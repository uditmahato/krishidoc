import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import 'market_controller.dart';
import 'market_models.dart';

const Key marketRefreshKey = Key('market.refresh');
const Key marketSearchKey = Key('market.search');
const Key marketFailureKey = Key('market.failure');
const Key marketSavedKey = Key('market.saved');
const Key marketPriceListKey = Key('market.priceList');

/// Market destination inside Home's persistent four-tab shell.
///
/// [active] prevents the IndexedStack from fetching data during app startup.
/// The official page is requested only when the farmer first opens Market.
class MarketTab extends ConsumerStatefulWidget {
  const MarketTab({required this.active, super.key});

  final bool active;

  @override
  ConsumerState<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends ConsumerState<MarketTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.active) _loadAfterBuild();
  }

  @override
  void didUpdateWidget(MarketTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _loadAfterBuild();
  }

  void _loadAfterBuild() {
    Future<void>.microtask(() {
      if (mounted) {
        unawaited(ref.read(marketControllerProvider.notifier).ensureLoaded());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(marketControllerProvider);
    final snapshot = state.snapshot;
    final quotes = snapshot == null
        ? const <MarketQuote>[]
        : snapshot.quotes.where((quote) => quote.matches(_query)).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(marketControllerProvider.notifier).refresh(),
      child: CustomScrollView(
        key: marketPriceListKey,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              KdLayout.pageGutter,
              KdLayout.pageGutter,
              KdLayout.pageGutter,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                KdSectionHeader(
                  title: l10n.marketTab,
                  subtitle: l10n.marketIntro,
                  action: IconButton.outlined(
                    key: marketRefreshKey,
                    tooltip: l10n.marketRefresh,
                    onPressed: state.isLoading
                        ? null
                        : () => ref
                              .read(marketControllerProvider.notifier)
                              .refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
                if (state.isLoading) ...[
                  const SizedBox(height: KdSpacing.smd),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(
                      Radius.circular(KdRadius.sm),
                    ),
                    child: LinearProgressIndicator(),
                  ),
                ],
                if (state.failure != null) ...[
                  const SizedBox(height: KdSpacing.smd),
                  _MarketFailureNotice(
                    message: snapshot == null
                        ? _failureText(l10n, state.failure!.kind)
                        : l10n.marketCachedAfterFailure,
                    onRetry: () =>
                        ref.read(marketControllerProvider.notifier).refresh(),
                  ),
                ],
                if (snapshot == null) ...[
                  const SizedBox(height: KdLayout.sectionGap),
                  if (state.isLoading && state.failure == null)
                    _MarketLoadingPanel(message: l10n.marketLoading),
                ],
                if (snapshot != null) ...[
                  const SizedBox(height: KdLayout.sectionGap),
                  _MarketSourceCard(
                    snapshot: snapshot,
                    isLoading: state.isLoading,
                    isSaved: state.isFromCache || state.failure != null,
                  ),
                  const SizedBox(height: KdSpacing.md),
                  TextField(
                    key: marketSearchKey,
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: l10n.marketSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).deleteButtonTooltip,
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: KdSpacing.smd),
                  Text(
                    l10n.marketOfficialNames,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
                  ),
                  const SizedBox(height: KdSpacing.md),
                ],
              ]),
            ),
          ),
          if (snapshot != null && quotes.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: KdLayout.pageGutter,
              ),
              sliver: SliverToBoxAdapter(
                child: _MarketEmptySearch(message: l10n.marketNoMatches),
              ),
            ),
          if (quotes.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: KdLayout.pageGutter,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: KdLayout.itemGap);
                  }
                  return _MarketQuoteCard(quote: quotes[index ~/ 2]);
                }, childCount: quotes.length * 2 - 1),
              ),
            ),
          if (snapshot != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                KdLayout.pageGutter,
                KdLayout.sectionGap,
                KdLayout.pageGutter,
                KdLayout.scrollBottomInset,
              ),
              sliver: SliverToBoxAdapter(
                child: _MarketDisclaimer(text: l10n.marketWholesaleNotice),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketSourceCard extends StatelessWidget {
  const _MarketSourceCard({
    required this.snapshot,
    required this.isLoading,
    required this.isSaved,
  });

  final MarketSnapshot snapshot;
  final bool isLoading;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fetched = DateFormat.yMMMd(
      locale,
    ).add_jm().format(snapshot.fetchedAt.toLocal());
    final status = isLoading
        ? l10n.marketRefreshing
        : isSaved
        ? l10n.marketSavedCopy
        : l10n.marketLatestOfficial;

    return KdHeroSurface(
      tone: KdHeroTone.leaf,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: KdSpacing.sm,
            runSpacing: KdSpacing.sm,
            children: [
              KdStatusPill(
                key: isSaved ? marketSavedKey : null,
                label: status,
                icon: isLoading
                    ? Icons.sync_rounded
                    : isSaved
                    ? Icons.history_rounded
                    : Icons.verified_outlined,
                backgroundColor: KdColors.surface,
              ),
              KdStatusPill(
                label: '${snapshot.quotes.length} ${l10n.marketItems}',
                icon: Icons.inventory_2_outlined,
                backgroundColor: KdColors.surface,
              ),
            ],
          ),
          const SizedBox(height: KdSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KdIconWell(
                icon: Icons.storefront_outlined,
                backgroundColor: KdColors.surface,
                foregroundColor: KdColors.primaryPressed,
              ),
              const SizedBox(width: KdSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.marketSourceName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: KdSpacing.xs),
                    Text(l10n.marketPublishedDate(snapshot.publishedDateLabel)),
                    Text(
                      l10n.marketRetrievedAt(fetched),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
                    ),
                    const SizedBox(height: KdSpacing.xs),
                    Text(
                      snapshot.providerUrl.host,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KdColors.primaryPressed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketQuoteCard extends StatelessWidget {
  const _MarketQuoteCard({required this.quote});

  final MarketQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final average = _formatPrice(quote.average, locale);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KdLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    quote.commodityName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: KdSpacing.smd),
                KdStatusPill(
                  label: quote.unit,
                  backgroundColor: KdColors.surfaceSunken,
                  foregroundColor: KdColors.inkBody,
                ),
              ],
            ),
            const SizedBox(height: KdSpacing.md),
            Text(
              l10n.marketAverage,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: KdColors.inkMuted),
            ),
            const SizedBox(height: KdSpacing.xxs),
            Text(
              '${l10n.marketCurrencySymbol} $average',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: KdColors.primaryPressed,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: KdSpacing.smd),
            const Divider(),
            const SizedBox(height: KdSpacing.smd),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35;
                final minimum = _PriceBound(
                  label: l10n.marketMinimum,
                  value:
                      '${l10n.marketCurrencySymbol} ${_formatPrice(quote.minimum, locale)}',
                );
                final maximum = _PriceBound(
                  label: l10n.marketMaximum,
                  value:
                      '${l10n.marketCurrencySymbol} ${_formatPrice(quote.maximum, locale)}',
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      minimum,
                      const SizedBox(height: KdSpacing.smd),
                      maximum,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: minimum),
                    const SizedBox(width: KdSpacing.md),
                    Expanded(child: maximum),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceBound extends StatelessWidget {
  const _PriceBound({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
      ),
      const SizedBox(height: KdSpacing.xxs),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _MarketFailureNotice extends StatelessWidget {
  const _MarketFailureNotice({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: marketFailureKey,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KdColors.stateUncertainBand,
          borderRadius: BorderRadius.circular(KdRadius.md),
          border: Border.all(color: KdColors.stateUncertainRail),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KdSpacing.smd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sync_problem_outlined,
                    color: KdColors.stateUncertainInk,
                  ),
                  const SizedBox(width: KdSpacing.smd),
                  Expanded(child: Text(message)),
                ],
              ),
              const SizedBox(height: KdSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(l10n.commonRetry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketLoadingPanel extends StatelessWidget {
  const _MarketLoadingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(KdSpacing.lg),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: KdSpacing.md),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _MarketEmptySearch extends StatelessWidget {
  const _MarketEmptySearch({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(KdSpacing.lg),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: KdIconSize.xl,
            color: KdColors.inkMuted,
          ),
          const SizedBox(height: KdSpacing.smd),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _MarketDisclaimer extends StatelessWidget {
  const _MarketDisclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: KdColors.surfaceWarm,
      borderRadius: BorderRadius.circular(KdRadius.md),
      border: Border.all(color: KdColors.outlineSoft),
    ),
    child: Padding(
      padding: const EdgeInsets.all(KdSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: KdColors.brandGoldInk),
          const SizedBox(width: KdSpacing.smd),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

String _failureText(AppLocalizations l10n, MarketFailureKind kind) =>
    switch (kind) {
      MarketFailureKind.network => l10n.marketNetworkError,
      MarketFailureKind.serviceUnavailable => l10n.marketServiceError,
      MarketFailureKind.invalidData => l10n.marketDataError,
      MarketFailureKind.unknown => l10n.marketUnknownError,
    };

String _formatPrice(double value, String locale) {
  final isWhole = value == value.truncateToDouble();
  final format = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = isWhole ? 0 : 2
    ..maximumFractionDigits = isWhole ? 0 : 2;
  return format.format(value);
}
