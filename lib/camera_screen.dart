import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'squircle_clipper.dart';
import 'package:path/path.dart' as p;
import 'photo_preview_screen.dart';

/// Top-level function for compute() — runs in a background isolate.
/// Decodes [bytes], bakes orientation, center-crops to a square, and returns JPEG bytes.
Uint8List _cropToSquare(Uint8List bytes) {
  img.Image? decoded = img.decodeJpg(bytes);
  if (decoded == null) return bytes;

  // Bake orientation
  decoded = img.bakeOrientation(decoded);

  final int side =
      decoded.width < decoded.height ? decoded.width : decoded.height;
  final int x = (decoded.width - side) ~/ 2;
  final int y = (decoded.height - side) ~/ 2;

  final img.Image square =
      img.copyCrop(decoded, x: x, y: y, width: side, height: side);
  return Uint8List.fromList(img.encodeJpg(square, quality: 70));
}

class CapturedPhoto {
  final String path;
  final DateTime capturedAt;

  CapturedPhoto({required this.path, required this.capturedAt});

  Map<String, dynamic> toJson() => {
        'path': path,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory CapturedPhoto.fromJson(Map<String, dynamic> json) => CapturedPhoto(
        path: json['path'],
        capturedAt: DateTime.parse(json['capturedAt']),
      );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isCapturing = false;
  int _currentCameraIndex = 0;

  final List<CapturedPhoto> _history = [];

  // Animations
  late AnimationController _shutterAnimController;
  late AnimationController _newPhotoAnimController;
  late Animation<double> _shutterAnim;
  late Animation<double> _newPhotoSlideAnim;
  late Animation<double> _newPhotoFadeAnim;

  @override
  void initState() {
    super.initState();
    _shutterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _shutterAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _shutterAnimController, curve: Curves.easeInOut),
    );

