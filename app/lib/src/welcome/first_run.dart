import 'package:core_domain/core_domain.dart';

import '../router.dart';

/// The whole first-run gate, as one pure function.
///
/// One stored key and no second flag. An `onboardingCompleted` alongside the
/// language would be two keys that can disagree, and the disagreement would be
/// invisible until a farmer hit it; the only question this module asks is the
/// one `SettingsKeys.selectedLanguage` already answers, which is whether this
/// reader has ever told us what they read.
///
/// A garbage stored value, say a `'bn'` written by some future build, returns
/// null from [AppLanguage.fromCode] and lands on the chooser. That is the
/// correct degraded behaviour and it falls out of the existing parser rather
/// than being coded for separately.
///
/// Pure and Flutter-free so the boot decision is testable without pumping a
/// widget, and so `main()` and the test helper can call the same function
/// instead of maintaining two implementations of it.
String initialLocationFor(String? storedLanguage) =>
    AppLanguage.fromCode(storedLanguage) == null
    ? AppRoutes.welcomeLanguage
    : AppRoutes.home;
