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
  bool _isGridView = false;

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

            // Gallery View (Stack or Grid)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation.drive(Tween(begin: 0.95, end: 1.0)),
                    child: child,
                  ),
                );
              },
              child: _isGridView 
                  ? _buildPhotoGrid(context) 
                  : Center(
                      key: const ValueKey('stack_view_container'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPhotoStack(previewSize),
                          if (widget.photos.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) => ScaleTransition(
                                scale: animation.drive(Tween(begin: 0.9, end: 1.0)),
                                child: FadeTransition(opacity: animation, child: child),
                              ),
                              child: Container(
                                key: ValueKey('timestamp_$_currentIndex'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _formatDateTime(
                                      widget.photos[_currentIndex].capturedAt),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 80), // Shifting images up
                        ],
                      ),
                    ),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Delete Button (Bottom Left)
            Positioned(
              bottom: 40,
              left: 24,
              child: GestureDetector(
                onTap: _deleteCurrentPhoto,
                child: SquircleClip(
                  n: 3.2,
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.red.withOpacity(0.12),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            // Toggle Button (Bottom Right)
            Positioned(
              bottom: 40,
              right: 24,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _isGridView = !_isGridView);
                },
                child: SquircleClip(
                  n: 3.2,
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.white.withOpacity(0.15),
                    child: Icon(
                      _isGridView ? Icons.layers_rounded : Icons.grid_view_rounded,
                      color: Colors.white,
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

  Widget _buildPhotoGrid(BuildContext context) {
    return SafeArea(
      key: const ValueKey('grid_view_container'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 100),
        child: GridView.builder(
          itemCount: widget.photos.length,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final photo = widget.photos[index];
            final isSelected = index == _currentIndex;
            
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentIndex = index;
                  _isGridView = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSelected ? 0.5 : 0.3),
                      blurRadius: isSelected ? 15 : 10,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: SquircleClip(
                  n: 3.2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(photo.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.broken_image, color: Colors.white30),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhotoStack(double size) {
    return KeyedSubtree(
      key: const ValueKey('stack_view'),
      child: GestureDetector(
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

  void _deleteCurrentPhoto() async {
    if (widget.photos.isEmpty) return;
    
    final photo = widget.photos[_currentIndex];
    HapticFeedback.heavyImpact();

    try {
      // 1. Delete from Physical Storage
      final file = File(photo.path);
      if (await file.exists()) {
        await file.delete();
      }

      // 2. Remove from List and Update UI
      setState(() {
        widget.photos.removeAt(_currentIndex);
        
        if (widget.photos.isEmpty) {
          Navigator.pop(context, true); // true = something was deleted
        } else {
          // Adjust index if we deleted the last item
          if (_currentIndex >= widget.photos.length) {
            _currentIndex = widget.photos.length - 1;
          }
        }
      });
      
      // Notify parent about the change if we are still here
      // (Optional: we could pop here too, but staying is better if there are more photos)
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }
}
