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

/// The first screen of the app, before its first localisable sentence.
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

  Future<void> _choose(LanguageChoice choice) async {
    if (_busy) return;
    // Fired before the await so the confirmation arrives with the tap rather
    // than with the result of the tap.
    unawaited(KdHaptics.selected());
    setState(() => _busy = true);

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
    if (mounted) setState(() => _busy = false);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: KdLayout.pageGutter,
                  vertical: KdSpacing.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Icon(
                        Icons.translate,
                        size: kdScaledIcon(context, KdIconSize.xxl),
                        color: KdColors.primary,
                        // First in traversal, and the closest thing to a
                        // pre-language prompt that can exist on a screen
                        // whose whole purpose is that no language is known
                        // yet. It resolves in the device locale, which is
                        // right: a screen-reader user's device language is
                        // their language.
                        semanticLabel: l10n.a11yLanguageChooser,
                      ),
                    ),
                    const SizedBox(height: KdSpacing.xl),
                    for (final choice in kLanguageChoices) ...[
                      if (choice != kLanguageChoices.first)
                        const SizedBox(height: KdSpacing.smd),
                      _LanguageTarget(choice: choice, onChoose: _choose),
                    ],
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
  const _LanguageTarget({required this.choice, required this.onChoose});

  final LanguageChoice choice;
  final void Function(LanguageChoice choice) onChoose;

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
      onTap: () => onChoose(choice),
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          key: languageTargetKey(choice.language),
          borderRadius: BorderRadius.circular(KdRadius.lg),
          onTap: () => onChoose(choice),
          child: ConstrainedBox(
            // Well above the 48dp floor. This is the one screen where a
            // mis-tap costs the user the whole app.
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KdSpacing.lmd,
                vertical: KdSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      // The choice's OWN script metrics, never the ambient
                      // theme. At this moment no language has been chosen, so
                      // the app themes with English metrics and both
                      // Devanagari endonyms would paint at Latin line height
                      // with letter spacing, collapsing the shirorekha on the
                      // one screen whose whole job is to be readable in that
                      // script.
                      style: KdType.forLocale(
                        choice.locale,
                      ).headlineSmall!.copyWith(color: KdColors.inkStrong),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: kdScaledIcon(context, KdIconSize.md),
                    color: KdColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
