import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class HomeCalendarDayCell extends StatelessWidget {
  final DateTime day;
  final String? imagePath;
  final bool calendarImageRenderingEnabled;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final bool isDisabled;
  final File? Function(String? path) getCachedImageFile;

  const HomeCalendarDayCell({
    super.key,
    required this.day,
    required this.imagePath,
    required this.calendarImageRenderingEnabled,
    required this.isToday,
    required this.isSelected,
    this.isOutside = false,
    this.isDisabled = false,
    required this.getCachedImageFile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isActive = isSelected || isToday;
    final textColor = isDisabled
        ? colors.calendarDayDisabledText
        : isOutside
            ? colors.calendarDayOutsideText
            : isActive
                ? colors.calendarControlText
                : theme.colorScheme.onSurface;

    Widget dayWidget = AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive ? colors.calendarControlBackground : Colors.transparent,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );

    if (imagePath != null && calendarImageRenderingEnabled && !isDisabled && !isOutside) {
      final cachedFile = getCachedImageFile(imagePath);
      dayWidget = AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  cachedFile!,
                  fit: BoxFit.cover,
                  cacheWidth:
                      (MediaQuery.sizeOf(context).width / 7 *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  filterQuality: FilterQuality.none,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isToday
                          ? colors.calendarControlBackground
                          : colors.imagePlaceholderStrong,
                    );
                  },
                ),
                Container(
                  color: isSelected
                      ? colors.scrim.withValues(alpha: 0.12)
                      : colors.scrim.withValues(alpha: 0.06),
                ),
                Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(
                        alpha: isSelected ? 0.85 : 0.68,
                      ),
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: colors.scrim.withValues(alpha: 0.5),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return dayWidget;
  }
}
