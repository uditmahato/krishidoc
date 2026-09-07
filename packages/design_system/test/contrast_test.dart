import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette, made falsifiable.
///
/// This suite exists because of a specific failure. The first token file
/// carried its contrast figures in code comments, four of them were wrong, and
/// the headline figure was overstated in the flattering direction. Worse, the
/// theme discarded the tokens entirely and seeded a Material palette from
/// them, so the colour that was audited was never the colour that shipped.
/// Comments cannot fail a build. These assertions can.
///
/// The same discipline the sealed `DiagnosisPresentation` applies to result
/// states (you cannot render a diagnosis without stating its certainty)
/// applies here: you cannot change a colour without restating what it is
/// legible against.
void main() {
  /// Asserts and, on failure, reports the real number rather than just
  /// "expected true". A contrast failure is only actionable if you can see
  /// how far off it is.
  void expectRatio(
    String what,
    Color foreground,
    Color background,
    double minimum,
  ) {
    final actual = contrastRatio(foreground, background);
    expect(
      actual,
      greaterThanOrEqualTo(minimum),
      reason:
          '$what measured ${actual.toStringAsFixed(2)}:1, '
          'needs at least ${minimum.toStringAsFixed(1)}:1',
    );
  }

  group('the calculator itself', () {
    // If this maths is wrong, every other assertion in the file is a
    // comforting lie, so it is checked against known values first.
    test('matches the canonical WCAG reference pairs', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
      expect(
        contrastRatio(const Color(0xFF767676), Colors.white),
        closeTo(4.54, 0.01),
      );
      expect(
        contrastRatio(Colors.white, const Color(0xFF808080)),
        closeTo(3.95, 0.01),
      );
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 0.001));
    });
  });

  group('text on the surfaces we actually paint', () {
    test('ink clears AA on both white and canvas', () {
      expectRatio(
        'inkStrong on surface',
        KdColors.inkStrong,
        KdColors.surface,
        4.5,
      );
      expectRatio(
        'inkStrong on canvas',
        KdColors.inkStrong,
        KdColors.canvas,
        4.5,
      );
      expectRatio(
        'inkBody on surface',
        KdColors.inkBody,
        KdColors.surface,
        4.5,
      );
      expectRatio('inkBody on canvas', KdColors.inkBody, KdColors.canvas, 4.5);
      expectRatio(
        'inkMuted on surface',
        KdColors.inkMuted,
        KdColors.surface,
        4.5,
      );
      expectRatio(
        'inkMuted on canvas',
        KdColors.inkMuted,
        KdColors.canvas,
        4.5,
      );
    });

    test('body ink holds a wide margin, because sunlight eats contrast', () {
      // Veiling glare in open sun can cut effective contrast by a factor of
      // five or more. A body ratio that only just clears 4.5:1 indoors is
      // unreadable in a field, so body copy is held far above the minimum.
      expectRatio(
        'inkBody on surface',
        KdColors.inkBody,
        KdColors.surface,
        12.0,
      );
    });

    test('muted ink survives the sunken fill it is painted on', () {
      // The not-ready row on Home puts its second line on surfaceSunken. That
      // sentence is one of the channels carrying "this is switched off", so it
      // has to stay readable on the fill that is also carrying it.
      expectRatio(
        'inkMuted on surfaceSunken',
        KdColors.inkMuted,
        KdColors.surfaceSunken,
        4.5,
      );
    });

    test('the light action and navigation surfaces retain strong ink', () {
      expectRatio(
        'inkStrong on actionLeaf',
        KdColors.inkStrong,
        KdColors.actionLeaf,
        4.5,
      );
      expectRatio(
        'inkBody on actionLeaf',
        KdColors.inkBody,
        KdColors.actionLeaf,
        4.5,
      );
      expectRatio(
        'primaryPressed on navigation',
        KdColors.primaryPressed,
        KdColors.navigation,
        4.5,
      );
    });

    test('the disabled label stays readable, which WCAG does not require', () {
      // Deliberately stricter than the standard. The shutter is disabled by
      // default while the frame is not yet good enough, and a farmer who
      // cannot read the coaching line must still see a control that is
      // waiting rather than one that is broken.
      expectRatio(
        'inkDisabled on surfaceSunken',
        KdColors.inkDisabled,
        KdColors.surfaceSunken,
        4.5,
      );
    });
  });

  group('brand and semantic accents', () {
    test('every accent clears AA on white', () {
      expectRatio('primary', KdColors.primary, KdColors.surface, 4.5);
      expectRatio(
        'primaryPressed',
        KdColors.primaryPressed,
        KdColors.surface,
        4.5,
      );
      expectRatio('warning', KdColors.warning, KdColors.surface, 4.5);
      expectRatio('danger', KdColors.danger, KdColors.surface, 4.5);
      expectRatio('slate', KdColors.slate, KdColors.surface, 4.5);
    });

    test('primary also clears AA on the tinted canvas', () {
      expectRatio('primary on canvas', KdColors.primary, KdColors.canvas, 4.5);
    });

    test('white on primary is legible, so filled buttons are safe', () {
      expectRatio(
        'onPrimary on primary',
        KdColors.onPrimary,
        KdColors.primary,
        4.5,
      );
    });
  });

  group('boundaries', () {
    test('the border clears 3:1 on both sides of every edge it draws', () {
      // A card edge has white on one side and canvas on the other. A border
      // that only clears one of them is invisible along half its length.
      expectRatio('border on surface', KdColors.border, KdColors.surface, 3.0);
      expectRatio('border on canvas', KdColors.border, KdColors.canvas, 3.0);
      // The not-ready row is the same card with a sunken fill, so the shared
      // cardTheme border has a third surface to survive. It is the closest of
      // the three, which is why it is asserted rather than assumed.
      expectRatio(
        'border on surfaceSunken',
        KdColors.border,
        KdColors.surfaceSunken,
        3.0,
      );
    });

    test('card fill against canvas is NOT a boundary, by measurement', () {
      // Recorded rather than fixed. White on canvas is about 1.12:1, so the
      // fill difference is decorative and the border is load bearing. M3's
      // defaults relied on a 1dp shadow here, which is why cards were
      // effectively edgeless in sunlight. If someone later deletes the border
      // believing the fills separate, this assertion is the counterexample.
      expect(
        contrastRatio(KdColors.surface, KdColors.canvas),
        lessThan(3.0),
        reason: 'fill difference alone cannot delineate a card',
      );
    });
  });

  group('diagnosis states', () {
    test('each state rail is visible against the surfaces it sits on', () {
      expectRatio(
        'confident rail',
        KdColors.stateConfidentRail,
        KdColors.surface,
        3.0,
      );
      expectRatio(
        'uncertain rail',
        KdColors.stateUncertainRail,
        KdColors.surface,
        3.0,
      );
      expectRatio(
        'out-of-scope rail',
        KdColors.stateOutOfScopeRail,
        KdColors.surface,
        3.0,
      );
    });

    test('ink on each tinted band clears AA', () {
      expectRatio(
        'confident ink on band',
        KdColors.stateConfidentInk,
        KdColors.stateConfidentBand,
        4.5,
      );
      expectRatio(
        'uncertain ink on band',
        KdColors.stateUncertainInk,
        KdColors.stateUncertainBand,
        4.5,
      );
      expectRatio(
        'out-of-scope ink on band',
        KdColors.stateOutOfScopeInk,
        KdColors.stateOutOfScopeBand,
        4.5,
      );
    });

    test(
      'colour alone cannot separate the three states, and that is arithmetic',
      () {
        // For a rail to read as a boundary on white it needs at least 3:1
        // against white, which puts a ceiling on its luminance. Three colours
        // all under that ceiling span at most roughly 3.5:1 between the
        // darkest and lightest, so the middle one cannot clear 3:1 against
        // either neighbour no matter which hues are chosen.
        //
        // This is asserted, not lamented. It is the reason state must always be
        // carried by glyph and by words as well, and it is why an earlier
        // review's measurement of 1.19:1 between two state colours was not a
        // palette bug to be tuned away.
        final pairs = <double>[
          contrastRatio(
            KdColors.stateConfidentRail,
            KdColors.stateUncertainRail,
          ),
          contrastRatio(
            KdColors.stateUncertainRail,
            KdColors.stateOutOfScopeRail,
          ),
          contrastRatio(
            KdColors.stateConfidentRail,
            KdColors.stateOutOfScopeRail,
          ),
        ];
        expect(
          pairs.every((r) => r < 4.5),
          isTrue,
          reason:
              'if this ever passes 4.5:1 the ceiling argument has changed and '
              'the colour-is-not-alone rule should be revisited, not deleted',
        );
      },
    );
  });

  group('capture coaching', () {
    test('both banner states are legible over any camera frame', () {
      // The banner floats over live video, which may be a white sheet of
      // paper or an overcast sky, so both fills are opaque and dark and the
      // text is white on both.
      expectRatio(
        'ink on ready fill',
        KdColors.coachInk,
        KdColors.coachReadyFill,
        4.5,
      );
      expectRatio(
        'ink on busy fill',
        KdColors.coachInk,
        KdColors.coachBusyFill,
        4.5,
      );
    });

    test('the fills do NOT carry readiness, so the shutter must', () {
      // Measured at about 1.95:1. Both fills have to be dark enough for white
      // text, which caps how far apart they can be. Readiness is therefore
      // signalled by the shutter arming, by the glyph, and by the words.
      expect(
        contrastRatio(KdColors.coachReadyFill, KdColors.coachBusyFill),
        lessThan(3.0),
      );
    });
  });

  group('the theme paints the tokens', () {
    // The regression guard for the defect that motivated this whole module.
    // ColorScheme.fromSeed(#1B5E20) returns #3C6939. If anyone reintroduces
    // seeding, these fail immediately instead of shipping an unaudited green.
    test(
      'the colour scheme carries the audited values, not a seeded palette',
      () {
        final scheme = kdLightTheme().colorScheme;
        expect(scheme.primary, KdColors.primary);
        expect(scheme.onPrimary, KdColors.onPrimary);
        expect(scheme.surface, KdColors.surface);
        expect(scheme.error, KdColors.danger);
        expect(scheme.outline, KdColors.border);
        expect(scheme.onSurface, KdColors.inkBody);
        expect(scheme.onSurfaceVariant, KdColors.inkMuted);
      },
    );

    test('the scaffold sits on canvas and cards sit on surface', () {
      final theme = kdLightTheme();
      expect(theme.scaffoldBackgroundColor, KdColors.canvas);
      expect(theme.cardTheme.color, KdColors.surface);
      expect(theme.cardTheme.elevation, 1);
      expect(
        theme.cardTheme.margin,
        EdgeInsets.zero,
        reason: 'the default 4dp margin silently doubled every list gap',
      );
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(
        shape.side.color,
        KdColors.outlineSoft,
        reason:
            'editorial cards use the quiet edge; controls and safety states '
            'still opt into the stronger functional border',
      );
    });

    test('disabled filled buttons keep a readable label', () {
      final style = kdLightTheme().filledButtonTheme.style!;
      final fill = style.backgroundColor!.resolve({WidgetState.disabled})!;
      final label = style.foregroundColor!.resolve({WidgetState.disabled})!;
      expectRatio('disabled shutter label', label, fill, 4.5);
    });

    test('every themed button clears the 48dp touch minimum', () {
      final theme = kdLightTheme();
      for (final entry in <String, ButtonStyle?>{
        'filled': theme.filledButtonTheme.style,
        'outlined': theme.outlinedButtonTheme.style,
        'text': theme.textButtonTheme.style,
      }.entries) {
        final size = entry.value!.minimumSize!.resolve({})!;
        expect(
          size.height,
          greaterThanOrEqualTo(KdSpacing.minTouchTarget),
          reason: '${entry.key} button height',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(KdSpacing.minTouchTarget),
          reason:
              '${entry.key} button width: Size.fromHeight leaves the minimum '
              'width at zero, which reads as a touch-target guarantee '
              'without being one',
        );
      }
    });
  });

  group('typography', () {
    test('Devanagari gets its own metrics, not English ones', () {
      final latin = KdType.forLocale(const Locale('en'));
      final deva = KdType.forLocale(const Locale('ne'));
      expect(
        deva.bodyLarge!.height,
        greaterThan(latin.bodyLarge!.height!),
        reason:
            'Flutter ships tall2021 identical to englishLike2021, so without '
            'this the two columns would be the same theme',
      );
      expect(KdType.forLocale(const Locale('hi')), same(deva));
      expect(
        KdType.forLocale(
          const Locale.fromSubtags(languageCode: 'xx', scriptCode: 'Deva'),
        ),
        same(deva),
      );
    });

    test('no Devanagari style falls below the line-height floor', () {
      final deva = KdType.forLocale(const Locale('ne'));
      final styles = <String, TextStyle?>{
        'displaySmall': deva.displaySmall,
        'headlineMedium': deva.headlineMedium,
        'headlineSmall': deva.headlineSmall,
        'titleLarge': deva.titleLarge,
        'titleMedium': deva.titleMedium,
        'titleSmall': deva.titleSmall,
        'bodyLarge': deva.bodyLarge,
        'bodyMedium': deva.bodyMedium,
        'bodySmall': deva.bodySmall,
        'labelLarge': deva.labelLarge,
        'labelMedium': deva.labelMedium,
        'labelSmall': deva.labelSmall,
      };
      for (final entry in styles.entries) {
        expect(
          entry.value!.height,
          greaterThanOrEqualTo(KdType.devanagariMinHeight),
          reason: '${entry.key} would collide stacked matras between lines',
        );
      }
    });

    test('Devanagari never carries letter spacing', () {
      // Letter spacing breaks the shirorekha, the horizontal line the script
      // is read along. It is roughly the equivalent of s p a c i n g out the
      // letters inside an English word.
      final deva = KdType.forLocale(const Locale('ne'));
      for (final style in <TextStyle?>[
        deva.titleLarge,
        deva.titleMedium,
        deva.bodyLarge,
        deva.bodyMedium,
        deva.bodySmall,
        deva.labelLarge,
      ]) {
        expect(style!.letterSpacing, 0);
      }
    });

    test(
      'leading is distributed evenly, so the extra space lands where matras are',
      () {
        final deva = KdType.forLocale(const Locale('ne'));
        expect(
          deva.bodyLarge!.leadingDistribution,
          TextLeadingDistribution.even,
        );
      },
    );

    test('the theme adopts the locale column', () {
      expect(
        kdLightTheme(locale: const Locale('ne')).textTheme.bodyLarge!.height,
        greaterThan(
          kdLightTheme(locale: const Locale('en')).textTheme.bodyLarge!.height!,
        ),
      );
    });
  });
}
