// Hallmark · genre: playful · macrostructure: status-ticket · theme: locked LaLeMa design system
// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const body = TextStyle(color: AppColors.ink, fontSize: 16, height: 1.5);
    const pixel = TextStyle(
      fontFamily: 'Zpix',
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.moss,
        onPrimary: AppColors.paperRaised,
        secondary: AppColors.mustard,
        onSecondary: AppColors.ink,
        error: AppColors.danger,
        onError: AppColors.paperRaised,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
      ),
      textTheme: const TextTheme(
        displayLarge: pixel,
        displayMedium: pixel,
        displaySmall: pixel,
        headlineLarge: pixel,
        headlineMedium: pixel,
        headlineSmall: pixel,
        titleLarge: pixel,
        titleMedium: pixel,
        titleSmall: pixel,
        bodyLarge: body,
        bodyMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 14,
          height: 20 / 14,
        ),
        bodySmall: TextStyle(color: AppColors.ink, fontSize: 12, height: 1.5),
        labelLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 14,
          height: 20 / 14,
        ),
        labelMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          height: 16 / 12,
        ),
        labelSmall: TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          height: 16 / 12,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.paperRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
      focusColor: AppColors.moss,
    );
  }
}

TextStyle pixelStyle({
  required double size,
  double? height,
  Color color = AppColors.ink,
}) {
  return TextStyle(
    fontFamily: 'Zpix',
    fontWeight: FontWeight.w400,
    fontSize: size,
    height: height,
    color: color,
  );
}
