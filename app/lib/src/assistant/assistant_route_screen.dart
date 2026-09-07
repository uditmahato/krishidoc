import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../capture/capture_screen.dart' show cropName;
import '../diagnosis/label_names.dart';
import '../providers.dart';
import 'crop_assistant.dart';

/// Connects the self-contained assistant to the app's live locale and
/// remembered crop context.
class AssistantRouteScreen extends ConsumerWidget {
  const AssistantRouteScreen({this.cropKey, this.candidateLabelKey, super.key});

  final String? cropKey;
  final String? candidateLabelKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final requestedCrop = cropKey == null
        ? null
        : ref.watch(cropCatalogProvider).byKey(cropKey);
    if (requestedCrop != null) {
      return _screen(context, requestedCrop);
    }
    final selected = ref.watch(selectedCropProvider);
    return selected.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.askKrishiAssistant)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: Text(l10n.askKrishiAssistant)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(KdLayout.pageGutter),
            child: Text(l10n.errorGeneric),
          ),
        ),
      ),
      data: (crop) => _screen(context, crop),
    );
  }

  Widget _screen(BuildContext context, Crop crop) {
    final l10n = AppLocalizations.of(context);
    final assistantCrop = CropAssistantCrop.fromKey(crop.key);
    if (assistantCrop == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.askKrishiAssistant)),
        body: Center(child: Text(l10n.outOfScopeNotCovered)),
      );
    }

    final candidate = candidateLabelKey;
    final candidateMatchesCrop =
        candidate != null && candidate.startsWith('${crop.key}_');
    final candidateName = candidateMatchesCrop
        ? localizedLabelName(l10n, candidate, cropKey: crop.key)
        : null;

    return CropAssistantScreen(
      language:
          CropAssistantLanguage.fromCode(
            Localizations.localeOf(context).languageCode,
          ) ??
          CropAssistantLanguage.en,
      crop: assistantCrop,
      initialContext: candidateName == null
          ? null
          : CropAssistantInitialContext(
              // The bounded guide uses this only for visible keyword routing;
              // it is never sent off-device and the raw key is never shown.
              query: '$candidate treatment prevention control',
              displayText: '$candidateName. ${l10n.possibleMatchNotice}',
            ),
      strings: CropAssistantUiStrings(
        title: l10n.askKrishiAssistant,
        intro: l10n.assistantIntro,
        offlineLabel: l10n.offlineGuideLabel,
        cropContextLabel: l10n.assistantCropContext,
        cropName: cropName(l10n, crop),
        questionLabel: l10n.assistantQuestionLabel,
        questionHint: l10n.assistantQuestionHint,
        askButton: l10n.assistantAskButton,
        emptyQuestionError: l10n.assistantEmptyQuestionError,
        questionTooLongError: l10n.assistantQuestionTooLongError,
        failedMessage: l10n.assistantFailedMessage,
        immediateHeading: l10n.assistantImmediateHeading,
        preventionHeading: l10n.assistantPreventionHeading,
        controlHeading: l10n.assistantControlHeading,
        seekHelpHeading: l10n.assistantSeekHelpHeading,
        sourceHeading: l10n.assistantSourceHeading,
      ),
    );
  }
}
