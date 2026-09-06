import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import 'crop_weather_advisor.dart';
import 'crop_weather_fit_card.dart';
import 'weather_controller.dart';
import 'weather_models.dart';
import 'weather_strings.dart';

const Key weatherLocationKey = Key('weather.location');
const Key weatherRefreshKey = Key('weather.refresh');
const Key weatherRetryKey = Key('weather.retry');
const Key weatherStaleKey = Key('weather.stale');
const Key weatherFailureKey = Key('weather.failure');

class NepalWeatherScreen extends ConsumerStatefulWidget {
  const NepalWeatherScreen({required this.strings, super.key});

  final WeatherStrings strings;

  @override
  ConsumerState<NepalWeatherScreen> createState() => _NepalWeatherScreenState();
}

class _NepalWeatherScreenState extends ConsumerState<NepalWeatherScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(nepalWeatherControllerProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final state = ref.watch(nepalWeatherControllerProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final languageCode = Localizations.localeOf(context).languageCode;
    final snapshot = state.snapshot;
    final stale = snapshot?.isStaleAt(DateTime.now().toUtc()) ?? false;
    final cropOutlook = snapshot == null
        ? null
        : const CropWeatherAdvisor().assess(
            snapshot: snapshot,
            crops: ref.watch(cropCatalogProvider).available,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.title),
        actions: [
          IconButton(
            key: weatherRefreshKey,
            tooltip: strings.refresh,
            onPressed: state.isLoading
                ? null
                : () => ref
                      .read(nepalWeatherControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(nepalWeatherControllerProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KdLayout.pageGutter,
            KdLayout.pageGutter,
            KdLayout.pageGutter,
            KdLayout.scrollBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocationSelector(
                strings: strings,
                state: state,
                languageCode: languageCode,
                onChanged: (location) => unawaited(
                  ref
                      .read(nepalWeatherControllerProvider.notifier)
                      .selectLocation(location),
                ),
              ),
              if (state.isLoading) ...[
                const SizedBox(height: KdSpacing.smd),
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(KdRadius.sm)),
                  child: LinearProgressIndicator(),
                ),
              ],
              if (state.failure != null) ...[
                const SizedBox(height: KdSpacing.smd),
                _FailureNotice(
                  message: snapshot == null
                      ? strings.failure(state.failure!.kind)
                      : strings.cachedAfterFailure,
                  retryLabel: strings.retry,
                  showRetry: snapshot == null,
                  onRetry: () => ref
                      .read(nepalWeatherControllerProvider.notifier)
                      .refresh(),
                ),
              ],
              if (snapshot == null && state.isLoading) ...[
                const SizedBox(height: KdLayout.sectionGap),
                _LoadingPanel(message: strings.loading),
              ],
              if (snapshot != null) ...[
                if (stale) ...[
                  const SizedBox(height: KdSpacing.smd),
                  _StaleNotice(strings: strings),
                ],
                const SizedBox(height: KdLayout.sectionGap),
                _CurrentWeatherHero(snapshot: snapshot, strings: strings),
                const SizedBox(height: KdLayout.sectionGap),
                CropWeatherFitCard(
                  outlook: cropOutlook!,
                  strings: strings,
                  locale: locale,
                  locationName: snapshot.location.nameFor(languageCode),
                  providerName: snapshot.providerName,
                  savedForecast: stale,
                ),
                const SizedBox(height: KdLayout.sectionGap),
                Row(
                  children: [
                    Container(
                      width: KdSpacing.xxl,
                      height: KdSpacing.xxl,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KdColors.primarySoft,
                        borderRadius: BorderRadius.circular(KdRadius.md),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        color: KdColors.primary,
                      ),
                    ),
                    const SizedBox(width: KdSpacing.smd),
                    Expanded(
                      child: Text(
                        strings.sevenDayForecast,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KdLayout.itemGap),
                _ForecastList(
                  forecasts: snapshot.daily,
                  strings: strings,
                  locale: locale,
                ),
                const SizedBox(height: KdLayout.sectionGap),
                _SourceFooter(
                  snapshot: snapshot,
                  strings: strings,
                  locale: locale,
                ),
                const SizedBox(height: KdSpacing.smd),
                _ForecastDisclaimer(text: strings.disclaimer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector({
    required this.strings,
    required this.state,
    required this.languageCode,
    required this.onChanged,
  });

  final WeatherStrings strings;
  final NepalWeatherState state;
  final String languageCode;
  final ValueChanged<NepalWeatherLocation> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: weatherLocationKey,
      value: state.location.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: strings.location,
        prefixIcon: const Icon(Icons.location_on_outlined),
        filled: true,
        fillColor: KdColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KdRadius.md),
          borderSide: const BorderSide(color: KdColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KdRadius.md),
          borderSide: const BorderSide(color: KdColors.border),
        ),
      ),
      items: [
        for (final location in NepalWeatherPresets.all)
          DropdownMenuItem(
            value: location.id,
            child: Text(location.nameFor(languageCode)),
          ),
      ],
      onChanged: state.isLoading
          ? null
          : (id) {
              final next = id == null ? null : NepalWeatherPresets.byId(id);
              if (next != null) onChanged(next);
            },
    );
  }
}

class _CurrentWeatherHero extends StatelessWidget {
  const _CurrentWeatherHero({required this.snapshot, required this.strings});

  final WeatherSnapshot snapshot;
  final WeatherStrings strings;

  @override
  Widget build(BuildContext context) {
    final current = snapshot.current;
    final number = NumberFormat(
      '0.#',
      Localizations.localeOf(context).toString(),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KdRadius.xl),
        border: Border.all(color: KdColors.primaryPressed),
        boxShadow: KdElevation.raised,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: KdColors.primaryPressed,
            child: Padding(
              padding: const EdgeInsets.all(KdSpacing.lmd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          strings.currentConditions,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: KdColors.onPrimary),
                        ),
                      ),
                      Icon(
                        _conditionIcon(current.condition),
                        color: KdColors.onPrimary,
                        size: kdScaledIcon(context, KdIconSize.xl),
                      ),
                    ],
                  ),
                  const SizedBox(height: KdSpacing.smd),
                  Text(
                    '${number.format(current.temperatureC)} °C',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: KdColors.onPrimary,
                    ),
                  ),
                  const SizedBox(height: KdSpacing.xs),
                  Text(
                    strings.condition(current.condition),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: KdColors.onPrimary),
                  ),
                ],
              ),
            ),
          ),
          ColoredBox(
            color: KdColors.primarySoft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KdSpacing.md,
                vertical: KdSpacing.smd,
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        icon: Icons.water_drop_outlined,
                        label: strings.humidity,
                        value: '${current.relativeHumidityPercent}%',
                      ),
                    ),
                    const VerticalDivider(),
                    Expanded(
                      child: _HeroMetric(
                        icon: Icons.air_rounded,
                        label: strings.wind,
                        value: strings.windSpeed(
                          number.format(current.windSpeedKmh),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: KdIconSize.sm, color: KdColors.primaryPressed),
      const SizedBox(width: KdSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: KdSpacing.xxs),
            Text(value, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    ],
  );
}

