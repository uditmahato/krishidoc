import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'crop_weather_advisor.dart';
import 'weather_strings.dart';

const Key cropWeatherFitKey = Key('weather.cropFit');
const Key cropWeatherInsufficientKey = Key('weather.cropFit.insufficient');

Key cropWeatherRowKey(String cropKey) => Key('weather.cropFit.$cropKey');

class CropWeatherFitCard extends StatelessWidget {
  const CropWeatherFitCard({
    required this.outlook,
    required this.strings,
    required this.locale,
    required this.locationName,
    required this.providerName,
    required this.savedForecast,
    super.key,
  });

  final CropWeatherOutlook outlook;
  final WeatherStrings strings;
  final String locale;
  final String locationName;
  final String providerName;
  final bool savedForecast;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('0.#', locale);

    return Card(
      key: cropWeatherFitKey,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: KdColors.primarySoft,
            child: Padding(
              padding: const EdgeInsets.all(KdSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const KdIconWell(
                        icon: Icons.eco_outlined,
                        backgroundColor: KdColors.surface,
                        foregroundColor: KdColors.primaryPressed,
                      ),
                      const SizedBox(width: KdSpacing.smd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.cropWeatherFitTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: KdSpacing.xs),
                            Text(strings.cropWeatherFitIntro(locationName)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KdSpacing.smd),
                  KdStatusPill(
                    label: savedForecast
                        ? strings.staleTitle
                        : strings.cropWeatherFitEstimate,
                    icon: savedForecast
                        ? Icons.schedule_outlined
                        : Icons.calendar_view_week_outlined,
                    backgroundColor: savedForecast
                        ? KdColors.stateUncertainBand
                        : KdColors.surface,
                    foregroundColor: savedForecast
                        ? KdColors.stateUncertainInk
                        : KdColors.primaryPressed,
                  ),
                ],
              ),
            ),
          ),
          if (!outlook.hasEnoughForecast || outlook.assessments.isEmpty)
            _InsufficientForecast(strings: strings)
          else ...[
            for (
              var index = 0;
              index < outlook.assessments.length;
              index++
            ) ...[
              if (index > 0) const Divider(),
              _CropFitRow(
                assessment: outlook.assessments[index],
                strings: strings,
                number: number,
              ),
            ],
            const Divider(),
            _ForecastContext(
              outlook: outlook,
              strings: strings,
              number: number,
            ),
          ],
          _LimitsNotice(text: strings.cropWeatherLimits),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KdSpacing.md,
              KdSpacing.smd,
              KdSpacing.md,
              KdSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: KdIconSize.sm,
                  color: KdColors.inkMuted,
                ),
                const SizedBox(width: KdSpacing.sm),
                Expanded(
                  child: Text(
                    strings.cropWeatherMethod(providerName),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: KdColors.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CropFitRow extends StatelessWidget {
  const _CropFitRow({
    required this.assessment,
    required this.strings,
    required this.number,
  });

  final CropWeatherAssessment assessment;
  final WeatherStrings strings;
  final NumberFormat number;

  @override
  Widget build(BuildContext context) {
    final visual = _FitVisual.forFit(assessment.fit, strings);
    final profile = assessment.profile;
    final reason = strings.cropWeatherPreferredDays(
      assessment.preferredDays,
      assessment.forecastDays,
      number.format(profile.preferredMinimumC),
      number.format(profile.preferredMaximumC),
    );

    return Padding(
      key: cropWeatherRowKey(assessment.crop.key),
      padding: const EdgeInsets.all(KdSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KdIconWell(
                icon: visual.icon,
                backgroundColor: visual.background,
                foregroundColor: visual.foreground,
              ),
              const SizedBox(width: KdSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.cropName(assessment.crop.key),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: KdSpacing.xs),
                    Text(reason),
                  ],
                ),
              ),
            ],
          );
          final status = KdStatusPill(
            label: visual.label,
            icon: visual.icon,
            backgroundColor: visual.background,
            foregroundColor: visual.foreground,
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: KdSpacing.smd),
                status,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: KdSpacing.smd),
              Flexible(child: status),
            ],
          );
        },
      ),
    );
  }
}

