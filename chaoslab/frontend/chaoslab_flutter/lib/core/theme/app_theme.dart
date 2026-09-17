import 'package:flutter/material.dart';

/// A dark, "mission control" visual language — this is the differentiator
/// the whole product idea leans on, so it deliberately does not look like a
/// default Material demo app.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF121821);
  static const Color surfaceRaised = Color(0xFF1A222E);
  static const Color border = Color(0xFF243040);

  static const Color textPrimary = Color(0xFFE6EDF5);
  static const Color textSecondary = Color(0xFF8C9BB0);
  static const Color textMuted = Color(0xFF5C6B80);

  static const Color accent = Color(0xFF4FD1C5); // signature teal
  static const Color accentDim = Color(0xFF2C7A72);

  static const Color statusHealthy = Color(0xFF3ECF8E);
  static const Color statusWarning = Color(0xFFF5B85C);
  static const Color statusCritical = Color(0xFFF5615C);

  static Color riskColor(double riskScorePct) {
    if (riskScorePct >= 70) return statusCritical;
    if (riskScorePct >= 40) return statusWarning;
    return statusHealthy;
  }
}

/// Centralized spacing/radius scale so screens stop hardcoding one-off
/// magic numbers for padding and corner radii.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
}

/// Two font roles: the platform's default UI sans (Roboto on Android, San
/// Francisco on iOS/macOS, Segoe/Inter-like on Windows — left unset so
/// Flutter picks the right one per platform) for labels/body/headings, and
/// `monospace` — a face guaranteed to resolve on every platform Flutter
/// targets — reserved for metric numbers, risk scores, and anything
/// resembling a terminal/log line. This is the "developer tool" signal
/// without making paragraphs of body text harder to scan.
class AppFonts {
  AppFonts._();

  static const String mono = 'monospace';

  static const TextStyle metric = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle metricLarge = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontSize: 28,
    height: 1.1,
  );

  static const TextStyle code = TextStyle(
    fontFamily: mono,
    color: AppColors.textSecondary,
    fontSize: 12.5,
    height: 1.5,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.statusCritical,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}

/// Reusable text styles for patterns that repeat across screens (section
/// eyebrows, card titles, muted captions) so widgets stop redefining the
/// same TextStyle with slightly different values each time.
class AppTextStyles {
  AppTextStyles._();

  /// Small caps-style uppercase label above a section ("PRIMARY BOTTLENECK").
  static const TextStyle eyebrow = TextStyle(
    color: AppColors.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const TextStyle cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.4,
  );
}