class _ForecastList extends StatelessWidget {
  const _ForecastList({
    required this.forecasts,
    required this.strings,
    required this.locale,
  });

  final List<DailyWeatherForecast> forecasts;
  final WeatherStrings strings;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < forecasts.length; index++) ...[
            if (index > 0) const Divider(),
            _ForecastRow(
              forecast: forecasts[index],
              strings: strings,
              locale: locale,
              today: index == 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({
    required this.forecast,
    required this.strings,
    required this.locale,
    required this.today,
  });

  final DailyWeatherForecast forecast;
  final WeatherStrings strings;
  final String locale;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('0.#', locale);
    final probability = forecast.precipitationProbabilityPercent;
    final day = today
        ? strings.today
        : DateFormat.MMMEd(locale).format(forecast.date);
    final range = strings.temperatureRange(
      number.format(forecast.minimumTemperatureC),
      number.format(forecast.maximumTemperatureC),
    );

    return Padding(
      padding: const EdgeInsets.all(KdSpacing.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final enlargedText =
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              if (enlargedText || constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ForecastIdentity(
                      condition: forecast.condition,
                      day: day,
                      conditionText: strings.condition(forecast.condition),
                    ),
                    const SizedBox(height: KdSpacing.sm),
                    Text(range, style: Theme.of(context).textTheme.titleSmall),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _ForecastIdentity(
                      condition: forecast.condition,
                      day: day,
                      conditionText: strings.condition(forecast.condition),
                    ),
                  ),
                  const SizedBox(width: KdSpacing.smd),
                  Text(range, style: Theme.of(context).textTheme.titleSmall),
                ],
              );
            },
          ),
          const SizedBox(height: KdSpacing.smd),
          Wrap(
            spacing: KdSpacing.md,
            runSpacing: KdSpacing.sm,
            children: [
              if (probability != null)
                _CompactMetric(
                  icon: Icons.umbrella_outlined,
                  label: strings.rain,
                  value: strings.rainChance(probability),
                ),
              _CompactMetric(
                icon: Icons.water_outlined,
                label: strings.rain,
                value: strings.rainAmount(
                  number.format(forecast.precipitationSumMm),
                ),
              ),
              _CompactMetric(
                icon: Icons.air_rounded,
                label: strings.maximumWind,
                value: strings.windSpeed(
                  number.format(forecast.maximumWindSpeedKmh),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastIdentity extends StatelessWidget {
  const _ForecastIdentity({
    required this.condition,
    required this.day,
    required this.conditionText,
  });

  final WeatherCondition condition;
  final String day;
  final String conditionText;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: KdSpacing.xxl,
        height: KdSpacing.xxl,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: KdColors.primarySoft,
          borderRadius: BorderRadius.circular(KdRadius.md),
        ),
        child: Icon(_conditionIcon(condition), color: KdColors.primary),
      ),
      const SizedBox(width: KdSpacing.smd),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day, style: Theme.of(context).textTheme.titleMedium),
            Text(conditionText, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: KdIconSize.sm, color: KdColors.inkMuted),
      const SizedBox(width: KdSpacing.xs),
      Flexible(
        child: Text(
          '$label: $value',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
        ),
      ),
    ],
  );
}

