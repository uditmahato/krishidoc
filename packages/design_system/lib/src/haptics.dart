import 'package:flutter/services.dart';

/// The app's haptic vocabulary, in one place.
///
/// Routed through `flutter/services`, so there is no extra dependency and no
/// VIBRATE permission: these go through `View.performHapticFeedback`, which
/// respects the system haptic setting. That setting is off by default on many
/// budget handsets, which leads to the one rule that matters here:
///
/// **A haptic is never the only channel.** Every call below is paired with
/// something visible. If it were the sole signal, it would be a signal the
/// majority of this app's users never receive.
///
/// Deliberately absent: home tile taps (the ink response already plays the
/// system click), page transitions, snackbars, and scrolling. Also absent for
/// now is the tick when the capture gate arms, because it needs the coaching
/// hysteresis to exist first: firing on every 5Hz assessment would turn a hand
/// hovering near the blur threshold into a pager.
abstract final class KdHaptics {
  /// A destructive or irreversible control was pressed.
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// The shutter was pressed. Fired synchronously before any await, because
  /// the confirmation has to arrive with the tap rather than with the result
  /// of the tap; without it the second tap is inevitable.
  static Future<void> shutter() => HapticFeedback.mediumImpact();

  /// Something the user waited for finished.
  static Future<void> completed() => HapticFeedback.lightImpact();

  /// A choice was committed: a crop, a language, a list selection.
  static Future<void> selected() => HapticFeedback.selectionClick();

  /// An action was refused, or something failed.
  static Future<void> refused() => HapticFeedback.heavyImpact();
}
