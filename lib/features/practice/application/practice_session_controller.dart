import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/hybrid_question_generator.dart';

/// Practice Room duration modes requested by user:
/// - 60 seconds (60 giây)
/// - 900 seconds (15 phút)
/// - 3600 seconds (1 tiếng)
/// - 0 = Unlimited (Không giới hạn)
final selectedPracticeDurationProvider = StateProvider<int>((ref) => 60);

/// Selected difficulty level for "Nhận biết nốt" (Note Recognition):
/// - 'lvl_notes_basic': Mức 1 (Dễ - Chỉ C4 tự nhiên, không dấu #/b)
/// - 'lvl_notes_inter': Mức 2 (Trung bình - Chỉ C4, có dấu #/b)
/// - 'lvl_notes_adv':   Mức 3 (Khá - Đa quãng C3–C5 tự nhiên)
/// - 'lvl_notes_master': Mức 4 (Nâng cao - Đa quãng C3–C5 đầy đủ #/b, tắt gợi ý C4)
final selectedNoteLevelIdProvider =
    StateProvider<String>((ref) => 'lvl_notes_basic');

/// Selected difficulty level for "Đọc nốt nhạc" (Staff Sight-Reading):
/// - 'lvl_staff_basic': Mức 1 (Dễ - Khóa Sol C4–B4 tự nhiên)
/// - 'lvl_staff_inter': Mức 2 (Trung bình - Khóa Sol C4–B4 có dấu #/b)
/// - 'lvl_staff_adv':   Mức 3 (Khá - Khóa Sol & Khóa Fa C3–C5 tự nhiên)
/// - 'lvl_staff_master': Mức 4 (Nâng cao - Khóa Sol & Khóa Fa C3–C5 đầy đủ #/b)
final selectedStaffLevelIdProvider =
    StateProvider<String>((ref) => 'lvl_staff_basic');

const List<(String id, String shortTitle, String subTitle, String fullDesc)>
    kNoteRecognitionLevels = [
  (
    'lvl_notes_basic',
    'Mức 1',
    'C4 Tự nhiên',
    'Dễ: Chỉ trong quãng C4 (Đô–Si), không có dấu thăng (#) hay giáng (b).'
  ),
  (
    'lvl_notes_inter',
    'Mức 2',
    'C4 Có #/b',
    'Trung bình: Chỉ trong quãng C4 nhưng có thêm 5 phím đen (dấu # / b).'
  ),
  (
    'lvl_notes_adv',
    'Mức 3',
    'C3–C5 Tự nhiên',
    'Khá: Mở rộng 3 quãng tám (C3–C5) với các nốt tự nhiên, có đối chiếu C4.'
  ),
  (
    'lvl_notes_master',
    'Mức 4',
    'C3–C5 Đầy đủ',
    'Nâng cao: Đầy đủ nốt tự nhiên & dấu #/b từ C3–C5, tắt gợi ý C4.'
  ),
];

const List<(String id, String shortTitle, String subTitle, String fullDesc)>
    kStaffReadingLevels = [
  (
    'lvl_staff_basic',
    'Mức 1',
    'Khóa Sol C4',
    'Dễ: Đọc 7 nốt tự nhiên trên khuông nhạc Khóa Sol (C4–B4), không dấu #/b.'
  ),
  (
    'lvl_staff_inter',
    'Mức 2',
    'Khóa Sol #/b',
    'Trung bình: Đọc khuông nhạc Khóa Sol (C4–B4) có thêm dấu thăng (♯).'
  ),
  (
    'lvl_staff_adv',
    'Mức 3',
    'Sol & Fa C3–C5',
    'Khá: Đọc cả Khóa Sol (𝄞) & Khóa Fa (𝄢) từ C3–C5 với các nốt tự nhiên.'
  ),
  (
    'lvl_staff_master',
    'Mức 4',
    'Sol & Fa Đầy đủ',
    'Nâng cao: Đọc thành thạo Khóa Sol & Khóa Fa (C3–C5) đầy đủ dấu hóa (#/b).'
  ),
];

