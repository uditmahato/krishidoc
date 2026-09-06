import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// App-wide Material 3 theme built from explicit tokens.
///
/// This used to call `ColorScheme.fromSeed(seedColor: KdColors.primary)`,
/// which was the single worst defect in the design system: seeding runs the
/// M3 tonal palette generator, and the generator does not return the colour it
/// was given. Feeding it #1B5E20 produced #3C6939, so every button, icon and
/// app bar in the app painted a green that nobody had ever contrast checked,
/// while the token file sat there describing a colour that never reached a
/// pixel. A design system whose values are advisory is not a design system.
///
/// Everything below is stated outright. It is more code than a seed call, and
/// that is the point: each value is a decision somebody can audit.
ThemeData kdLightTheme({Locale locale = const Locale('en')}) {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: KdColors.primary,
    onPrimary: KdColors.onPrimary,
    primaryContainer: KdColors.primarySoft,
    onPrimaryContainer: KdColors.stateConfidentInk,
    secondary: KdColors.slate,
    onSecondary: KdColors.onPrimary,
    secondaryContainer: KdColors.stateOutOfScopeBand,
    onSecondaryContainer: KdColors.stateOutOfScopeInk,
    tertiary: KdColors.warning,
    onTertiary: KdColors.onPrimary,
    tertiaryContainer: KdColors.stateUncertainBand,
    onTertiaryContainer: KdColors.stateUncertainInk,
    error: KdColors.danger,
    onError: KdColors.onPrimary,
    errorContainer: Color(0xFFF6DCDC),
    onErrorContainer: Color(0xFF5C1010),
    surface: KdColors.surface,
    onSurface: KdColors.inkBody,
    onSurfaceVariant: KdColors.inkMuted,
    surfaceContainerLowest: KdColors.surface,
    surfaceContainerLow: KdColors.surface,
    surfaceContainer: KdColors.canvas,
    surfaceContainerHigh: KdColors.surfaceSunken,
    surfaceContainerHighest: KdColors.surfaceSunken,
    outline: KdColors.border,
    outlineVariant: KdColors.border,
    inverseSurface: KdColors.inkStrong,
    onInverseSurface: KdColors.surface,
  );

  final text = KdType.forLocale(locale);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: KdColors.canvas,
    canvasColor: KdColors.canvas,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,

    appBarTheme: AppBarTheme(
      backgroundColor: KdColors.canvas,
      foregroundColor: KdColors.inkStrong,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      titleTextStyle: text.titleLarge?.copyWith(color: KdColors.inkStrong),
    ),

    // Editorial surfaces use a quiet edge and depth. Functional controls and
    // safety states still use the stronger KdColors.border token explicitly.
    cardTheme: CardThemeData(
      color: KdColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x1A0E3C28),
      elevation: 1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdRadius.lg),
        side: const BorderSide(color: KdColors.outlineSoft),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(KdSpacing.xxxl, 54),
        padding: const EdgeInsets.symmetric(
          horizontal: KdSpacing.lg,
          vertical: KdSpacing.smd,
        ),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KdRadius.xl),
        ),
        // Disabled has to stay readable. M3's default is a 12 percent ghost,
        // and the shutter, the most important control in the app, is disabled
        // by default while the frame is not yet good enough. A user who
        // cannot read the coaching line must still see a button that is
        // waiting rather than one that is broken.
        disabledBackgroundColor: KdColors.surfaceSunken,
        disabledForegroundColor: KdColors.inkDisabled,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(KdSpacing.xxxl, 52),
        padding: const EdgeInsets.symmetric(horizontal: KdSpacing.lmd),
        textStyle: text.labelLarge,
        foregroundColor: KdColors.primaryPressed,
        side: const BorderSide(color: KdColors.primary, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KdRadius.xl),
        ),
      ),
    ),

    // Previously unthemed, which left the two debug text buttons at 40dp,
    // under the Android minimum.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(
          KdSpacing.minTouchTarget,
          KdSpacing.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: KdSpacing.md),
        textStyle: text.labelLarge,
        foregroundColor: KdColors.primaryPressed,
      ),
    ),

    // The crop chip measured about 32dp, which made the smallest target on
    // the capture screen the one a farmer taps with muddy hands.
    chipTheme: ChipThemeData(
      backgroundColor: KdColors.surface,
      selectedColor: KdColors.primarySoft,
      side: const BorderSide(color: KdColors.outlineSoft),
      labelStyle: text.labelLarge?.copyWith(color: KdColors.inkBody),
      padding: const EdgeInsets.symmetric(
        horizontal: KdSpacing.smd,
        vertical: KdSpacing.smd,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdRadius.xl),
      ),
    ),

    listTileTheme: ListTileThemeData(
      minVerticalPadding: KdSpacing.smd,
      minLeadingWidth: KdSpacing.xl,
      iconColor: KdColors.primaryPressed,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall?.copyWith(color: KdColors.inkMuted),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdRadius.md),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: KdColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KdRadius.xl)),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: KdColors.navigation,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: KdColors.primarySoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdRadius.pill),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? KdColors.primaryPressed
              : KdColors.inkMuted,
          size: KdIconSize.md,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? KdColors.primaryPressed
              : KdColors.inkMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        );
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KdColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KdSpacing.md,
        vertical: KdSpacing.smd,
      ),
      labelStyle: text.bodyMedium?.copyWith(color: KdColors.inkMuted),
      hintStyle: text.bodyMedium?.copyWith(color: KdColors.inkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KdRadius.md),
        borderSide: const BorderSide(color: KdColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KdRadius.md),
        borderSide: const BorderSide(color: KdColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KdRadius.md),
        borderSide: const BorderSide(color: KdColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KdRadius.md),
        borderSide: const BorderSide(color: KdColors.danger),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: KdColors.inkStrong,
        minimumSize: const Size.square(KdSpacing.minTouchTarget),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: KdColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdRadius.lg),
        side: const BorderSide(color: KdColors.outlineSoft),
      ),
      textStyle: text.bodyMedium,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: KdColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KdRadius.xl),
      ),
      titleTextStyle: text.titleLarge?.copyWith(color: KdColors.inkStrong),
      contentTextStyle: text.bodyMedium?.copyWith(color: KdColors.inkBody),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: KdColors.border, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KdColors.primary
            : Colors.transparent,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: KdColors.primary,
      foregroundColor: KdColors.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(KdRadius.lg)),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KdColors.primary,
      linearTrackColor: KdColors.surfaceSunken,
      circularTrackColor: KdColors.surfaceSunken,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: KdColors.inkStrong,
      contentTextStyle: text.bodyMedium?.copyWith(color: KdColors.surface),
      behavior: SnackBarBehavior.floating,
    ),

    dividerTheme: const DividerThemeData(
      color: KdColors.outlineSoft,
      space: 1,
      thickness: 1,
    ),

    // Flutter's Android default (ZoomPageTransitionsBuilder) snapshots both
    // routes into full screen textures on the first frame of every push,
    // roughly 10MB each at 1080x2340, and it can do that while a camera
    // stream is still alive. The fade is cheaper and does not fight the
    // camera for memory.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()},
    ),
  );
}

/// A duration that collapses to zero when the platform asks for no animation.
///
/// Android's "Remove animations" accessibility setting is enabled far more
/// often on low end hardware than on flagships, which is exactly this app's
/// audience. Every custom duration must go through here; a raw
/// `Duration(milliseconds: 250)` at a call site ignores the user's setting.
Duration kdDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

/// An icon size that grows with the user's font setting.
///
/// Android's font size slider scales text and leaves icons alone, so a fixed
/// 32dp icon next to a label that grows 30 percent inverts their relationship
/// at precisely the settings chosen by people who rely on the icon most. The
/// clamp stops a 2.0 scale from turning a 32dp glyph into a 64dp one that
/// pushes the label it belongs to off the tile.
double kdScaledIcon(BuildContext context, double size) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6).scale(size);
