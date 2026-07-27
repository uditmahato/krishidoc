import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_services.dart';

/// Overridden at the root (main or test pump); reading it unoverridden is a
/// wiring bug and fails loudly.
final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('servicesProvider must be overridden at the root'),
);

/// Newest-first window of stored diagnoses for the History screen.
final recentDiagnosesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(servicesProvider).diagnosisStore.watchRecent(),
);