class PracticeSessionState {
  final String? sessionId;
  final String mode; // 'quick', 'topic', 'review'
  final String topicId;
  final String? levelId;
  final List<QuestionModel> questions;
  final int currentIndex;
  final QuestionOptionModel? selectedOption;
  final List<AnswerModel> recordedAnswers;
  final bool isLoading;
  final bool isCompleted;
  final int activeDurationSeconds;
  final int? timeLimitSeconds; // 60, 900, 3600, or null
  final bool isUnlimitedMode; // true when 'Không giới hạn'
  final int elapsedSeconds;
  final int currentCombo;
  final int maxComboInSession;
  final bool isNewHighScore;
  final String? errorMessage;

  const PracticeSessionState({
    this.sessionId,
    this.mode = 'quick',
    this.topicId = 'topic_notes',
    this.levelId,
    this.questions = const [],
    this.currentIndex = 0,
    this.selectedOption,
    this.recordedAnswers = const [],
    this.isLoading = false,
    this.isCompleted = false,
    this.activeDurationSeconds = 0,
    this.timeLimitSeconds,
    this.isUnlimitedMode = false,
    this.elapsedSeconds = 0,
    this.currentCombo = 0,
    this.maxComboInSession = 0,
    this.isNewHighScore = false,
    this.errorMessage,
  });

  QuestionModel? get currentQuestion =>
      (currentIndex >= 0 && currentIndex < questions.length)
          ? questions[currentIndex]
          : null;

  bool get isCurrentAnswered => selectedOption != null;

  bool get isCurrentCorrect => selectedOption?.isCorrect ?? false;

  bool get isContinuousScoringMode =>
      timeLimitSeconds != null || isUnlimitedMode;

  int get totalQuestions => isContinuousScoringMode
      ? recordedAnswers.length
      : questions.length;

  int get answeredCount => recordedAnswers.length;

  int get correctCount => recordedAnswers.where((a) => a.isCorrect).length;

  int get wrongCount => recordedAnswers.where((a) => !a.isCorrect).length;

  int get scorePoints => correctCount * 10;

  int get remainingSeconds {
    if (timeLimitSeconds == null) return 0;
    return (timeLimitSeconds! - elapsedSeconds).clamp(0, timeLimitSeconds!);
  }

  String get timeModeLabel {
    if (isUnlimitedMode) return 'Không giới hạn';
    if (timeLimitSeconds == 60) return '60 giây';
    if (timeLimitSeconds == 900) return '15 phút';
    if (timeLimitSeconds == 3600) return '1 tiếng';
    if (timeLimitSeconds != null) return '${timeLimitSeconds}s';
    return '$totalQuestions câu';
  }

  /// BR-06: Accuracy = correct / answered * 100%; guard division by zero
  double get accuracyPercent => recordedAnswers.isEmpty
      ? 0.0
      : (correctCount / recordedAnswers.length) * 100.0;

  /// Supportive feedback message based on accuracy (Section 6.11)
  String get encouragingFeedback {
    if (recordedAnswers.isEmpty) {
      return 'Phiên luyện tập đã kết thúc. Hãy chọn thời gian và thử sức với các nốt nhạc tiếp theo nhé!';
    }
    final acc = accuracyPercent;
    if (acc >= 90) {
      return 'Xuất sắc! Tai nghe của bạn cực kỳ nhạy bén và chuẩn xác.';
    } else if (acc >= 70) {
      return 'Kết quả rất tốt! Hãy duy trì luyện tập đều đặn mỗi ngày nhé.';
    } else if (acc >= 50) {
      return 'Khởi đầu đáng khích lệ! Bạn có thể ôn lại các nốt sai trong mục Ôn tập.';
    } else {
      return 'Đừng lo lắng, cảm âm cần thời gian làm quen. Hãy bấm nghe nốt chuẩn Đô (C4) để đối chiếu nhé!';
    }
  }

