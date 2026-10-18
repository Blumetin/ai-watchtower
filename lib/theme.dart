import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'l10n/app_localizations.dart';

class AppColors {
  static const primary = Color(0xFF37474F);
  static const onPrimary = Colors.white;
  static const primaryContainer = Color(0xFFDDE3E6);
  static const onPrimaryContainer = Color(0xFF1B262C);
  static const secondary = Color(0xFF964900);
  static const secondaryContainer = Color(0xFFFC820C);
  static const onSecondaryContainer = Color(0xFF5E2C00);
  static const tertiary = Color(0xFF0058A2);
  static const surface = Color(0xFFF8F9FA);
  static const surfaceContainerLow = Color(0xFFF2F4F5);
  static const surfaceContainer = Color(0xFFECEFF1);
  static const surfaceContainerHigh = Color(0xFFE6E9EB);
  static const onSurface = Color(0xFF1A1C1E);
  static const onSurfaceVariant = Color(0xFF44474E);
  static const outline = Color(0xFF74777F);
  static const outlineVariant = Color(0xFFC4C7CC);
  static const cardBorder = outlineVariant;
  static const unrated = Color(0xFF5F6368);

  static const attention = Color(0xFFA14A00);

  static const scaleRed = Color(0xFFAF101A);
  static const scaleRedLight = Color(0xFFD32F2F);

  static const textMuted = onSurfaceVariant;

  static const sevRed = Color(0xFFC62828);
  static const sevOrange = Color(0xFFFF9800);
  static const sevYellow = Color(
    0xFFFFE082,
  );
  static const onSevLight = Color(0xFF261A00);

  static const sevOrangeBorder = Color(0xFFA14A00);
  static const sevYellowBorder = Color(0xFF8C6A00);
}

Color? severityBorder(String? severity) => switch (severity) {
  'critical' => AppColors.sevOrangeBorder,
  'warning' => AppColors.sevYellowBorder,
  _ => null,
};

Color severityColor(String? severity) => switch (severity) {
  'extreme' => AppColors.sevRed,
  'critical' => AppColors.sevOrange,
  'warning' => AppColors.sevYellow,
  'info' => AppColors.tertiary,
  _ => AppColors.unrated,
};

Color onSeverityColor(String? severity) =>
    severity == 'critical' || severity == 'warning'
    ? AppColors.onSevLight
    : Colors.white;

String? severityLabel(AppLocalizations t, String? severity) =>
    switch (severity) {
      'extreme' => t.severityExtreme,
      'critical' => t.severityCritical,
      'warning' => t.severityWarning,
      'info' => t.severityInfo,
      _ => null,
    };

const groupOrder = ['氣象', '地震海嘯', '水利', '火災事故', '交通', '民生', '其他'];

IconData groupIcon(String group) => switch (group) {
  '氣象' => Symbols.thunderstorm_rounded,
  '地震海嘯' => Symbols.earthquake_rounded,
  '水利' => Symbols.water_drop_rounded,
  '火災事故' => Symbols.local_fire_department_rounded,
  '交通' => Symbols.traffic_rounded,
  '民生' => Symbols.home_rounded,
  _ => Symbols.info_rounded,
};

String groupLabel(AppLocalizations t, String group) => switch (group) {
  '氣象' => t.groupWeather,
  '地震海嘯' => t.groupQuake,
  '水利' => t.groupWater,
  '火災事故' => t.groupFire,
  '交通' => t.groupTraffic,
  '民生' => t.groupLiving,
  _ => t.groupOther,
};

class AppLayout {
  static const pageMargin = 24.0;
  static const pagePadding = EdgeInsets.fromLTRB(24, 24, 24, 32);
  static const gap = 16.0;
  static const radius = 8.0;
  static const radiusLg = 12.0;
  static const borderWidth = 2.0;
  static const accentBarWidth = 4.0;
  static const touchTarget = 56.0;
}

ThemeData buildTheme() {
  const cjkFallback = kIsWeb ? ['NotoSansTCUI', 'NotoSansJPUI'] : null;
  TextStyle style(String family, double size, FontWeight w, double height) =>
      TextStyle(
        fontFamily: family,
        fontFamilyFallback: cjkFallback,
        fontSize: size,
        fontWeight: w,
        fontVariations: [FontVariation.weight(w.value.toDouble())],
        height: height,
        color: AppColors.onSurface,
      );
  TextStyle heading(double size, FontWeight w) =>
      style('PlusJakartaSans', size, w, 1.35);
  TextStyle body(double size, FontWeight w) =>
      style('AtkinsonHyperlegibleNext', size, w, 1.7);

  return ThemeData(
    useMaterial3: true,
    fontFamilyFallback: cjkFallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.primaryContainer,
      onSecondaryContainer: AppColors.onPrimaryContainer,
      tertiary: AppColors.tertiary,
      surface: AppColors.surface,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHigh,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      error: AppColors.sevRed,
    ),
    iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
    scaffoldBackgroundColor: AppColors.surface,
    visualDensity: VisualDensity.standard,
    tooltipTheme: TooltipThemeData(
      textStyle: body(16, FontWeight.w500).copyWith(color: Colors.white),
    ),
    textTheme: TextTheme(
      headlineLarge: heading(32, FontWeight.w800),
      headlineMedium: heading(24, FontWeight.w700),
      headlineSmall: heading(20, FontWeight.w700),
      titleMedium: heading(18, FontWeight.w700),
      titleSmall: heading(16, FontWeight.w700),
      labelSmall: heading(16, FontWeight.w600),
      labelLarge: heading(18, FontWeight.w700),
      labelMedium: heading(16, FontWeight.w600),
      bodyLarge: body(20, FontWeight.w400),
      bodyMedium: body(18, FontWeight.w400),
      bodySmall: body(16, FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: heading(
        20,
        FontWeight.w700,
      ).copyWith(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: heading(18, FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: AppColors.surfaceContainer,
      indicatorColor: AppColors.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(heading(16, FontWeight.w600)),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(AppLayout.touchTarget, AppLayout.touchTarget),
        ),
      ),
    ),
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(AppLayout.touchTarget, AppLayout.touchTarget),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: body(16, FontWeight.w500).copyWith(color: Colors.white),
    ),
  );
}

Color intensityColor(String raw) => switch (raw.replaceAll('級', '')) {
  '1' || '2' => AppColors.tertiary,
  '3' || '4' => AppColors.secondaryContainer,
  '5弱' || '5強' => AppColors.scaleRedLight,
  '6弱' || '6強' || '7' => AppColors.scaleRed,
  _ => AppColors.unrated,
};

Color onIntensityColor(String raw) =>
    intensityColor(raw) == AppColors.secondaryContainer
    ? AppColors.onSecondaryContainer
    : Colors.white;
