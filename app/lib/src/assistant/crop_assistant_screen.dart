import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'crop_assistant_controller.dart';
import 'offline_crop_assistant.dart';

const Key cropAssistantQuestionKey = Key('cropAssistant.question');
const Key cropAssistantAskKey = Key('cropAssistant.ask');
const Key cropAssistantDisclosureKey = Key('cropAssistant.disclosure');
const Key cropAssistantAnswerKey = Key('cropAssistant.answer');

/// A scan-provided possible match that should receive immediate bounded
/// guidance when the assistant opens.
///
/// [query] is an internal keyword-routing input and is never rendered. The
/// farmer sees [displayText], which must carry the possible-match caveat.
@immutable
final class CropAssistantInitialContext {
  const CropAssistantInitialContext({
    required this.query,
    required this.displayText,
  });

  final String query;
  final String displayText;
}

/// UI-only copy supplied by the app localization adapter.
///
/// Knowledge text stays in the bounded offline pack; navigation labels,
/// headings, errors and the localized crop name remain normal app strings.
@immutable
final class CropAssistantUiStrings {
  const CropAssistantUiStrings({
    required this.title,
    required this.intro,
    required this.offlineLabel,
    required this.cropContextLabel,
    required this.cropName,
    required this.questionLabel,
    required this.questionHint,
    required this.askButton,
    required this.emptyQuestionError,
    required this.questionTooLongError,
    required this.failedMessage,
    required this.immediateHeading,
    required this.preventionHeading,
    required this.controlHeading,
    required this.seekHelpHeading,
    required this.sourceHeading,
  });

  final String title;
  final String intro;
  final String offlineLabel;
  final String cropContextLabel;
  final String cropName;
  final String questionLabel;
  final String questionHint;
  final String askButton;
  final String emptyQuestionError;
  final String questionTooLongError;
  final String failedMessage;
  final String immediateHeading;
  final String preventionHeading;
  final String controlHeading;
  final String seekHelpHeading;
  final String sourceHeading;
}

/// A self-contained screen for the bundled Nepal crop guide.
///
/// The screen owns its controller so route builders only provide current
/// language/crop and localized chrome. [service] is injectable for tests and
/// for future signed knowledge-pack implementations.
class CropAssistantScreen extends StatefulWidget {
  const CropAssistantScreen({
    required this.language,
    required this.crop,
    required this.strings,
    this.initialContext,
    this.service = const OfflineCropAssistantService(),
    super.key,
  });

  final CropAssistantLanguage language;
  final CropAssistantCrop crop;
  final CropAssistantUiStrings strings;
  final CropAssistantInitialContext? initialContext;
  final CropAssistantService service;

  @override
  State<CropAssistantScreen> createState() => _CropAssistantScreenState();
}

