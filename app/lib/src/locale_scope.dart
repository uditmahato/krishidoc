import 'package:flutter/widgets.dart';

/// In-memory locale switching for the shell. Persistence arrives with the
/// settings store (M2); this widget's API will not change when it does.
class LocaleScope extends InheritedWidget {
  const LocaleScope({
    required this.locale,
    required this.setLocale,
    required super.child,
    super.key,
  });

  final Locale? locale;

  /// Returns when the choice is durable, not when it has been applied.
  ///
  /// The repaint is synchronous inside the implementation, so callers that do
  /// not care can ignore the future. The chooser does care: it navigates on
  /// completion, so that the screen after it cannot be reached in a state
  /// where the language has been shown but not stored.
  final Future<void> Function(Locale locale) setLocale;

  static LocaleScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope missing above this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) => locale != oldWidget.locale;
}
