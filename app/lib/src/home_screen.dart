import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import 'capture/capture_screen.dart' show cropName;
import 'locale_scope.dart';
import 'market/market.dart';
import 'providers.dart';
import 'router.dart';
import 'weather/weather.dart';
import 'weather/weather_l10n.dart';
import 'welcome/language_choice.dart';

const Key homeWorkTabKey = Key('home.tab.work');
const Key homeAskTabKey = Key('home.tab.ask');
const Key homeMarketTabKey = Key('home.tab.market');
const Key homeProfileTabKey = Key('home.tab.profile');

/// Kept as an alias for callers that still address the records destination.
/// Records now live inside Profile, matching the four-tab product structure.
@Deprecated('Use homeProfileTabKey')
const Key homeRecordsTabKey = homeProfileTabKey;
const Key homeAddWorkKey = Key('home.work.add');
const Key homeSaveQuestionKey = Key('home.ask.save');
const Key homeCaptureKey = Key('home.capture');
const Key homeScanFabKey = Key('home.scanFab');
const Key homeDetectDiseaseKey = Key('home.detectDisease');
const Key homeAssistantKey = Key('home.assistant');
const Key homeWeatherKey = Key('home.weather');
const Key homeViewAllPhotosKey = Key('home.records.viewAllPhotos');
const Key homeDiagnosisHistoryKey = Key('home.records.diagnosisHistory');
const Key homeAboutKey = Key('home.profile.about');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;
    final pages = <Widget>[
      const _WorkPage(),
      const _AskPage(),
      MarketTab(active: _index == 2),
      const _ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: KdLayout.pageGutter,
        title: Row(
          children: [
            KdBrandMark(size: 38, semanticLabel: l10n.appTitle),
            const SizedBox(width: KdSpacing.smd),
            Expanded(
              child: Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<AppLanguage>(
            tooltip: l10n.languageMenuTooltip,
            onSelected: (language) {
              unawaited(KdHaptics.selected());
              unawaited(
                LocaleScope.of(context).setLocale(Locale(language.code)),
              );
            },
            itemBuilder: (context) => [
              for (final choice in kLanguageChoices)
                CheckedPopupMenuItem(
                  value: choice.language,
                  checked: choice.language.code == current,
                  child: Text(
                    choice.name(l10n),
                    style: KdType.forLocale(
                      choice.locale,
                    ).bodyLarge?.copyWith(color: KdColors.inkStrong),
                  ),
                ),
            ],
            child: Semantics(
              button: true,
              label: l10n.languageMenuTooltip,
              child: Container(
                margin: const EdgeInsetsDirectional.only(end: KdSpacing.smd),
                padding: const EdgeInsets.symmetric(
                  horizontal: KdSpacing.smd,
                  vertical: KdSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: KdColors.surface,
                  borderRadius: BorderRadius.circular(KdRadius.pill),
                  border: Border.all(color: KdColors.outlineSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, size: KdIconSize.sm),
                    const SizedBox(width: KdSpacing.sm),
                    Text(
                      current.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              key: homeScanFabKey,
              tooltip: l10n.scanAction,
              backgroundColor: KdColors.actionLeaf,
              foregroundColor: KdColors.primaryPressed,
              onPressed: () {
                unawaited(KdHaptics.selected());
                context.push(AppRoutes.diagnose);
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.scanAction),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: KdColors.outlineSoft)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            unawaited(KdHaptics.selected());
            setState(() => _index = value);
          },
          destinations: [
            NavigationDestination(
              key: homeWorkTabKey,
              icon: const Icon(Icons.grass_outlined),
              selectedIcon: const Icon(Icons.grass),
              label: l10n.workTab,
            ),
            NavigationDestination(
              key: homeAskTabKey,
              icon: const Icon(Icons.search_outlined),
              selectedIcon: const Icon(Icons.search_rounded),
              label: l10n.askTab,
            ),
            NavigationDestination(
              key: homeMarketTabKey,
              icon: const Icon(Icons.trending_up_outlined),
              selectedIcon: const Icon(Icons.trending_up_rounded),
              label: l10n.marketTab,
            ),
            NavigationDestination(
              key: homeProfileTabKey,
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.profileTab,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkPage extends ConsumerWidget {
  const _WorkPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(recentFarmTasksProvider);
    final crop = ref.watch(selectedCropProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.scrollBottomInset,
      ),
      children: [
        Text(
          DateFormat.MMMEd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(DateTime.now()).toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: KdColors.inkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: KdSpacing.xs),
        Text(
          l10n.workHeading,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: KdSpacing.md),
        crop.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text(l10n.errorGeneric),
          data: (selected) => _CropContextCard(crop: selected),
        ),
        const SizedBox(height: KdSpacing.md),
        _ScanHero(
          onTap: () => context.push(AppRoutes.diagnose),
          title: l10n.detectDisease,
          body: l10n.detectDiseaseDescription,
          actionLabel: l10n.diseaseScanTitle,
          badgeLabel: l10n.diseaseExperimentalTitle,
        ),
        const SizedBox(height: KdSpacing.md),
        _ResponsiveShortcuts(
          children: [
            _WeatherSummaryCard(onTap: () => context.push(AppRoutes.weather)),
            _QuickAction(
              icon: Icons.menu_book_outlined,
              iconBackground: KdColors.brandGoldSoft,
              iconForeground: KdColors.brandGoldInk,
              title: l10n.askKrishiAssistant,
              body: l10n.askKrishiAssistantDescription,
              onTap: () => context.push(AppRoutes.assistant),
            ),
          ],
        ),
        const SizedBox(height: KdLayout.sectionGap),
        KdSectionHeader(
          title: l10n.workTab,
          action: _AdaptiveFilledAction(
            buttonKey: homeAddWorkKey,
            onPressed: () => _createTask(context, ref, FarmTaskKind.work),
            icon: Icons.add,
            label: l10n.addWork,
          ),
        ),
        const SizedBox(height: KdLayout.itemGap),
        tasks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(l10n.errorGeneric),
          data: (rows) {
            final work = rows
                .where((row) => row.kind == FarmTaskKind.work)
                .toList();
            final open = work.where((row) => !row.isCompleted).toList();
            final done = work.where((row) => row.isCompleted).toList();
            if (work.isEmpty) {
              return _EmptyCard(
                icon: Icons.task_alt,
                title: l10n.workEmptyTitle,
                body: l10n.workEmptyBody,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (open.isNotEmpty)
                  KdGroupedSurface(
                    children: [
                      for (final task in open)
                        _TaskRow(task: task, grouped: true),
                    ],
                  ),
                if (done.isNotEmpty) ...[
                  const SizedBox(height: KdLayout.sectionGap),
                  Text(
                    l10n.completedHeading(done.length),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: KdLayout.itemGap),
                  KdGroupedSurface(
                    children: [
                      for (final task in done.take(5))
                        _TaskRow(task: task, grouped: true),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({
    required this.onTap,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.badgeLabel,
  });

  final VoidCallback onTap;
  final String title;
  final String body;
  final String actionLabel;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) => KdHeroSurface(
    tone: KdHeroTone.leaf,
    child: Stack(
      children: [
        PositionedDirectional(
          end: -20,
          top: -22,
          child: ExcludeSemantics(
            child: Icon(
              Icons.eco_rounded,
              size: kdScaledIcon(context, 132),
              color: const Color(0x18123F24),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KdStatusPill(
              label: badgeLabel,
              icon: Icons.auto_awesome_outlined,
              backgroundColor: KdColors.surface,
              foregroundColor: KdColors.primaryPressed,
            ),
            const SizedBox(height: KdSpacing.lmd),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: KdColors.inkStrong),
            ),
            const SizedBox(height: KdSpacing.sm),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KdColors.inkBody),
            ),
            const SizedBox(height: KdSpacing.lmd),
            FilledButton.icon(
              key: homeCaptureKey,
              style: FilledButton.styleFrom(
                backgroundColor: KdColors.primaryPressed,
                foregroundColor: KdColors.onPrimary,
              ),
              onPressed: onTap,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(actionLabel),
            ),
          ],
        ),
      ],
    ),
  );
}

class _WeatherSummaryCard extends ConsumerWidget {
  const _WeatherSummaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(nepalWeatherControllerProvider);
    final snapshot = state.snapshot;
    final language = Localizations.localeOf(context).languageCode;
    final strings = localizedWeatherStrings(l10n);
    final condition = snapshot == null
        ? l10n.weatherCardBody
        : strings.condition(snapshot.current.condition);

    return Card(
      color: KdColors.skySoft,
      child: InkWell(
        key: homeWeatherKey,
        borderRadius: BorderRadius.circular(KdRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KdSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  KdIconWell(
                    icon: Icons.cloud_outlined,
                    backgroundColor: KdColors.surface,
                    foregroundColor: KdColors.skyInk,
                    size: 48,
                  ),
                  Icon(Icons.arrow_forward_rounded, color: KdColors.skyInk),
                ],
              ),
              const SizedBox(height: KdSpacing.smd),
              Text(
                snapshot == null
                    ? l10n.weatherTitle
                    : '${snapshot.current.temperatureC.round()}°  $condition',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: KdColors.inkStrong),
              ),
              const SizedBox(height: KdSpacing.xs),
              Text(
                snapshot == null ? condition : state.location.nameFor(language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: KdColors.skyInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KdRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                KdIconWell(
                  icon: icon,
                  backgroundColor: iconBackground,
                  foregroundColor: iconForeground,
                  size: 48,
                ),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
            const SizedBox(height: KdSpacing.smd),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: KdSpacing.xs),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ResponsiveShortcuts extends StatelessWidget {
  const _ResponsiveShortcuts({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.15;
      if (stack) {
        return Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                const SizedBox(height: KdSpacing.smd),
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1)
                const SizedBox(width: KdSpacing.smd),
            ],
          ],
        ),
      );
    },
  );
}

class _AdaptiveFilledAction extends StatelessWidget {
  const _AdaptiveFilledAction({
    required this.buttonKey,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tonal = false,
  });

  final Key buttonKey;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final copy = Text(label, textAlign: TextAlign.center, maxLines: 2);
    if (tonal) {
      return largeText
          ? FilledButton.tonal(
              key: buttonKey,
              onPressed: onPressed,
              child: copy,
            )
          : FilledButton.tonalIcon(
              key: buttonKey,
              onPressed: onPressed,
              icon: Icon(icon),
              label: copy,
            );
    }
    return largeText
        ? FilledButton(key: buttonKey, onPressed: onPressed, child: copy)
        : FilledButton.icon(
            key: buttonKey,
            onPressed: onPressed,
            icon: Icon(icon),
            label: copy,
          );
  }
}

class _CropContextCard extends ConsumerWidget {
  const _CropContextCard({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(cropCatalogProvider);
    final picker = PopupMenuButton<Crop>(
      tooltip: l10n.changeCrop,
      onSelected: (next) =>
          ref.read(selectedCropProvider.notifier).select(next),
      itemBuilder: (context) => [
        for (final available in catalog.available)
          CheckedPopupMenuItem(
            value: available,
            checked: available.key == crop.key,
            child: Text(cropName(l10n, available)),
          ),
      ],
      child: _CropChangeButton(label: l10n.changeCrop),
    );
    final summary = Row(
      children: [
        const Icon(Icons.eco_outlined, color: KdColors.primary),
        const SizedBox(width: KdSpacing.smd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.currentCrop,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                cropName(l10n, crop),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KdColors.primarySoft,
        borderRadius: BorderRadius.circular(KdRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KdLayout.cardPadding,
          vertical: KdSpacing.smd,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.1;
            if (largeText || constraints.maxWidth < 280) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  Align(alignment: Alignment.centerRight, child: picker),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: summary),
                picker,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CropChangeButton extends StatelessWidget {
  const _CropChangeButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return Container(
      constraints: const BoxConstraints(minHeight: KdSpacing.minTouchTarget),
      padding: EdgeInsets.symmetric(
        horizontal: largeText ? KdSpacing.smd : KdSpacing.md,
        vertical: KdSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: KdColors.surface,
        borderRadius: BorderRadius.circular(KdRadius.pill),
        border: Border.all(color: KdColors.outlineSoft),
      ),
      child: largeText
          ? Icon(
              Icons.swap_horiz_rounded,
              semanticLabel: label,
              color: KdColors.primaryPressed,
              size: kdScaledIcon(context, KdIconSize.md),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: KdColors.primaryPressed,
                  ),
                ),
                const SizedBox(width: KdSpacing.xs),
                const Icon(
                  Icons.expand_more_rounded,
                  color: KdColors.primaryPressed,
                  size: KdIconSize.sm,
                ),
              ],
            ),
    );
  }
}

class _AskPage extends ConsumerWidget {
  const _AskPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(recentFarmTasksProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.scrollBottomInset,
      ),
      children: [
        KdSectionHeader(
          title: l10n.cropDoctorTitle,
          subtitle: l10n.cropDoctorIntro,
        ),
        const SizedBox(height: KdSpacing.lg),
        _DoctorScanHero(
          key: homeDetectDiseaseKey,
          title: l10n.detectDisease,
          body: l10n.detectDiseaseDescription,
          onTap: () => context.push(AppRoutes.diagnose),
        ),
        const SizedBox(height: KdSpacing.md),
        _AssistantActionCard(
          key: homeAssistantKey,
          title: l10n.askKrishiAssistant,
          body: l10n.askKrishiAssistantDescription,
          badge: l10n.offlineGuideLabel,
          onTap: () => context.push(AppRoutes.assistant),
        ),
        const SizedBox(height: KdLayout.sectionGap),
        KdSectionHeader(
          title: l10n.savedQuestions,
          action: _AdaptiveFilledAction(
            buttonKey: homeSaveQuestionKey,
            onPressed: () => _createTask(context, ref, FarmTaskKind.question),
            icon: Icons.add_rounded,
            label: l10n.saveQuestion,
            tonal: true,
          ),
        ),
        const SizedBox(height: KdSpacing.smd),
        _NoticeCard(
          title: l10n.questionPrivateTitle,
          body: l10n.questionPrivateBody,
        ),
        const SizedBox(height: KdSpacing.smd),
        tasks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(l10n.errorGeneric),
          data: (rows) {
            final questions = rows
                .where((row) => row.kind == FarmTaskKind.question)
                .toList();
            if (questions.isEmpty) {
              return _EmptyCard(
                icon: Icons.question_answer_outlined,
                title: l10n.questionEmptyTitle,
                body: l10n.questionEmptyBody,
              );
            }
            return KdGroupedSurface(
              children: [
                for (final question in questions)
                  _TaskRow(task: question, grouped: true),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DoctorScanHero extends StatelessWidget {
  const _DoctorScanHero({
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KdHeroSurface(
    tone: KdHeroTone.leaf,
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KdRadius.xl),
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KdIconWell(
              icon: Icons.document_scanner_outlined,
              backgroundColor: KdColors.surface,
              foregroundColor: KdColors.primaryPressed,
              size: 64,
            ),
            const SizedBox(width: KdSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: KdColors.inkStrong),
                  ),
                  const SizedBox(height: KdSpacing.sm),
                  Text(
                    body,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: KdColors.inkBody),
                  ),
                  const SizedBox(height: KdSpacing.md),
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: CircleAvatar(
                      backgroundColor: KdColors.primaryPressed,
                      foregroundColor: KdColors.onPrimary,
                      child: Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AssistantActionCard extends StatelessWidget {
  const _AssistantActionCard({
    required this.title,
    required this.body,
    required this.badge,
    required this.onTap,
    super.key,
  });

  final String title;
  final String body;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: KdColors.surface,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KdRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const KdIconWell(
                  icon: Icons.forum_outlined,
                  backgroundColor: KdColors.brandGoldSoft,
                  foregroundColor: KdColors.brandGoldInk,
                  size: 52,
                ),
                const SizedBox(width: KdSpacing.smd),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
            const SizedBox(height: KdSpacing.smd),
            Text(body),
            const SizedBox(height: KdSpacing.smd),
            KdStatusPill(
              label: badge,
              icon: Icons.offline_bolt_outlined,
              backgroundColor: KdColors.primarySoft,
              foregroundColor: KdColors.primaryPressed,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfilePage extends ConsumerWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final observations = ref.watch(recentObservationsProvider);
    final diagnoses = ref.watch(recentDiagnosesProvider);
    final tasks = ref.watch(recentFarmTasksProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.scrollBottomInset,
      ),
      children: [
        KdSectionHeader(title: l10n.profileTab, subtitle: l10n.recordsIntro),
        const SizedBox(height: KdSpacing.lg),
        observations.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text(l10n.errorGeneric),
          data: (photos) => tasks.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Text(l10n.errorGeneric),
            data: (rows) {
              final completed = rows.where((row) => row.isCompleted).length;
              final questions = rows
                  .where((row) => row.kind == FarmTaskKind.question)
                  .length;
              return _ActivitySummary(
                items: [
                  _ActivityMetric(
                    icon: Icons.photo_outlined,
                    count: photos.length,
                    label: l10n.photosLabel,
                  ),
                  _ActivityMetric(
                    icon: Icons.task_alt_outlined,
                    count: completed,
                    label: l10n.completedLabel,
                  ),
                  _ActivityMetric(
                    icon: Icons.help_outline,
                    count: questions,
                    label: l10n.questionsLabel,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: KdLayout.sectionGap),
        KdSectionHeader(
          title: l10n.diagnosisHistory,
          action: TextButton(
            onPressed: () => context.push(AppRoutes.history),
            child: Text(l10n.viewScans),
          ),
        ),
        const SizedBox(height: KdLayout.itemGap),
        diagnoses.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text(l10n.errorGeneric),
          data: (rows) => KdGroupedSurface(
            children: [
              ListTile(
                key: homeDiagnosisHistoryKey,
                leading: const KdIconWell(
                  icon: Icons.document_scanner_outlined,
                  backgroundColor: KdColors.earthSoft,
                  foregroundColor: KdColors.earthInk,
                ),
                title: Text('${rows.length} ${l10n.scansLabel}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.history),
              ),
            ],
          ),
        ),
        const SizedBox(height: KdLayout.sectionGap),
        KdSectionHeader(
          title: l10n.cropPhotos,
          action: TextButton(
            key: homeViewAllPhotosKey,
            onPressed: () => context.push(AppRoutes.notebook),
            child: Text(l10n.viewAll),
          ),
        ),
        const SizedBox(height: KdLayout.itemGap),
        observations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(l10n.errorGeneric),
          data: (rows) => rows.isEmpty
              ? _EmptyCard(
                  icon: Icons.photo_library_outlined,
                  title: l10n.recordsEmptyTitle,
                  body: l10n.recordsEmptyBody,
                  action: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.capture),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l10n.takeCropPhoto),
                  ),
                )
              : KdGroupedSurface(
                  children: [
                    for (final row in rows.take(4))
                      _ObservationRow(observation: row, grouped: true),
                  ],
                ),
        ),
        const SizedBox(height: KdLayout.sectionGap),
        KdGroupedSurface(
          children: [
            ListTile(
              key: homeAboutKey,
              leading: const KdIconWell(
                icon: Icons.shield_outlined,
                backgroundColor: KdColors.primarySoft,
                foregroundColor: KdColors.primaryPressed,
              ),
              title: Text(l10n.aboutTitle),
              subtitle: Text(l10n.aboutPrivacyTitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.welcomeAbout),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityMetric {
  const _ActivityMetric({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.items});

  final List<_ActivityMetric> items;

  @override
  Widget build(BuildContext context) => Card(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25;
        if (stacked) {
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _MetricRow(item: items[index]),
                if (index != items.length - 1) const Divider(),
              ],
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: KdSpacing.md),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                Expanded(child: _MetricColumn(item: items[index])),
                if (index != items.length - 1)
                  const SizedBox(height: 64, child: VerticalDivider()),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.item});

  final _ActivityMetric item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: KdSpacing.md,
      vertical: KdSpacing.smd,
    ),
    child: Row(
      children: [
        Icon(item.icon, color: KdColors.primary),
        const SizedBox(width: KdSpacing.smd),
        Expanded(child: Text(item.label)),
        Text('${item.count}', style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.item});

  final _ActivityMetric item;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(item.icon, color: KdColors.primary),
      const SizedBox(height: KdSpacing.xs),
      Text('${item.count}', style: Theme.of(context).textTheme.titleLarge),
      Text(
        item.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _ObservationRow extends ConsumerWidget {
  const _ObservationRow({required this.observation, this.grouped = false});

  final Observation observation;
  final bool grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(
      locale,
    ).format(observation.createdAt.toLocal());
    final crop = observation.cropKey == null
        ? null
        : ref.read(cropCatalogProvider).byKey(observation.cropKey);
    final tile = ListTile(
      leading: const Icon(Icons.photo_outlined),
      title: Text(crop == null ? l10n.cropPhoto : cropName(l10n, crop)),
      subtitle: Text(observation.note ?? date),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('${AppRoutes.notebook}/${observation.id}'),
    );
    return grouped ? tile : Card(child: tile);
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, this.grouped = false});

  final FarmTask task;
  final bool grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final due = _dueLabel(context, task.dueAt);
    final tile = CheckboxListTile(
      value: task.isCompleted,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        task.title,
        style: task.isCompleted
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: due == null
          ? (task.kind == FarmTaskKind.question
                ? Text(task.isCompleted ? l10n.resolved : l10n.savedOnPhone)
                : null)
          : Text(due),
      onChanged: (checked) async {
        final next = checked == true
            ? task.complete(DateTime.now().toUtc())
            : task.reopen();
        await ref.read(servicesProvider).farmTaskStore.upsert(next);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                checked == true ? l10n.markedComplete : l10n.markedOpen,
              ),
            ),
          );
        }
      },
    );
    return grouped ? tile : Card(child: tile);
  }
}

String? _dueLabel(BuildContext context, DateTime? value) {
  if (value == null) return null;
  final l10n = AppLocalizations.of(context);
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  if (date == today) return l10n.dueToday;
  if (date == today.add(const Duration(days: 1))) return l10n.dueTomorrow;
  return l10n.dueOn(
    DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(local),
  );
}

Future<void> _createTask(
  BuildContext context,
  WidgetRef ref,
  FarmTaskKind kind,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  var dueChoice = 0;
  final title = kind == FarmTaskKind.work ? l10n.addWork : l10n.saveQuestion;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: FarmTask.maxTitleLength,
              minLines: kind == FarmTaskKind.question ? 2 : 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: kind == FarmTaskKind.work
                    ? l10n.workHint
                    : l10n.questionHint,
              ),
            ),
            if (kind == FarmTaskKind.work) ...[
              const SizedBox(height: KdSpacing.xs),
              Text(l10n.whenLabel),
              Wrap(
                spacing: KdSpacing.xs,
                children: [
                  ChoiceChip(
                    label: Text(l10n.noDueDate),
                    selected: dueChoice == 0,
                    onSelected: (_) => setDialogState(() => dueChoice = 0),
                  ),
                  ChoiceChip(
                    label: Text(l10n.today),
                    selected: dueChoice == 1,
                    onSelected: (_) => setDialogState(() => dueChoice = 1),
                  ),
                  ChoiceChip(
                    label: Text(l10n.tomorrow),
                    selected: dueChoice == 2,
                    onSelected: (_) => setDialogState(() => dueChoice = 2),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) {
    return;
  }
  final selectedCrop = ref.read(selectedCropProvider).valueOrNull;
  final now = DateTime.now();
  DateTime? due;
  if (kind == FarmTaskKind.work && dueChoice > 0) {
    final localDay = DateTime(now.year, now.month, now.day + dueChoice - 1, 12);
    due = localDay.toUtc();
  }
  final task = FarmTask(
    id: ref.read(servicesProvider).ids.newId(),
    title: controller.text,
    kind: kind,
    cropKey: selectedCrop?.key,
    createdAt: now.toUtc(),
    dueAt: due,
  );
  await ref.read(servicesProvider).farmTaskStore.upsert(task);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kind == FarmTaskKind.work ? l10n.workSaved : l10n.questionSaved,
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    color: KdColors.surfaceSunken,
    child: Padding(
      padding: const EdgeInsets.all(KdLayout.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: KdColors.inkMuted),
          const SizedBox(width: KdSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: KdSpacing.xxs),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(KdLayout.cardPadding),
      child: Column(
        children: [
          Icon(icon, color: KdColors.inkMuted, size: KdIconSize.xl),
          const SizedBox(height: KdSpacing.smd),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: KdSpacing.xxs),
          Text(body, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: KdSpacing.smd),
            action!,
          ],
        ],
      ),
    ),
  );
}
