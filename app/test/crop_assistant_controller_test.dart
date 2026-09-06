import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/assistant/crop_assistant.dart';

void main() {
  test('validates an empty question without consulting the service', () async {
    final service = _CountingService();
    final controller = CropAssistantController(
      service: service,
      language: CropAssistantLanguage.en,
      crop: CropAssistantCrop.tomato,
    );
    addTearDown(controller.dispose);

    await controller.ask('   ');

    expect(controller.status, CropAssistantStatus.invalid);
    expect(
      controller.validationIssue,
      CropAssistantValidationIssue.emptyQuestion,
    );
    expect(service.calls, 0);
  });

  test('returns guidance in the selected language and crop context', () async {
    final controller = CropAssistantController(
      service: const OfflineCropAssistantService(),
      language: CropAssistantLanguage.ne,
      crop: CropAssistantCrop.potato,
    );
    addTearDown(controller.dispose);

    await controller.ask('पातमा डढुवा जस्तो थोप्ला छ');

    expect(controller.status, CropAssistantStatus.answered);
    expect(controller.answer?.language, CropAssistantLanguage.ne);
    expect(controller.answer?.crop, CropAssistantCrop.potato);
    expect(controller.answer?.summary, contains('आलु'));
    expect(controller.turns.single.question, 'पातमा डढुवा जस्तो थोप्ला छ');
  });

  test('keeps every completed exchange in the in-memory session', () async {
    final controller = CropAssistantController(
      service: const OfflineCropAssistantService(),
      language: CropAssistantLanguage.en,
      crop: CropAssistantCrop.tomato,
    );
    addTearDown(controller.dispose);

    await controller.ask('How do I prevent disease?');
    await controller.ask('What should I control now?');

    expect(controller.turns, hasLength(2));
    expect(controller.turns.first.question, 'How do I prevent disease?');
    expect(controller.turns.last.question, 'What should I control now?');
    expect(controller.answer, same(controller.turns.last.answer));
  });

  test('passes earlier turns as context for a bounded follow-up', () async {
    final controller = CropAssistantController(
      service: const OfflineCropAssistantService(),
      language: CropAssistantLanguage.en,
      crop: CropAssistantCrop.tomato,
    );
    addTearDown(controller.dispose);

    await controller.ask('There are dark spots on the leaves');
    final symptomSummary = controller.answer!.summary;
    await controller.ask('How can I prevent it next time?');

    expect(controller.answer!.summary, symptomSummary);
  });

  test('changing context clears an answer in the previous language', () async {
    final controller = CropAssistantController(
      service: const OfflineCropAssistantService(),
      language: CropAssistantLanguage.en,
      crop: CropAssistantCrop.tomato,
    );
    addTearDown(controller.dispose);
    await controller.ask('yellow leaves');
    expect(controller.answer, isNotNull);

    controller.updateContext(
      language: CropAssistantLanguage.hi,
      crop: CropAssistantCrop.maize,
    );

    expect(controller.status, CropAssistantStatus.idle);
    expect(controller.answer, isNull);
    expect(controller.turns, isEmpty);
    expect(controller.identity.disclosure, contains('जनरेटिव एआई नहीं'));
  });

  test('a stale response cannot overwrite a changed context', () async {
    final service = _DelayedService();
    final controller = CropAssistantController(
      service: service,
      language: CropAssistantLanguage.en,
      crop: CropAssistantCrop.tomato,
    );
    addTearDown(controller.dispose);

    final pending = controller.ask('spots');
    expect(controller.status, CropAssistantStatus.answering);
    controller.updateContext(
      language: CropAssistantLanguage.hi,
      crop: CropAssistantCrop.maize,
    );
    service.complete();
    await pending;

    expect(controller.status, CropAssistantStatus.idle);
    expect(controller.answer, isNull);
    expect(controller.turns, isEmpty);
  });
}

final class _CountingService implements CropAssistantService {
  int calls = 0;

  @override
  Future<CropAssistantAnswer> answer(CropAssistantQuery query) async {
    calls++;
    return const OfflineCropAssistantService().answer(query);
  }

  @override
  CropAssistantGuideIdentity identity({
    required CropAssistantLanguage language,
    required CropAssistantCrop crop,
  }) => const OfflineCropAssistantService().identity(
    language: language,
    crop: crop,
  );
}

final class _DelayedService implements CropAssistantService {
  final Completer<void> _release = Completer<void>();

  void complete() => _release.complete();

  @override
  Future<CropAssistantAnswer> answer(CropAssistantQuery query) async {
    await _release.future;
    return const OfflineCropAssistantService().answer(query);
  }

  @override
  CropAssistantGuideIdentity identity({
    required CropAssistantLanguage language,
    required CropAssistantCrop crop,
  }) => const OfflineCropAssistantService().identity(
    language: language,
    crop: crop,
  );
}