class _CropAssistantScreenState extends State<CropAssistantScreen> {
  late final TextEditingController _questionController;
  late final ScrollController _scrollController;
  late final CropAssistantController _controller;
  var _lastTurnCount = 0;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _scrollController = ScrollController();
    _controller = CropAssistantController(
      service: widget.service,
      language: widget.language,
      crop: widget.crop,
    )..addListener(_onChanged);
    _scheduleInitialContext();
  }

  @override
  void didUpdateWidget(CropAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      _controller.updateService(widget.service);
    }
    _controller.updateContext(language: widget.language, crop: widget.crop);
    if (oldWidget.initialContext?.query != widget.initialContext?.query ||
        oldWidget.initialContext?.displayText !=
            widget.initialContext?.displayText) {
      _scheduleInitialContext();
    }
  }

  void _scheduleInitialContext() {
    final initial = widget.initialContext;
    if (initial == null || initial.query.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.initialContext?.query != initial.query) return;
      unawaited(_controller.ask(initial.query));
    });
  }

  void _onChanged() {
    if (!mounted) return;
    final addedTurn = _controller.turns.length > _lastTurnCount;
    if (addedTurn) _questionController.clear();
    _lastTurnCount = _controller.turns.length;
    setState(() {});
    if (addedTurn || _controller.pendingQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  void _scrollToLatest() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: kdDuration(context, KdMotion.standard),
      curve: KdMotion.enter,
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final identity = _controller.identity;
    final turns = _controller.turns;
    final pendingQuestion = _controller.pendingQuestion;
    final validationText = switch (_controller.validationIssue) {
      CropAssistantValidationIssue.emptyQuestion => strings.emptyQuestionError,
      CropAssistantValidationIssue.questionTooLong =>
        strings.questionTooLongError,
      null => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KdLayout.pageGutter,
                  KdLayout.pageGutter,
                  KdLayout.pageGutter,
                  KdSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GuideHeader(
                      strings: strings,
                      disclosure: identity.disclosure,
                    ),
                    if (_controller.status == CropAssistantStatus.failed) ...[
                      const SizedBox(height: KdSpacing.smd),
                      _FailureNotice(message: strings.failedMessage),
                    ],
                    if (turns.isNotEmpty || pendingQuestion != null) ...[
                      const SizedBox(height: KdLayout.sectionGap),
                      Column(
                        key: cropAssistantAnswerKey,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < turns.length;
                            index++
                          ) ...[
                            if (index == 0 &&
                                widget.initialContext?.query ==
                                    turns[index].question)
                              _ScanContextBubble(
                                text: widget.initialContext!.displayText,
                              )
                            else
                              _QuestionBubble(question: turns[index].question),
                            const SizedBox(height: KdSpacing.smd),
                            _AnswerCard(
                              answer: turns[index].answer,
                              strings: strings,
                            ),
                            if (index != turns.length - 1 ||
                                pendingQuestion != null)
                              const SizedBox(height: KdLayout.sectionGap),
                          ],
                          if (pendingQuestion != null) ...[
                            if (widget.initialContext?.query == pendingQuestion)
                              _ScanContextBubble(
                                text: widget.initialContext!.displayText,
                              )
                            else
                              _QuestionBubble(question: pendingQuestion),
                            const SizedBox(height: KdSpacing.smd),
                            const _AnsweringIndicator(),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _QuestionComposer(
            controller: _questionController,
            strings: strings,
            validationText: validationText,
            isAnswering: _controller.isAnswering,
            onAsk: () => unawaited(_controller.ask(_questionController.text)),
            onSubmitted: (value) => unawaited(_controller.ask(value)),
          ),
        ],
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({required this.strings, required this.disclosure});

  final CropAssistantUiStrings strings;
  final String disclosure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: KdSpacing.xxxl,
              height: KdSpacing.xxxl,
              decoration: BoxDecoration(
                color: KdColors.primarySoft,
                borderRadius: BorderRadius.circular(KdRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.eco_outlined,
                size: kdScaledIcon(context, KdIconSize.md),
                color: KdColors.primary,
              ),
            ),
            const SizedBox(width: KdSpacing.smd),
            Expanded(
              child: Text(
                strings.intro,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: KdSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Chip(
            avatar: const Icon(Icons.spa_outlined),
            label: Text('${strings.cropContextLabel}: ${strings.cropName}'),
          ),
        ),
        const SizedBox(height: KdSpacing.smd),
        Semantics(
          key: cropAssistantDisclosureKey,
          container: true,
          label: '${strings.offlineLabel}. $disclosure',
          child: Container(
            padding: const EdgeInsets.all(KdSpacing.smd),
            decoration: BoxDecoration(
              color: KdColors.surfaceSunken,
              borderRadius: BorderRadius.circular(KdRadius.md),
              border: Border.all(color: KdColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.offline_bolt_outlined,
                  size: kdScaledIcon(context, KdIconSize.sm),
                  color: KdColors.primaryPressed,
                ),
                const SizedBox(width: KdSpacing.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${strings.offlineLabel}  ',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        TextSpan(
                          text: disclosure,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionComposer extends StatelessWidget {
  const _QuestionComposer({
    required this.controller,
    required this.strings,
    required this.validationText,
    required this.isAnswering,
    required this.onAsk,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final CropAssistantUiStrings strings;
  final String? validationText;
  final bool isAnswering;
  final VoidCallback onAsk;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KdColors.surface,
        border: Border(top: BorderSide(color: KdColors.border)),
        boxShadow: KdElevation.floating,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          KdLayout.pageGutter,
          KdSpacing.smd,
          KdLayout.pageGutter,
          KdSpacing.smd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: cropAssistantQuestionKey,
                controller: controller,
                minLines: 1,
                maxLines: 3,
                maxLength: CropAssistantQuery.maxQuestionLength,
                textInputAction: TextInputAction.send,
                onSubmitted: isAnswering ? null : onSubmitted,
                decoration: InputDecoration(
                  labelText: strings.questionLabel,
                  hintText: strings.questionHint,
                  errorText: validationText,
                  counterText: '',
                  prefixIcon: const Icon(Icons.chat_bubble_outline),
                ),
              ),
            ),
            const SizedBox(width: KdSpacing.smd),
            Tooltip(
              message: strings.askButton,
              child: Semantics(
                button: true,
                label: strings.askButton,
                child: SizedBox.square(
                  dimension: KdSpacing.xxxl,
                  child: FilledButton(
                    key: cropAssistantAskKey,
                    onPressed: isAnswering ? null : onAsk,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.square(KdSpacing.xxxl),
                      padding: EdgeInsets.zero,
                    ),
                    child: isAnswering
                        ? const SizedBox.square(
                            dimension: KdIconSize.sm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanContextBubble extends StatelessWidget {
  const _ScanContextBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(KdLayout.cardPadding),
        decoration: BoxDecoration(
          color: KdColors.stateUncertainBand,
          borderRadius: BorderRadius.circular(KdRadius.lg),
          border: Border.all(color: KdColors.stateUncertainRail),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.document_scanner_outlined,
              color: KdColors.stateUncertainRail,
            ),
            const SizedBox(width: KdSpacing.smd),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: question,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KdSpacing.md,
              vertical: KdSpacing.smd,
            ),
            decoration: BoxDecoration(
              color: KdColors.primarySoft,
              borderRadius: BorderRadius.circular(KdRadius.lg),
              border: Border.all(color: KdColors.primary),
            ),
            child: Text(question),
          ),
        ),
      ),
    );
  }
}

class _AnsweringIndicator extends StatelessWidget {
  const _AnsweringIndicator();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KdSpacing.md,
        vertical: KdSpacing.smd,
      ),
      decoration: BoxDecoration(
        color: KdColors.surface,
        borderRadius: BorderRadius.circular(KdRadius.lg),
        border: Border.all(color: KdColors.border),
      ),
      child: const SizedBox.square(
        dimension: KdIconSize.sm,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.strings});

  final CropAssistantAnswer answer;
  final CropAssistantUiStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KdLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: KdSpacing.xxl,
                  height: KdSpacing.xxl,
                  decoration: BoxDecoration(
                    color: KdColors.primarySoft,
                    borderRadius: BorderRadius.circular(KdRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.eco_outlined,
                    color: KdColors.primary,
                  ),
                ),
                const SizedBox(width: KdSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: KdColors.primaryPressed,
                        ),
                      ),
                      const SizedBox(height: KdSpacing.xs),
                      Text(
                        answer.summary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KdSpacing.md),
            const Divider(),
            _GuidanceSection(
              icon: Icons.checklist_outlined,
              title: strings.immediateHeading,
              items: answer.immediateActions,
              emphasized: true,
            ),
            const Divider(),
            _GuidanceSection(
              icon: Icons.health_and_safety_outlined,
              title: strings.preventionHeading,
              items: answer.prevention,
            ),
            const Divider(),
            _GuidanceSection(
              icon: Icons.cleaning_services_outlined,
              title: strings.controlHeading,
              items: answer.control,
            ),
            const Divider(),
            _GuidanceSection(
              icon: Icons.support_agent_outlined,
              title: strings.seekHelpHeading,
              items: answer.seekHelpWhen,
            ),
            const SizedBox(height: KdSpacing.smd),
            _SourceFooter(answer: answer, heading: strings.sourceHeading),
          ],
        ),
      ),
    );
  }
}