class _SourceFooter extends StatelessWidget {
  const _SourceFooter({
    required this.snapshot,
    required this.strings,
    required this.locale,
  });

  final WeatherSnapshot snapshot;
  final WeatherStrings strings;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final updated = DateFormat.yMMMd(
      locale,
    ).add_jm().format(snapshot.current.observedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KdSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_done_outlined,
            size: KdIconSize.sm,
            color: KdColors.inkMuted,
          ),
          const SizedBox(width: KdSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.provider(snapshot.providerName),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  strings.updatedAt(updated),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastDisclaimer extends StatelessWidget {
  const _ForecastDisclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(KdSpacing.smd),
    decoration: BoxDecoration(
      color: KdColors.surfaceSunken,
      borderRadius: BorderRadius.circular(KdRadius.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: KdIconSize.sm,
          color: KdColors.inkMuted,
        ),
        const SizedBox(width: KdSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
          ),
        ),
      ],
    ),
  );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: KdSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: KdSpacing.md),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.strings});

  final WeatherStrings strings;

  @override
  Widget build(BuildContext context) => Container(
    key: weatherStaleKey,
    padding: const EdgeInsets.all(KdSpacing.smd),
    decoration: BoxDecoration(
      color: KdColors.stateUncertainBand,
      borderRadius: BorderRadius.circular(KdRadius.md),
      border: Border.all(color: KdColors.stateUncertainRail),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule_outlined, color: KdColors.stateUncertainRail),
        const SizedBox(width: KdSpacing.smd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.staleTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: KdSpacing.xs),
              Text(strings.staleBody),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FailureNotice extends StatelessWidget {
  const _FailureNotice({
    required this.message,
    required this.retryLabel,
    required this.showRetry,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final bool showRetry;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    key: weatherFailureKey,
    padding: const EdgeInsets.all(KdSpacing.smd),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(KdRadius.md),
      border: Border.all(color: KdColors.danger),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, color: KdColors.danger),
        const SizedBox(width: KdSpacing.smd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (showRetry) ...[
                const SizedBox(height: KdSpacing.xs),
                TextButton(
                  key: weatherRetryKey,
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

IconData _conditionIcon(WeatherCondition condition) => switch (condition) {
  WeatherCondition.clear => Icons.wb_sunny_outlined,
  WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
  WeatherCondition.fog => Icons.foggy,
  WeatherCondition.drizzle => Icons.grain,
  WeatherCondition.rain => Icons.umbrella_outlined,
  WeatherCondition.snow => Icons.ac_unit,
  WeatherCondition.showers => Icons.shower_outlined,
  WeatherCondition.thunderstorm => Icons.thunderstorm_outlined,
  WeatherCondition.unknown => Icons.cloud_outlined,
};
