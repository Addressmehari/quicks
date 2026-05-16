import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'squircle_clipper.dart';
import 'package:path/path.dart' as p;
import 'photo_preview_screen.dart';

class CapturedPhoto {
  final String path;
  final DateTime capturedAt;

  CapturedPhoto({required this.path, required this.capturedAt});
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
      ResolutionPreset.high,
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

      // Crop to 1:1 square (center-crop) then save
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'instant_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(dir.path, fileName);

      final Uint8List rawBytes = await photo.readAsBytes();
      final img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        final int side = decoded.width < decoded.height
            ? decoded.width
            : decoded.height;
        final int x = (decoded.width - side) ~/ 2;
        final int y = (decoded.height - side) ~/ 2;
        final img.Image cropped = img.copyCrop(
          decoded,
          x: x, y: y,
          width: side, height: side,
        );
        await File(savedPath).writeAsBytes(img.encodeJpg(cropped, quality: 92));
      } else {
        await File(photo.path).copy(savedPath);
      }

      final captured = CapturedPhoto(
        path: savedPath,
        capturedAt: DateTime.now(),
      );

      setState(() {
        _history.insert(0, captured);
        _isCapturing = false;
      });

      _newPhotoAnimController.forward(from: 0);
    } catch (e) {
      debugPrint('Capture error: $e');
      setState(() => _isCapturing = false);
    }
  }

  void _openPhoto(CapturedPhoto photo) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PhotoPreviewScreen(photo: photo),
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
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Text(
                    'instants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_cameras.length > 1)
                    GestureDetector(
                      onTap: _flipCamera,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flip_camera_ios_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Viewfinder (squircle) ────────────────────────────────
            AnimatedBuilder(
              animation: _shutterAnim,
              builder: (_, __) => Transform.scale(
                scale: _shutterAnim.value,
                child: SizedBox(
                  width: viewfinderSize,
                  height: viewfinderSize,
                  child: CustomPaint(
                    painter: _SquircleShadowPainter(),
                    child: SquircleClip(
                      n: 4.0,
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

            const SizedBox(height: 28),

            // ── Capture Button ────────────────────────────────────────
            GestureDetector(
              onTap: _capturePhoto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: _isCapturing ? 68 : 72,
                height: _isCapturing ? 68 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: _isCapturing ? 26 : 30,
                    height: _isCapturing ? 26 : 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── History Strip ─────────────────────────────────────────
            Expanded(
              child: _history.isEmpty
                  ? _buildEmptyHistory()
                  : _buildHistoryStrip(),
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
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final photo = _history[index];
              final isNewest = index == 0;

              Widget tile = GestureDetector(
                onTap: () => _openPhoto(photo),
                child: _HistoryTile(photo: photo),
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
          SquircleClip(
            n: 4.0,
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
          // Timestamp overlay at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: SquircleClipper(n: 4.0),
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
    final path = buildSquirclePath(size, n: 4.0);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 20);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SquircleShadowPainter oldDelegate) => false;
}