    _newPhotoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _newPhotoSlideAnim = Tween<double>(begin: -80, end: 0).animate(
      CurvedAnimation(
          parent: _newPhotoAnimController, curve: Curves.easeOutCubic),
    );
    _newPhotoFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _newPhotoAnimController, curve: Curves.easeOut),
    );

    _initCamera();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'history.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        final List<CapturedPhoto> loadedHistory = [];

        for (var item in jsonList) {
          final photo = CapturedPhoto.fromJson(item);
          // Only add if the file actually exists on disk
          if (await File(photo.path).exists()) {
            loadedHistory.add(photo);
          }
        }

        setState(() {
          _history.clear();
          _history.addAll(loadedHistory);
        });
      }
    } catch (e) {
      debugPrint('Load history error: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'history.json'));
      final jsonList = _history.map((photo) => photo.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Save history error: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _startCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera start error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isCameraReady = false);
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    await _startCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);

    // Shutter flash animation
    await _shutterAnimController.forward();
    await _shutterAnimController.reverse();

    try {
      final XFile photo = await _controller!.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'instant_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(dir.path, fileName);

      // Fast copy to permanent storage so we can show it immediately
      await File(photo.path).copy(savedPath);

      final captured = CapturedPhoto(
        path: savedPath,
        capturedAt: DateTime.now(),
      );

      setState(() {
        _history.insert(0, captured);
        _isCapturing = false;
      });

      _saveHistory();

      _newPhotoAnimController.forward(from: 0);

      // Perform the heavy cropping in the background without awaiting it here
      _processPhotoInBackground(savedPath);
    } catch (e) {
      debugPrint('Capture error: $e');
      setState(() => _isCapturing = false);
    }
  }

  /// Processes the photo (cropping to square) in a background isolate.
  Future<void> _processPhotoInBackground(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final croppedBytes = await compute(_cropToSquare, bytes);
      await File(path).writeAsBytes(croppedBytes);
      debugPrint('Background cropping complete for: $path');
    } catch (e) {
      debugPrint('Background processing error: $e');
    }
  }

  void _openPhoto(int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PhotoPreviewScreen(
          photos: _history,
          initialIndex: index,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _shutterAnimController.dispose();
    _newPhotoAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewfinderSize = size.width * 0.88;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main Content ──────────────────────────────────────────
            Column(
              children: [
                // ── Top Bar (Close button) ─────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: const [
                      Spacer(),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // ── Viewfinder (squircle) ─────────────────────────────
                AnimatedBuilder(
                  animation: _shutterAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _shutterAnim.value,
                    child: Center(
                      child: SizedBox(
                        width: viewfinderSize,
                        height: viewfinderSize,
                        child: CustomPaint(
                          painter: _SquircleShadowPainter(),
                          child: SquircleClip(
                            n: 3.2,
                            child: SizedBox(
                              width: viewfinderSize,
                              height: viewfinderSize,
                              child: _isCameraReady && _controller != null
                                  ? _buildCameraPreview(viewfinderSize)
                                  : _buildCameraPlaceholder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Capture Button ─────────────────────────────────────
                BouncingButton(
                  onTap: _capturePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _isCapturing ? 64 : 70,
                      height: _isCapturing ? 64 : 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Friends Selector ──────────────────────────────────
                BouncingButton(
                  onTap: () {
                    // Open selector logic
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_alt_rounded,
                            color: Color(0xFF0A84FF), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Friends',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withOpacity(0.4), size: 18),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Bottom Icons Row ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // History Icon
                      BouncingButton(
                        onTap: () {
                          if (_history.isNotEmpty) _openPhoto(0);
                        },
                        child: const Icon(Icons.history_rounded,
                            color: Colors.white, size: 28),
                      ),

                      // Flip Camera Icon
                      BouncingButton(
                        onTap: _flipCamera,
                        child: const Icon(Icons.cached_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(double size) {
    final double rawAspect = _controller!.value.aspectRatio; // always landscape ratio from sensor

    // value.aspectRatio is ALWAYS reported as landscape (width/height of sensor).
    // e.g. 16:9 → 1.778, 4:3 → 1.333
    // For portrait display we need the INVERSE: 9:16 → 0.5625
    final double portraitAspect = rawAspect > 1.0 ? 1.0 / rawAspect : rawAspect;

    // Use buildPreview() (raw Texture) instead of CameraPreview to bypass
    // the internal AspectRatio widget which causes distortion.
    // We manually apply the correct portrait aspect ratio, then scale up
    // so the width fills the square and excess height is clipped.
    return ClipRect(
      child: Center(
        child: Transform.scale(
          // scale = 1/portraitAspect → makes width = S, height overflows → ClipRect clips
          scale: 1.0 / portraitAspect,
          child: AspectRatio(
            aspectRatio: portraitAspect,
            child: _controller!.buildPreview(),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined,
              color: Colors.white30, size: 48),
          const SizedBox(height: 12),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              color: Colors.white.withOpacity(0.18), size: 36),
          const SizedBox(height: 10),
          Text(
            'Your moments will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'moments',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_history.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110, // Fixed height for the strip
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final photo = _history[index];
              final isNewest = index == 0;

              Widget tile = Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => _openPhoto(index),
                  child: _HistoryTile(photo: photo),
                ),
              );

              if (isNewest) {
                tile = AnimatedBuilder(
                  animation: _newPhotoAnimController,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_newPhotoSlideAnim.value, 0),
                    child: Opacity(
                      opacity: _newPhotoFadeAnim.value,
                      child: child,
                    ),
                  ),
                  child: tile,
                );
              }

              return tile;
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final CapturedPhoto photo;

  const _HistoryTile({required this.photo});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    const double tileSize = 90;

    return Container(
      width: tileSize,
      height: tileSize, // square → squircle mask is perfectly symmetrical
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Square image → squircle mask
          Hero(
            tag: photo.path,
            child: SquircleClip(
              n: 3.2,
              child: Image.file(
                File(photo.path),
                width: tileSize,
                height: tileSize,
                fit: BoxFit.cover, // center-crops the 1:1 image into squircle
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, color: Colors.white30),
                ),
              ),
            ),
          ),
          // Timestamp overlay at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: SquircleClipper(n: 3.2),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.72),
                    ],
                  ),
                ),
                child: Text(
                  _formatTime(photo.capturedAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a subtle glow behind the squircle viewfinder.
class _SquircleShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = buildSquirclePath(size, n: 3.2);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 20);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SquircleShadowPainter oldDelegate) => false;
}

/// A wrapper that adds a subtle bounce/pop effect on tap.
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncingButton({super.key, required this.child, required this.onTap});

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
