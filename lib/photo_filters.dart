import 'package:flutter/material.dart';

class PhotoFilters {
  static const String day = 'day';

  static String getFormattedDay(DateTime dt) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[dt.weekday - 1].toUpperCase();
  }
}

enum FilterOverlaySize { small, large }

class PhotoFilterOverlay extends StatelessWidget {
  final String? filter;
  final DateTime date;
  final FilterOverlaySize size;
  
  // Custom offset for cases where we need specific padding
  final double? customBottomOffset;

  const PhotoFilterOverlay({
    super.key,
    required this.filter,
    required this.date,
    this.size = FilterOverlaySize.large,
    this.customBottomOffset,
  });

  @override
  Widget build(BuildContext context) {
    if (filter == null) return const SizedBox.shrink();

    if (filter == PhotoFilters.day) {
      final isLarge = size == FilterOverlaySize.large;
      
      return Positioned(
        bottom: customBottomOffset ?? (isLarge ? 32 : 12),
        left: 0,
        right: 0,
        child: Text(
          PhotoFilters.getFormattedDay(date),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: isLarge ? 28 : 10,
            fontWeight: FontWeight.w800,
            letterSpacing: isLarge ? 3.0 : 1.5,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: isLarge ? 12 : 4,
                offset: isLarge ? const Offset(0, 2) : const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
