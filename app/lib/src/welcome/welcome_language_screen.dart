import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../locale_scope.dart';
import '../router.dart';
import 'language_choice.dart';

/// Stable handle per option, so a test can name a target without matching on
/// a string in a script the test file may not render.
Key languageTargetKey(AppLanguage language) =>
    Key('welcome.language.${language.code}');

/// The first localised screen of the app, before a reading language is known.
///
/// No AppBar, no back, no skip, no preselection, no Continue button. One tap
/// is the whole screen. It is reached by being the initial location rather
/// than by being pushed, so there is nothing behind it to go back to.
class WelcomeLanguageScreen extends StatefulWidget {
  const WelcomeLanguageScreen({super.key});

  @override
  State<WelcomeLanguageScreen> createState() => _WelcomeLanguageScreenState();
}

class _WelcomeLanguageScreenState extends State<WelcomeLanguageScreen> {
  /// Guards against a double tap writing twice. Set before the await, so the
  /// second tap of an impatient double tap is dropped rather than queued.
  bool _busy = false;
  AppLanguage? _pendingLanguage;

  Future<void> _choose(LanguageChoice choice) async {
    if (_busy) return;
    // Fired before the await so the confirmation arrives with the tap rather
    // than with the result of the tap.
    unawaited(KdHaptics.selected());
    setState(() {
      _busy = true;
      _pendingLanguage = choice.language;
    });

    // Awaited, not started. Navigating on completion is what guarantees the
    // next screen cannot be reached in a state where the language is on
    // screen but not on disk.
    await LocaleScope.of(context).setLocale(choice.locale);
    if (!mounted) return;

    // `push`, not `go`, and this is the mis-tap recovery: system back from
    // About returns here with the app already repainted in the chosen script,
    // so a wrong tap costs one back press and one tap, with no reading
    // required at either step.
    await context.push('${AppRoutes.welcomeAbout}?first=1');
    if (mounted) {
      setState(() {
        _busy = false;
        _pendingLanguage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: KdColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          // Bottom aligned when there is room, top-to-bottom scrolling when
          // there is not. A scroll view whose minHeight equals the viewport
          // is the entire short-viewport fix: no orientation branch, no
          // breakpoint, and nothing to get wrong in landscape.
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KdSpacing.lg,
                  KdSpacing.xl,
                  KdSpacing.lg,
                  KdSpacing.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KdBrandMark(size: 56, semanticLabel: l10n.appTitle),
                        const SizedBox(height: KdSpacing.lg),
                        Text(
                          l10n.languageGreeting,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: KdColors.primaryPressed),
                        ),
                        const SizedBox(height: KdSpacing.xs),
                        Text(
                          l10n.a11yLanguageChooser,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: KdSpacing.sm),
                        Text(
                          l10n.languageChoiceHint,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: KdColors.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: KdSpacing.xl),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final choice in kLanguageChoices) ...[
                          if (choice != kLanguageChoices.first)
                            const SizedBox(height: KdSpacing.smd),
                          _LanguageTarget(
                            choice: choice,
                            onChoose: _choose,
                            busy: _busy,
                            pending: _pendingLanguage == choice.language,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTarget extends StatelessWidget {
  const _LanguageTarget({
    required this.choice,
    required this.onChoose,
    required this.busy,
    required this.pending,
  });

  final LanguageChoice choice;
  final void Function(LanguageChoice choice) onChoose;
  final bool busy;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final label = choice.name(AppLocalizations.of(context));

    return Semantics(
      button: true,
      label: label,
      // The handler lives on the Semantics node, with `excludeSemantics`
      // collapsing the subtree beneath it. The other arrangement, a Semantics
      // wrapper around an ExcludeSemantics around the InkWell, produces a node
      // carrying isButton and NO tap action, because the handler is inside the
      // excluded subtree: TalkBack announces "button" and double tap does
      // nothing. On an unskippable first-run gate that is a hard lock for a
      // blind user.
      onTap: busy ? null : () => onChoose(choice),
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: busy && !pending ? 0.52 : 1,
        duration: kdDuration(context, KdMotion.quick),
        child: Card(
          elevation: pending ? 0 : 1,
          color: pending ? KdColors.primarySoft : KdColors.surface,
          child: InkWell(
            key: languageTargetKey(choice.language),
            borderRadius: BorderRadius.circular(KdRadius.lg),
            onTap: busy ? null : () => onChoose(choice),
            child: ConstrainedBox(
              // Well above the 48dp floor. This is the one screen where a
              // mis-tap costs the user the whole app.
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KdSpacing.lmd,
                  vertical: KdSpacing.smd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        // The choice's OWN script metrics, never the ambient
                        // theme. At this moment no language has been chosen,
                        // so both Devanagari endonyms need explicit metrics.
                        style: KdType.forLocale(
                          choice.locale,
                        ).headlineSmall!.copyWith(color: KdColors.inkStrong),
                      ),
                    ),
                    if (pending)
                      SizedBox.square(
                        dimension: KdIconSize.md,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: KdColors.primaryPressed,
                        ),
                      )
                    else
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: KdColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(
                          dimension: 40,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: kdScaledIcon(context, KdIconSize.md),
                            color: KdColors.primaryPressed,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
