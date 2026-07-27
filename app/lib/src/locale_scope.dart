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
  final ValueChanged<Locale> setLocale;

  static LocaleScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope missing above this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) => locale != oldWidget.locale;
}