  PracticeSessionState copyWith({
    String? sessionId,
    String? mode,
    String? topicId,
    String? levelId,
    List<QuestionModel>? questions,
    int? currentIndex,
    QuestionOptionModel? selectedOption,
    bool clearSelectedOption = false,
    List<AnswerModel>? recordedAnswers,
    bool? isLoading,
    bool? isCompleted,
    int? activeDurationSeconds,
    int? timeLimitSeconds,
    bool clearTimeLimit = false,
    bool? isUnlimitedMode,
    int? elapsedSeconds,
    int? currentCombo,
    int? maxComboInSession,
    bool? isNewHighScore,
    String? errorMessage,
  }) {
    return PracticeSessionState(
      sessionId: sessionId ?? this.sessionId,
      mode: mode ?? this.mode,
      topicId: topicId ?? this.topicId,
      levelId: levelId ?? this.levelId,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedOption:
          clearSelectedOption ? null : (selectedOption ?? this.selectedOption),
      recordedAnswers: recordedAnswers ?? this.recordedAnswers,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      activeDurationSeconds:
          activeDurationSeconds ?? this.activeDurationSeconds,
      timeLimitSeconds: clearTimeLimit
          ? null
          : (timeLimitSeconds ?? this.timeLimitSeconds),
      isUnlimitedMode: isUnlimitedMode ?? this.isUnlimitedMode,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentCombo: currentCombo ?? this.currentCombo,
      maxComboInSession: maxComboInSession ?? this.maxComboInSession,
      isNewHighScore: isNewHighScore ?? this.isNewHighScore,
      errorMessage: errorMessage,
    );
  }
}

class PracticeSessionNotifier extends StateNotifier<PracticeSessionState> {
  final AppDatabase _db;
  final HybridQuestionGenerator _generator;
  final AudioService _audioService;
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  DateTime? _questionShownAt;
  DateTime? _activeSegmentStartedAt;
  int _accumulatedActiveMs = 0;
  Timer? _sessionTimer;
  bool _isBusy = false;

  PracticeSessionNotifier(
    this._db,
    this._generator,
    this._audioService,
    this._ref,
  ) : super(const PracticeSessionState());

