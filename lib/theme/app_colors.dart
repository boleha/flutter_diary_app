import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSubtle;
  final Color surfaceInset;
  final Color surfaceCard;
  final Color outline;
  final Color outlineStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color iconMuted;
  final Color imagePlaceholder;
  final Color imagePlaceholderStrong;
  final Color calendarControlBackground;
  final Color calendarControlText;
  final Color calendarControlIcon;
  final Color calendarWeekdayText;
  final Color calendarWeekendText;
  final Color calendarDayOutsideText;
  final Color calendarDayDisabledText;
  final Color calendarDivider;
  final Color actionPrimaryBackground;
  final Color actionPrimaryForeground;
  final Color danger;
  final Color success;
  final Color warning;
  final Color warningBackground;
  final Color toastBackground;
  final Color toastErrorBackground;
  final Color toastForeground;
  final Color scrim;
  final Color shadowSoft;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSubtle,
    required this.surfaceInset,
    required this.surfaceCard,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.iconMuted,
    required this.imagePlaceholder,
    required this.imagePlaceholderStrong,
    required this.calendarControlBackground,
    required this.calendarControlText,
    required this.calendarControlIcon,
    required this.calendarWeekdayText,
    required this.calendarWeekendText,
    required this.calendarDayOutsideText,
    required this.calendarDayDisabledText,
    required this.calendarDivider,
    required this.actionPrimaryBackground,
    required this.actionPrimaryForeground,
    required this.danger,
    required this.success,
    required this.warning,
    required this.warningBackground,
    required this.toastBackground,
    required this.toastErrorBackground,
    required this.toastForeground,
    required this.scrim,
    required this.shadowSoft,
  });

  static AppColors of(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    assert(
      colors != null,
      'AppColors is not configured on the current ThemeData.',
    );
    return colors!;
  }

  static final AppColors light = AppColors(
    background: const Color(0xFFF2F4F7),
    surface: Colors.white,
    surfaceMuted: const Color(0xFFF6F7F9),
    surfaceSubtle: Colors.grey[100]!,
    surfaceInset: Colors.grey[50]!,
    surfaceCard: Colors.white,
    outline: Colors.grey[200]!,
    outlineStrong: Colors.grey[400]!,
    textPrimary: Colors.grey[800]!,
    textSecondary: Colors.grey[700]!,
    textMuted: Colors.grey[600]!,
    iconMuted: Colors.grey[600]!,
    imagePlaceholder: Colors.grey[100]!,
    imagePlaceholderStrong: Colors.grey[200]!,
    calendarControlBackground: const Color(0xFFF6F7F9),
    calendarControlText: Colors.grey[700]!,
    calendarControlIcon: Colors.grey[600]!,
    calendarWeekdayText: Colors.grey[800]!,
    calendarWeekendText: Colors.grey[600]!,
    calendarDayOutsideText: Colors.grey[400]!,
    calendarDayDisabledText: Colors.grey[300]!,
    calendarDivider: Colors.grey[300]!,
    actionPrimaryBackground: Colors.grey[700]!,
    actionPrimaryForeground: Colors.white,
    danger: Colors.red,
    success: Colors.green,
    warning: Colors.orange[800]!,
    warningBackground: Colors.orange[100]!,
    toastBackground: const Color(0xFF2F2F2F),
    toastErrorBackground: const Color(0xFFC43C3C),
    toastForeground: Colors.white,
    scrim: Colors.black,
    shadowSoft: Colors.black.withValues(alpha: 0.05),
  );

  static final AppColors dark = AppColors(
    background: const Color(0xFF121212),
    surface: const Color(0xFF1E1E1E),
    surfaceMuted: const Color(0xFF1E1E1E),
    surfaceSubtle: const Color(0xFF2A2A2A),
    surfaceInset: const Color(0xFF212121),
    surfaceCard: const Color(0xFF2B2B2B),
    outline: Colors.grey[800]!,
    outlineStrong: Colors.grey[500]!,
    textPrimary: Colors.grey[300]!,
    textSecondary: Colors.grey[400]!,
    textMuted: Colors.grey[500]!,
    iconMuted: Colors.grey[500]!,
    imagePlaceholder: Colors.grey[800]!,
    imagePlaceholderStrong: Colors.grey[700]!,
    calendarControlBackground: Colors.grey[800]!,
    calendarControlText: Colors.grey[300]!,
    calendarControlIcon: Colors.grey[400]!,
    calendarWeekdayText: Colors.grey[400]!,
    calendarWeekendText: Colors.grey[500]!,
    calendarDayOutsideText: Colors.grey[400]!,
    calendarDayDisabledText: Colors.grey[700]!,
    calendarDivider: Colors.grey[700]!,
    actionPrimaryBackground: Colors.grey[700]!,
    actionPrimaryForeground: Colors.white,
    danger: Colors.red[400]!,
    success: Colors.green[400]!,
    warning: Colors.orange[300]!,
    warningBackground: Colors.orange.withValues(alpha: 0.18),
    toastBackground: const Color(0xFF2F2F2F),
    toastErrorBackground: const Color(0xFFC43C3C),
    toastForeground: Colors.white,
    scrim: Colors.black,
    shadowSoft: Colors.black.withValues(alpha: 0.2),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSubtle,
    Color? surfaceInset,
    Color? surfaceCard,
    Color? outline,
    Color? outlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? iconMuted,
    Color? imagePlaceholder,
    Color? imagePlaceholderStrong,
    Color? calendarControlBackground,
    Color? calendarControlText,
    Color? calendarControlIcon,
    Color? calendarWeekdayText,
    Color? calendarWeekendText,
    Color? calendarDayOutsideText,
    Color? calendarDayDisabledText,
    Color? calendarDivider,
    Color? actionPrimaryBackground,
    Color? actionPrimaryForeground,
    Color? danger,
    Color? success,
    Color? warning,
    Color? warningBackground,
    Color? toastBackground,
    Color? toastErrorBackground,
    Color? toastForeground,
    Color? scrim,
    Color? shadowSoft,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      iconMuted: iconMuted ?? this.iconMuted,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      imagePlaceholderStrong:
          imagePlaceholderStrong ?? this.imagePlaceholderStrong,
      calendarControlBackground:
          calendarControlBackground ?? this.calendarControlBackground,
      calendarControlText: calendarControlText ?? this.calendarControlText,
      calendarControlIcon: calendarControlIcon ?? this.calendarControlIcon,
      calendarWeekdayText: calendarWeekdayText ?? this.calendarWeekdayText,
      calendarWeekendText: calendarWeekendText ?? this.calendarWeekendText,
      calendarDayOutsideText:
          calendarDayOutsideText ?? this.calendarDayOutsideText,
      calendarDayDisabledText:
          calendarDayDisabledText ?? this.calendarDayDisabledText,
      calendarDivider: calendarDivider ?? this.calendarDivider,
      actionPrimaryBackground:
          actionPrimaryBackground ?? this.actionPrimaryBackground,
      actionPrimaryForeground:
          actionPrimaryForeground ?? this.actionPrimaryForeground,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      warningBackground: warningBackground ?? this.warningBackground,
      toastBackground: toastBackground ?? this.toastBackground,
      toastErrorBackground: toastErrorBackground ?? this.toastErrorBackground,
      toastForeground: toastForeground ?? this.toastForeground,
      scrim: scrim ?? this.scrim,
      shadowSoft: shadowSoft ?? this.shadowSoft,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }

    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      imagePlaceholder: Color.lerp(
        imagePlaceholder,
        other.imagePlaceholder,
        t,
      )!,
      imagePlaceholderStrong: Color.lerp(
        imagePlaceholderStrong,
        other.imagePlaceholderStrong,
        t,
      )!,
      calendarControlBackground: Color.lerp(
        calendarControlBackground,
        other.calendarControlBackground,
        t,
      )!,
      calendarControlText: Color.lerp(
        calendarControlText,
        other.calendarControlText,
        t,
      )!,
      calendarControlIcon: Color.lerp(
        calendarControlIcon,
        other.calendarControlIcon,
        t,
      )!,
      calendarWeekdayText: Color.lerp(
        calendarWeekdayText,
        other.calendarWeekdayText,
        t,
      )!,
      calendarWeekendText: Color.lerp(
        calendarWeekendText,
        other.calendarWeekendText,
        t,
      )!,
      calendarDayOutsideText: Color.lerp(
        calendarDayOutsideText,
        other.calendarDayOutsideText,
        t,
      )!,
      calendarDayDisabledText: Color.lerp(
        calendarDayDisabledText,
        other.calendarDayDisabledText,
        t,
      )!,
      calendarDivider: Color.lerp(calendarDivider, other.calendarDivider, t)!,
      actionPrimaryBackground: Color.lerp(
        actionPrimaryBackground,
        other.actionPrimaryBackground,
        t,
      )!,
      actionPrimaryForeground: Color.lerp(
        actionPrimaryForeground,
        other.actionPrimaryForeground,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBackground: Color.lerp(
        warningBackground,
        other.warningBackground,
        t,
      )!,
      toastBackground: Color.lerp(toastBackground, other.toastBackground, t)!,
      toastErrorBackground: Color.lerp(
        toastErrorBackground,
        other.toastErrorBackground,
        t,
      )!,
      toastForeground: Color.lerp(toastForeground, other.toastForeground, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
    );
  }
}
