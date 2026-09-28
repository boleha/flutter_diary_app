import 'dart:io';

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../theme/app_colors.dart';
import 'mood_icons.dart';

class HomeCalendarEntryCard extends StatelessWidget {
  final DateTime date;
  final DiaryEntry entry;
  final bool isDark;
  final VoidCallback onTap;
  final File? Function(String? path) getCachedImageFile;

  const HomeCalendarEntryCard({
    super.key,
    required this.date,
    required this.entry,
    required this.isDark,
    required this.onTap,
    required this.getCachedImageFile,
  });

  String _getWeekdayName(DateTime date) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colors.calendarControlBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    _getWeekdayName(date),
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DrawerDiaryCard(
                entry: entry,
                isDark: isDark,
                getCachedImageFile: getCachedImageFile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerDiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final bool isDark;
  final File? Function(String? path) getCachedImageFile;

  const _DrawerDiaryCard({
    required this.entry,
    required this.isDark,
    required this.getCachedImageFile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasImage = entry.images.isNotEmpty;
    final imagePath = hasImage ? entry.images.first : null;
    final cardColor = colors.surfaceCard;
    final tagTextColor = colors.textSecondary;
    final mood = entry.mood?.trim() ?? '';
    final weather = entry.weather?.trim() ?? '';
    final hasMood = mood.isNotEmpty;
    final hasWeather = weather.isNotEmpty;
    final weightTextRaw = entry.weight?.trim() ?? '';
    final hasWeight = weightTextRaw.isNotEmpty;
    final weightText = hasWeight
        ? ((weightTextRaw.toLowerCase().endsWith('kg') ||
                  weightTextRaw.endsWith('公斤'))
              ? weightTextRaw
              : '${weightTextRaw}kg')
        : '';
    final shadowColor = colors.shadowSoft;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage && imagePath != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final cacheWidth =
                    (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                        .round();
                return AspectRatio(
                  aspectRatio: 1.15,
                  child: Image.file(
                    getCachedImageFile(imagePath)!,
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.low,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      return ColoredBox(
                        color: colors.imagePlaceholder,
                        child: SizedBox.expand(child: child),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: colors.imagePlaceholderStrong,
                        child: Icon(
                          Icons.image_not_supported,
                          color: colors.iconMuted,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          if (!hasImage || hasMood || hasWeather || hasWeight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceInset,
                borderRadius: hasImage
                    ? const BorderRadius.vertical(bottom: Radius.circular(12))
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (hasMood)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (MoodIcons.getIcon(mood) != null) ...[
                          Icon(
                            MoodIcons.getIcon(mood)!,
                            size: 14,
                            color: tagTextColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          mood,
                          style: TextStyle(
                            fontSize: 12,
                            color: tagTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if (hasMood && hasWeather) const SizedBox(width: 12),
                  if (hasWeather)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (WeatherIcons.getIcon(weather) != null) ...[
                          Icon(
                            WeatherIcons.getIcon(weather)!,
                            size: 14,
                            color: tagTextColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          weather,
                          style: TextStyle(
                            fontSize: 12,
                            color: tagTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if ((hasWeather || hasMood) && hasWeight)
                    const SizedBox(width: 12),
                  if (hasWeight)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monitor_weight_outlined,
                          size: 14,
                          color: tagTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          weightText,
                          style: TextStyle(
                            fontSize: 12,
                            color: tagTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
