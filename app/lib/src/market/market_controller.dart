import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'market_cache.dart';
import 'market_models.dart';
import 'market_service.dart';

final marketServiceProvider = Provider<MarketService>(
  (ref) => KalimatiMarketService(),
);

/// Overridden with [FileMarketSnapshotCache] by `main()` and with the memory
/// implementation in widget tests. Keeping the port here makes filesystem
/// access invisible to both the page and the network adapter.
final marketSnapshotCacheProvider = Provider<MarketSnapshotCache>(
  (ref) => MemoryMarketSnapshotCache(),
);

final marketControllerProvider =
    NotifierProvider<MarketController, MarketState>(MarketController.new);

final class MarketState {
  const MarketState({
    this.snapshot,
    this.failure,
    this.isLoading = false,
    this.isFromCache = false,
  });

  final MarketSnapshot? snapshot;
  final MarketFailure? failure;
  final bool isLoading;

  /// True until a live request succeeds during this process.
  final bool isFromCache;
}

final class MarketController extends Notifier<MarketState> {
  var _requestSerial = 0;
  var _hasLoaded = false;

  @override
  MarketState build() => const MarketState();

  /// Restores a last-known-good snapshot first, then checks the official page.
  Future<void> ensureLoaded() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    state = MarketState(
      snapshot: state.snapshot,
      isLoading: true,
      isFromCache: state.isFromCache,
    );

    MarketSnapshot? cached;
    try {
      cached = await ref.read(marketSnapshotCacheProvider).read();
    } on Object {
      // A cache is an availability aid, never a prerequisite for live data.
    }
    if (cached != null) {
      state = MarketState(snapshot: cached, isLoading: true, isFromCache: true);
    }
    await _refresh(cached ?? state.snapshot);
  }

  Future<void> refresh() async {
    _hasLoaded = true;
    await _refresh(state.snapshot);
  }

  Future<void> _refresh(MarketSnapshot? cached) async {
    final request = ++_requestSerial;
    state = MarketState(
      snapshot: cached,
      isLoading: true,
      isFromCache: state.isFromCache,
    );

    try {
      final snapshot = await ref.read(marketServiceProvider).fetch();
      if (request != _requestSerial) return;
      state = MarketState(snapshot: snapshot);
      try {
        await ref.read(marketSnapshotCacheProvider).write(snapshot);
      } on Object {
        // A full live list remains useful even if this device cannot save it.
      }
    } on MarketServiceException catch (error) {
      if (request != _requestSerial) return;
      state = MarketState(
        snapshot: cached,
        failure: MarketFailure(error.kind),
        isFromCache: cached != null,
      );
    } on Object {
      if (request != _requestSerial) return;
      state = MarketState(
        snapshot: cached,
        failure: const MarketFailure(MarketFailureKind.unknown),
        isFromCache: cached != null,
      );
    }
  }
}
