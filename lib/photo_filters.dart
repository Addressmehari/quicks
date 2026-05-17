import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PhotoFilters {
  static const String day = 'day';

  static String getFormattedDay(DateTime dt) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[dt.weekday - 1].toUpperCase();
  }

  static String getFormattedDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day} · $h:$m';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              PhotoFilters.getFormattedDay(date),
              textAlign: TextAlign.center,
              style: GoogleFonts.chewy(
                color: Colors.white.withOpacity(0.95),
                fontSize: isLarge ? 36 : 14,
                fontWeight: FontWeight.w400,
                letterSpacing: isLarge ? 2.0 : 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: isLarge ? 12 : 4,
                    offset: isLarge ? const Offset(0, 3) : const Offset(0, 1),
                  ),
                ],
              ),
            ),
            SizedBox(height: isLarge ? 2 : 0), // Spacing between day and date
            Text(
              PhotoFilters.getFormattedDate(date),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: isLarge ? 12 : 7,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: isLarge ? 8 : 2,
                    offset: isLarge ? const Offset(0, 1) : const Offset(0, 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
