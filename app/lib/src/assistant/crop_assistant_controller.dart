import 'package:flutter/foundation.dart';

import 'offline_crop_assistant.dart';

enum CropAssistantStatus { idle, answering, answered, invalid, failed }

enum CropAssistantValidationIssue { emptyQuestion, questionTooLong }

/// One completed exchange in the in-memory assistant session.
final class CropAssistantTurn {
  const CropAssistantTurn({required this.question, required this.answer});

  final String question;
  final CropAssistantAnswer answer;
}

/// State owner for one offline assistant screen.
final class CropAssistantController extends ChangeNotifier {
  CropAssistantController({
    required CropAssistantService service,
    required CropAssistantLanguage language,
    required CropAssistantCrop crop,
  }) : _service = service,
       _language = language,
       _crop = crop;

  CropAssistantService _service;
  CropAssistantLanguage _language;
  CropAssistantCrop _crop;
  CropAssistantStatus _status = CropAssistantStatus.idle;
  CropAssistantValidationIssue? _validationIssue;
  final List<CropAssistantTurn> _turns = [];
  String? _pendingQuestion;
  Object? _error;
  int _requestSerial = 0;
  bool _disposed = false;

  CropAssistantLanguage get language => _language;
  CropAssistantCrop get crop => _crop;
  CropAssistantStatus get status => _status;
  CropAssistantValidationIssue? get validationIssue => _validationIssue;
  List<CropAssistantTurn> get turns => List.unmodifiable(_turns);
  String? get pendingQuestion => _pendingQuestion;

  /// The latest response, retained for callers that need only current advice.
  CropAssistantAnswer? get answer => _turns.isEmpty ? null : _turns.last.answer;
  Object? get error => _error;
  bool get isAnswering => _status == CropAssistantStatus.answering;

  CropAssistantGuideIdentity get identity =>
      _service.identity(language: _language, crop: _crop);

  /// Applies a locale/crop change without leaving an answer in the old
  /// language or for the old crop on screen.
  void updateContext({
    required CropAssistantLanguage language,
    required CropAssistantCrop crop,
  }) {
    if (_language == language && _crop == crop) return;
    _language = language;
    _crop = crop;
    _requestSerial++;
    _status = CropAssistantStatus.idle;
    _validationIssue = null;
    _turns.clear();
    _pendingQuestion = null;
    _error = null;
    notifyListeners();
  }

  /// Used when a parent replaces the injected implementation in a test or in
  /// a future signed knowledge-pack update.
  void updateService(CropAssistantService service) {
    if (identical(_service, service)) return;
    _service = service;
    _requestSerial++;
    _status = CropAssistantStatus.idle;
    _validationIssue = null;
    _turns.clear();
    _pendingQuestion = null;
    _error = null;
    notifyListeners();
  }

  Future<void> ask(String question) async {
    final normalized = question.trim();
    if (normalized.isEmpty) {
      _setInvalid(CropAssistantValidationIssue.emptyQuestion);
      return;
    }
    if (normalized.length > CropAssistantQuery.maxQuestionLength) {
      _setInvalid(CropAssistantValidationIssue.questionTooLong);
      return;
    }

    final serial = ++_requestSerial;
    _status = CropAssistantStatus.answering;
    _validationIssue = null;
    _pendingQuestion = normalized;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.answer(
        CropAssistantQuery(
          question: normalized,
          language: _language,
          crop: _crop,
          previousQuestions: _turns.map((turn) => turn.question),
        ),
      );
      if (_disposed || serial != _requestSerial) return;
      _turns.add(CropAssistantTurn(question: normalized, answer: result));
      _pendingQuestion = null;
      _status = CropAssistantStatus.answered;
      notifyListeners();
    } catch (error) {
      if (_disposed || serial != _requestSerial) return;
      _pendingQuestion = null;
      _error = error;
      _status = CropAssistantStatus.failed;
      notifyListeners();
    }
  }

  void _setInvalid(CropAssistantValidationIssue issue) {
    _status = CropAssistantStatus.invalid;
    _validationIssue = issue;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSerial++;
    super.dispose();
  }
}
