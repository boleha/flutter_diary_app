import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppUi {
  const AppUi._();

  static const EdgeInsets pagePadding = EdgeInsets.all(16);
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(10, 12, 10, 12);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const double sectionGap = 16;
  static const double itemGap = 12;
  static const Duration fastDuration = Duration(milliseconds: 180);
  static const Duration baseDuration = Duration(milliseconds: 220);
  static const Duration shortDebounce = Duration(milliseconds: 300);
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));

  static Color subtleSurface(BuildContext context) {
    return AppColors.of(context).surfaceSubtle;
  }

  static Color secondaryFabBackground(BuildContext context) {
    return AppColors.of(context).calendarControlBackground;
  }

  static Color secondaryFabForeground(BuildContext context) {
    return AppColors.of(context).textPrimary;
  }

  static Color mutedText(BuildContext context) {
    return AppColors.of(context).textMuted;
  }

  static Color mutedIcon(BuildContext context) {
    return AppColors.of(context).iconMuted;
  }

  static BoxDecoration neumorphicDecoration(
    BuildContext context, {
    double radius = 14,
    Color? color,
  }) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark ? colors.surfaceCard : colors.surfaceMuted),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFFADB6C2).withValues(alpha: 0.4),
          offset: const Offset(3, 3),
          blurRadius: 8,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.9),
          offset: const Offset(-3, -3),
          blurRadius: 8,
        ),
      ],
    );
  }
}

class NeumorphicSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? color;

  const NeumorphicSurface({
    super.key,
    required this.child,
    this.radius = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppUi.neumorphicDecoration(
        context,
        radius: radius,
        color: color,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