  void _stopTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void _startTimerIfNeeded() {
    _stopTimer();
    if (_audioService.isTestMode) return;
    if (!state.isContinuousScoringMode) return;

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (state.isCompleted || state.isLoading || _activeSegmentStartedAt == null) {
        return;
      }
      final nextElapsed = state.elapsedSeconds + 1;
      state = state.copyWith(elapsedSeconds: nextElapsed);

      if (state.timeLimitSeconds != null &&
          nextElapsed >= state.timeLimitSeconds!) {
        _stopTimer();
        await finishSessionNow();
      }
    });
  }

  /// Allows changing duration mode dynamically inside the Practice Room:
  /// [durationOption]: 60 (60 giây), 900 (15 phút), 3600 (1 tiếng), 0 (Không giới hạn)
  void setPracticeDurationOption(int durationOption) {
    _ref.read(selectedPracticeDurationProvider.notifier).state = durationOption;
    if (durationOption == 0) {
      state = state.copyWith(
        clearTimeLimit: true,
        isUnlimitedMode: true,
        elapsedSeconds: 0,
      );
    } else {
      state = state.copyWith(
        timeLimitSeconds: durationOption,
        isUnlimitedMode: false,
        elapsedSeconds: 0,
      );
    }
    _startTimerIfNeeded();
  }

  Future<bool> startSession({
    required String mode, // 'quick', 'topic', 'review'
    String? topicId,
    String? levelId,
    int targetCount = 10,
    int? timeLimitSeconds,
    bool isUnlimitedMode = false,
    int? seed,
  }) async {
    if (_isBusy) return false;
    _isBusy = true;
    try {
      _stopTimer();
      await _audioService.stop();
      state = state.copyWith(
        isLoading: true,
        isCompleted: false,
        clearSelectedOption: true,
        recordedAnswers: const [],
        currentIndex: 0,
        elapsedSeconds: 0,
        errorMessage: null,
      );

      final initialBatchSize =
          (timeLimitSeconds != null || isUnlimitedMode) ? 20 : targetCount;

      final generated = await _generator.generateSessionQuestions(
        mode: mode,
        topicId: topicId,
        levelId: levelId,
        targetCount: initialBatchSize,
        seed: seed,
      );

      if (generated.questions.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: mode == 'review'
              ? 'Hiện không có câu hỏi nào cần ôn tập ở mục này.'
              : 'Không tìm thấy bộ câu hỏi hợp lệ cho cấp độ này.',
        );
        return false;
      }

      final sessionId = 'ses_${_uuid.v4()}';
      final now = DateTime.now();
      _accumulatedActiveMs = 0;
      _activeSegmentStartedAt = now;
      _questionShownAt = now;

      await _db.createPracticeSession(
        sessionId: sessionId,
        topicId: generated.topicId,
        levelId: generated.levelId,
        mode: mode,
        totalQuestions: generated.questions.length,
        startedAt: now,
      );

      state = PracticeSessionState(
        sessionId: sessionId,
        mode: mode,
        topicId: generated.topicId,
        levelId: generated.levelId,
        questions: generated.questions,
        currentIndex: 0,
        selectedOption: null,
        recordedAnswers: const [],
        isLoading: false,
        isCompleted: false,
        activeDurationSeconds: 0,
        timeLimitSeconds: timeLimitSeconds,
        isUnlimitedMode: isUnlimitedMode,
        elapsedSeconds: 0,
      );

      _startTimerIfNeeded();

      // Auto-play first question if user enabled autoPlayQuestionAudio in Settings (never auto-play for Sight-Reading!)
      final settings = _ref.read(appSettingsProvider);
      if (settings.autoPlayQuestionAudio &&
          state.currentQuestion != null &&
          !state.currentQuestion!.isSightReading) {
        await _audioService.playAsset(state.currentQuestion!.audioAsset);
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể khởi tạo phiên luyện tập. Vui lòng thử lại.',
      );
      return false;
    } finally {
      _isBusy = false;
    }
  }

  /// Called when app goes to background so paused time is excluded (Section 6.11).
  void onAppPaused() {
    if (_activeSegmentStartedAt != null && !state.isCompleted) {
      _accumulatedActiveMs +=
          DateTime.now().difference(_activeSegmentStartedAt!).inMilliseconds;
      _activeSegmentStartedAt = null;
    }
    _audioService.stop();
  }

  /// Called when app resumes to foreground.
  void onAppResumed() {
    if (_activeSegmentStartedAt == null &&
        state.sessionId != null &&
        !state.isCompleted) {
      _activeSegmentStartedAt = DateTime.now();
    }
  }

  /// Allows switching level dynamically inside the Practice Room across all topics.
  Future<void> switchNoteLevelInSession(String newLevelId) async {
    if (_isBusy ||
        state.mode == 'review' ||
        state.topicId.isEmpty ||
        state.levelId == newLevelId) {
      return;
    }
    _isBusy = true;
    try {
      if (state.topicId == 'topic_staff_reading') {
        _ref.read(selectedStaffLevelIdProvider.notifier).state = newLevelId;
      } else if (state.topicId == 'topic_notes') {
        _ref.read(selectedNoteLevelIdProvider.notifier).state = newLevelId;
      }
      await _audioService.stop();

      final batchSize = state.isContinuousScoringMode ? 20 : 10;
      final generated = await _generator.generateSessionQuestions(
        mode: 'topic',
        topicId: state.topicId,
        levelId: newLevelId,
        targetCount: batchSize,
      );
      if (generated.questions.isEmpty) return;

      if (state.sessionId != null) {
        await _db.updateSessionTopicAndLevel(
          sessionId: state.sessionId!,
          topicId: state.topicId,
          levelId: newLevelId,
        );
      }

      _questionShownAt = DateTime.now();
      state = state.copyWith(
        levelId: newLevelId,
        questions: generated.questions,
        currentIndex: 0,
        clearSelectedOption: true,
      );

      final settings = _ref.read(appSettingsProvider);
      if (settings.autoPlayQuestionAudio &&
          state.currentQuestion != null &&
          !state.currentQuestion!.isSightReading) {
        await _audioService.playAsset(state.currentQuestion!.audioAsset);
      }
    } catch (_) {
    } finally {
      _isBusy = false;
    }
  }

  /// Allows toggling directly between "🎧 Nghe nốt" ('topic_notes') and "🎼 Đọc nốt" ('topic_staff_reading')
  /// inside the Practice Room while preserving the difficulty tier (Mức 1..4).
  Future<void> switchNotePracticeModeInSession(String targetTopicId) async {
    if (_isBusy || state.mode == 'review' || state.topicId == targetTopicId) {
      return;
    }
    if (targetTopicId != 'topic_notes' &&
        targetTopicId != 'topic_staff_reading') {
      return;
    }
    _isBusy = true;
    try {
      await _audioService.stop();

      final curLvl = state.levelId ?? '';
      final String mappedLevelId;
      if (targetTopicId == 'topic_staff_reading') {
        if (curLvl.contains('master')) {
          mappedLevelId = 'lvl_staff_master';
        } else if (curLvl.contains('adv')) {
          mappedLevelId = 'lvl_staff_adv';
        } else if (curLvl.contains('inter')) {
          mappedLevelId = 'lvl_staff_inter';
        } else {
          mappedLevelId = 'lvl_staff_basic';
        }
        _ref.read(selectedStaffLevelIdProvider.notifier).state = mappedLevelId;
      } else {
        if (curLvl.contains('master')) {
          mappedLevelId = 'lvl_notes_master';
        } else if (curLvl.contains('adv')) {
          mappedLevelId = 'lvl_notes_adv';
        } else if (curLvl.contains('inter')) {
          mappedLevelId = 'lvl_notes_inter';
        } else {
          mappedLevelId = 'lvl_notes_basic';
        }
        _ref.read(selectedNoteLevelIdProvider.notifier).state = mappedLevelId;
      }

      final batchSize = state.isContinuousScoringMode ? 20 : 10;
      final generated = await _generator.generateSessionQuestions(
        mode: 'topic',
        topicId: targetTopicId,
        levelId: mappedLevelId,
        targetCount: batchSize,
      );
      if (generated.questions.isEmpty) return;

      if (state.sessionId != null) {
        await _db.updateSessionTopicAndLevel(
          sessionId: state.sessionId!,
          topicId: targetTopicId,
          levelId: mappedLevelId,
        );
      }

      _questionShownAt = DateTime.now();
      state = state.copyWith(
        topicId: targetTopicId,
        levelId: mappedLevelId,
        questions: generated.questions,
        currentIndex: 0,
        clearSelectedOption: true,
      );

      final settings = _ref.read(appSettingsProvider);
      if (settings.autoPlayQuestionAudio &&
          state.currentQuestion != null &&
          !state.currentQuestion!.isSightReading) {
        await _audioService.playAsset(state.currentQuestion!.audioAsset);
      }
    } catch (_) {
    } finally {
      _isBusy = false;
    }
  }

  /// Submits an answer when the user taps directly on the interactive Piano Keyboard.
  Future<void> submitPianoKeyAnswer(String tappedNoteKey) async {
    final currentQ = state.currentQuestion;
    if (currentQ == null || state.isCurrentAnswered || state.isCompleted) {
      return;
    }

    // 1. Check exact optionKey match first (e.g. 'C3', 'G4'), then pitch-class match on 1-octave keyboard
    final exactMatch = currentQ.options
        .where((o) => o.optionKey.toUpperCase() == tappedNoteKey.toUpperCase())
        .firstOrNull;
    if (exactMatch != null) {
      if (!currentQ.isSightReading) {
        unawaited(_audioService.playPianoKey(exactMatch.optionKey));
      }
      await submitAnswer(exactMatch);
      return;
    }

    final tappedPitchClass =
        tappedNoteKey.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();

    final pitchClassMatches = currentQ.options
        .where((o) =>
            o.optionKey.replaceAll(RegExp(r'[0-9]'), '').toUpperCase() ==
            tappedPitchClass)
        .toList();

    if (pitchClassMatches.isNotEmpty) {
      final chosenOption =
          pitchClassMatches.where((o) => o.isCorrect).firstOrNull ??
              pitchClassMatches
                  .where((o) =>
                      o.optionKey.toUpperCase() == tappedNoteKey.toUpperCase())
                  .firstOrNull ??
              pitchClassMatches.first;
      if (!currentQ.isSightReading) {
        unawaited(_audioService.playPianoKey(chosenOption.optionKey));
      }
      await submitAnswer(chosenOption);
      return;
    }

    // 2. User tapped a piano key that is not among the 4 options -> definitely wrong
    if (!currentQ.isSightReading) {
      unawaited(_audioService.playPianoKey(tappedNoteKey));
    }
    final wrongSyntheticOption = QuestionOptionModel(
      id: '${currentQ.id}_piano_$tappedNoteKey',
      questionId: currentQ.id,
      optionKey: tappedNoteKey,
      label: tappedNoteKey,
      isCorrect: false,
      sortOrder: 99,
    );
    await submitAnswer(wrongSyntheticOption);
  }

  Future<void> submitAnswer(QuestionOptionModel option) async {
    final currentQ = state.currentQuestion;
    if (currentQ == null || state.isCurrentAnswered || state.isCompleted) {
      // Already answered -> ignore rapid/multiple taps (BR-04, TC-13)
      return;
    }

    final now = DateTime.now();
    final responseMs = _questionShownAt != null
        ? now.difference(_questionShownAt!).inMilliseconds.clamp(50, 300000)
        : 1000;

    final answer = AnswerModel(
      id: 'ans_${_uuid.v4()}',
      sessionId: state.sessionId ?? 'ses_unknown',
      questionId: currentQ.id,
      selectedOptionId: option.id,
      isCorrect: option.isCorrect,
      answeredAt: now,
      responseMs: responseMs,
    );

    final nextCombo = option.isCorrect ? state.currentCombo + 1 : 0;
    final nextMaxCombo =
        nextCombo > state.maxComboInSession ? nextCombo : state.maxComboInSession;

    state = state.copyWith(
      selectedOption: option,
      recordedAnswers: [...state.recordedAnswers, answer],
      currentCombo: nextCombo,
      maxComboInSession: nextMaxCombo,
    );

    final settings = _ref.read(appSettingsProvider);
    if (settings.hapticFeedbackEnabled) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
    if (currentQ.isSightReading) {
      // In Sight-Reading mode, play the true piano pitch after the user answers so they connect eye & ear!
      unawaited(_audioService.playAsset(currentQ.audioAsset));
    }
    await _audioService.playFeedbackSfx(isCorrect: option.isCorrect);
  }

  /// Advances to the next question or completes the session.
  /// In Timed / Unlimited mode, automatically replenishes questions so practice never stops early!
  Future<bool> nextQuestion() async {
    if (_isBusy || !state.isCurrentAnswered || state.isCompleted) return false;
    _isBusy = true;
    try {
      await _audioService.stop();

      final nextIdx = state.currentIndex + 1;

      // If in Continuous Scoring Mode (60s, 15m, 1h, Unlimited) and running low on questions,
      // generate more questions seamlessly without repeating the last question at the seam!
      if (state.isContinuousScoringMode && nextIdx >= state.questions.length) {
        final lastQ =
            state.questions.isNotEmpty ? state.questions.last : null;
        final more = await _generator.generateSessionQuestions(
          mode: state.mode == 'review' ? 'topic' : state.mode,
          topicId: state.topicId,
          levelId: state.levelId,
          targetCount: 15,
          excludeAudioAsset: lastQ?.audioAsset,
          excludeOptionKey: lastQ?.correctOption.optionKey,
        );
        if (more.questions.isNotEmpty) {
          final updatedQuestions = [...state.questions, ...more.questions];
          _questionShownAt = DateTime.now();
          state = state.copyWith(
            questions: updatedQuestions,
            currentIndex: nextIdx,
            clearSelectedOption: true,
          );
          final settings = _ref.read(appSettingsProvider);
          if (settings.autoPlayQuestionAudio &&
              state.currentQuestion != null &&
              !state.currentQuestion!.isSightReading) {
            await _audioService.playAsset(state.currentQuestion!.audioAsset);
          }
          return false;
        }
      }

      if (nextIdx < state.questions.length) {
        _questionShownAt = DateTime.now();
        state = state.copyWith(
          currentIndex: nextIdx,
          clearSelectedOption: true,
        );
        final settings = _ref.read(appSettingsProvider);
        if (settings.autoPlayQuestionAudio &&
            state.currentQuestion != null &&
            !state.currentQuestion!.isSightReading) {
          await _audioService.playAsset(state.currentQuestion!.audioAsset);
        }
        return false; // Not finished yet
      } else {
        await _completeSession();
        return true; // Session completed!
      }
    } finally {
      _isBusy = false;
    }
  }

  /// Completes the session immediately (when timer expires or user taps "Kết thúc & Tính điểm").
  Future<void> finishSessionNow() async {
    if (state.isCompleted) return;
    await _completeSession();
  }

  Future<void> _completeSession() async {
    if (state.isCompleted) return;
    _stopTimer();
    await _audioService.stop();
    final now = DateTime.now();
    if (_activeSegmentStartedAt != null) {
      _accumulatedActiveMs +=
          now.difference(_activeSegmentStartedAt!).inMilliseconds;
      _activeSegmentStartedAt = null;
    }
    final durationSec = state.elapsedSeconds > 0
        ? state.elapsedSeconds
        : (_accumulatedActiveMs / 1000).round().clamp(1, 7200);

    bool newHighScore = false;
    try {
      if (state.sessionId != null && state.recordedAnswers.isNotEmpty) {
        await _db.completeSessionTransaction(
          sessionId: state.sessionId!,
          mode: state.mode,
          topicId: state.topicId,
          levelId: state.levelId,
          answers: state.recordedAnswers,
          activeDurationSeconds: durationSec,
          completedAt: now,
        );
        final prevBestScore =
            int.tryParse(await _db.getSetting('best_score') ?? '0') ?? 0;
        if (state.scorePoints > prevBestScore && state.scorePoints > 0) {
          newHighScore = true;
          await _db.setSetting('best_score', state.scorePoints.toString());
        }
        final prevBestCombo =
            int.tryParse(await _db.getSetting('best_combo_streak') ?? '0') ?? 0;
        if (state.maxComboInSession > prevBestCombo &&
            state.maxComboInSession > 0) {
          await _db.setSetting(
              'best_combo_streak', state.maxComboInSession.toString());
        }
      } else if (state.sessionId != null) {
        await _db.abandonSession(state.sessionId!);
      }
    } catch (_) {}

    state = state.copyWith(
      isCompleted: true,
      activeDurationSeconds: durationSec,
      isNewHighScore: newHighScore,
    );

    // Refresh progress & review providers
    _ref.invalidate(overallProgressProvider);
    _ref.invalidate(pendingReviewItemsProvider);
  }

  /// Marks session as abandoned if user leaves mid-session without saving (BR-07).
  Future<void> abandonSessionIfIncomplete() async {
    _stopTimer();
    await _audioService.stop();
    if (state.sessionId != null && !state.isCompleted) {
      await _db.abandonSession(state.sessionId!);
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

final hybridQuestionGeneratorProvider = Provider<HybridQuestionGenerator>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final validator = ref.watch(assetValidatorProvider);
  return HybridQuestionGenerator(db, validator);
});

final practiceSessionProvider =
    StateNotifierProvider<PracticeSessionNotifier, PracticeSessionState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final generator = ref.watch(hybridQuestionGeneratorProvider);
  final audio = ref.watch(audioServiceProvider);
  return PracticeSessionNotifier(db, generator, audio, ref);
});
