import 'package:flutter/material.dart';

import 'tokens.dart';

/// App-wide Material 3 theme seeded from the token palette.
ThemeData kdLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: KdColors.primary);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(KdSpacing.minTouchTarget),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(KdSpacing.minTouchTarget),
      ),
    ),
  );
}