class _ForecastContext extends StatelessWidget {
  const _ForecastContext({
    required this.outlook,
    required this.strings,
    required this.number,
  });

  final CropWeatherOutlook outlook;
  final WeatherStrings strings;
  final NumberFormat number;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(KdSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.cropWeatherForecastContext,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: KdSpacing.smd),
        Wrap(
          spacing: KdSpacing.sm,
          runSpacing: KdSpacing.sm,
          children: [
            _ContextChip(
              icon: Icons.water_drop_outlined,
              label: strings.cropWeatherRainTotal(
                number.format(outlook.totalRainMm),
              ),
            ),
            _ContextChip(
              icon: Icons.air_rounded,
              label: strings.cropWeatherPeakWind(
                number.format(outlook.maximumWindSpeedKmh),
              ),
            ),
            if (outlook.thunderstormDays > 0)
              _ContextChip(
                icon: Icons.thunderstorm_outlined,
                label: strings.cropWeatherThunderstormDays(
                  outlook.thunderstormDays,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: KdSpacing.smd,
      vertical: KdSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: KdColors.skySoft,
      borderRadius: BorderRadius.circular(KdRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: KdIconSize.sm, color: KdColors.skyInk),
        const SizedBox(width: KdSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: KdColors.skyInk),
          ),
        ),
      ],
    ),
  );
}

class _InsufficientForecast extends StatelessWidget {
  const _InsufficientForecast({required this.strings});

  final WeatherStrings strings;

  @override
  Widget build(BuildContext context) => Padding(
    key: cropWeatherInsufficientKey,
    padding: const EdgeInsets.all(KdSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, color: KdColors.slate),
        const SizedBox(width: KdSpacing.smd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.cropWeatherFitInsufficient,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: KdSpacing.xs),
              Text(strings.cropWeatherFitNotEnoughForecast),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LimitsNotice extends StatelessWidget {
  const _LimitsNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(
      KdSpacing.md,
      KdSpacing.smd,
      KdSpacing.md,
      0,
    ),
    padding: const EdgeInsets.all(KdSpacing.smd),
    decoration: BoxDecoration(
      color: KdColors.stateUncertainBand,
      borderRadius: BorderRadius.circular(KdRadius.md),
      border: Border.all(color: KdColors.stateUncertainRail),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: KdIconSize.sm,
          color: KdColors.stateUncertainRail,
        ),
        const SizedBox(width: KdSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

final class _FitVisual {
  const _FitVisual({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  factory _FitVisual.forFit(CropWeatherFit fit, WeatherStrings strings) =>
      switch (fit) {
        CropWeatherFit.favorable => _FitVisual(
          label: strings.cropWeatherFitFavorable,
          icon: Icons.check_circle_outline_rounded,
          background: KdColors.stateConfidentBand,
          foreground: KdColors.stateConfidentInk,
        ),
        CropWeatherFit.mixed => _FitVisual(
          label: strings.cropWeatherFitMixed,
          icon: Icons.adjust_rounded,
          background: KdColors.stateUncertainBand,
          foreground: KdColors.stateUncertainInk,
        ),
        CropWeatherFit.weak => _FitVisual(
          label: strings.cropWeatherFitWeak,
          icon: Icons.info_outline_rounded,
          background: KdColors.stateOutOfScopeBand,
          foreground: KdColors.stateOutOfScopeInk,
        ),
        CropWeatherFit.insufficientData => _FitVisual(
          label: strings.cropWeatherFitInsufficient,
          icon: Icons.help_outline_rounded,
          background: KdColors.stateOutOfScopeBand,
          foreground: KdColors.stateOutOfScopeInk,
        ),
      };

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}