class _GuidanceSection extends StatelessWidget {
  const _GuidanceSection({
    required this.icon,
    required this.title,
    required this.items,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: KdSpacing.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: KdSpacing.xl,
                height: KdSpacing.xl,
                decoration: BoxDecoration(
                  color: KdColors.primarySoft,
                  borderRadius: BorderRadius.circular(KdRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: KdColors.primary, size: KdIconSize.sm),
              ),
              const SizedBox(width: KdSpacing.smd),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: KdSpacing.smd),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: KdSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: KdSpacing.sm),
                    child: Icon(
                      Icons.circle,
                      size: KdSpacing.xs,
                      color: KdColors.primaryPressed,
                    ),
                  ),
                  const SizedBox(width: KdSpacing.smd),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );

    if (!emphasized) return content;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: KdSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: KdSpacing.smd),
      decoration: BoxDecoration(
        color: KdColors.primarySoft,
        borderRadius: BorderRadius.circular(KdRadius.md),
      ),
      child: content,
    );
  }
}

class _SourceFooter extends StatelessWidget {
  const _SourceFooter({required this.answer, required this.heading});

  final CropAssistantAnswer answer;
  final String heading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KdSpacing.smd),
      decoration: BoxDecoration(
        color: KdColors.surfaceSunken,
        borderRadius: BorderRadius.circular(KdRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, color: KdColors.primaryPressed),
          const SizedBox(width: KdSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: KdSpacing.xs),
                Text(
                  answer.identity.attribution,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: KdSpacing.xs),
                SelectableText(
                  answer.identity.sourceUri.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KdColors.primaryPressed,
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

class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(KdSpacing.smd),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(KdRadius.md),
      border: Border.all(color: KdColors.danger),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: KdColors.danger),
        const SizedBox(width: KdSpacing.smd),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KdColors.danger),
          ),
        ),
      ],
    ),
  );
}
