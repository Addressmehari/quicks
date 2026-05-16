import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_screen.dart';
import 'squircle_clipper.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final List<CapturedPhoto> photos;
  final int initialIndex;

  const PhotoPreviewScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final previewSize = size.width * 0.8;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Tap background to dismiss
            GestureDetector(
              onTap: () => Navigator.pop(context, _currentIndex),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
              ),
            ),

            // Stacked Photo Gallery
            Center(
              child: _buildPhotoStack(previewSize),
            ),

            // Back button + timestamp (Top)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context, _currentIndex),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDateTime(
                                widget.photos[_currentIndex].capturedAt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Delete button (Bottom)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // In a real app, we'd delete the file and update the state
                    // For now, let's just pop with a signal or message
                    Navigator.pop(context, -1); // -1 means deleted
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStack(double size) {
    return GestureDetector(
      onTap: _nextPhoto,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Render current + next 3 photos (Back to Front)
          for (int i = 3; i >= 0; i--)
            if (_currentIndex + i < widget.photos.length)
              _buildPhotoCard(_currentIndex + i, size, i),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(int index, double size, int depth) {
    final photo = widget.photos[index];
    final isTop = depth == 0;
    
    // Balanced "fan" distribution instead of pure random to avoid lopsidedness
    // Alternates sides based on the photo index
    final double side = (index % 2 == 0) ? 1.0 : -1.0;
    
    final rotation = isTop ? 0.0 : (0.08 * side * depth); 
    final xOffset = isTop ? 0.0 : (18.0 * side * depth); 
    final yOffset = isTop ? 0.0 : (-28.0 * depth);
    
    final scale = isTop ? 1.0 : (1.0 - (0.08 * depth));

    return AnimatedContainer(
      key: ValueKey(photo.path),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(xOffset, yOffset)
        ..rotateZ(rotation)
        ..scale(scale),
      child: Hero(
        tag: isTop ? photo.path : "bg_${photo.path}_$index",
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isTop ? 0.45 : 0.3),
                blurRadius: isTop ? 40 : 20,
                spreadRadius: isTop ? 10 : 0,
              ),
            ],
          ),
          child: SquircleClip(
            n: 3.2,
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.broken_image, color: Colors.white30, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _nextPhoto() {
    if (widget.photos.length <= 1) return;
    
    HapticFeedback.mediumImpact();
    setState(() {
      if (_currentIndex < widget.photos.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
    });
  }
}
