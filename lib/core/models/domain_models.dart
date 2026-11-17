class TopicModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final int sortOrder;
  final bool isEnabled;

  const TopicModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.isEnabled,
  });

  factory TopicModel.fromMap(Map<String, dynamic> map) {
    return TopicModel(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 1,
      isEnabled: (map['is_enabled'] == 1 || map['is_enabled'] == true),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'sort_order': sortOrder,
        'is_enabled': isEnabled ? 1 : 0,
      };
}

class LevelModel {
  final String id;
  final String topicId;
  final String code;
  final String name;
  final int difficulty;
  final String unlockRule;

  const LevelModel({
    required this.id,
    required this.topicId,
    required this.code,
    required this.name,
    required this.difficulty,
    required this.unlockRule,
  });

  /// Returns true if reference pitch C4 should be available in this level (Levels 1, 2, 3)
  bool get allowsReferencePitch => difficulty <= 3;

  factory LevelModel.fromMap(Map<String, dynamic> map) {
    return LevelModel(
      id: map['id'] as String,
      topicId: map['topic_id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
      unlockRule: map['unlock_rule'] as String? ?? 'always_unlocked',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'code': code,
        'name': name,
        'difficulty': difficulty,
        'unlock_rule': unlockRule,
      };
}

class QuestionOptionModel {
  final String id;
  final String questionId;
  final String optionKey;
  final String label;
  final bool isCorrect;
  final int sortOrder;

  const QuestionOptionModel({
    required this.id,
    required this.questionId,
    required this.optionKey,
    required this.label,
    required this.isCorrect,
    required this.sortOrder,
  });

  factory QuestionOptionModel.fromMap(Map<String, dynamic> map) {
    return QuestionOptionModel(
      id: map['id'] as String,
      questionId: map['question_id'] as String,
      optionKey: map['option_key'] as String,
      label: map['label'] as String,
      isCorrect: (map['is_correct'] == 1 || map['is_correct'] == true),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'question_id': questionId,
        'option_key': optionKey,
        'label': label,
        'is_correct': isCorrect ? 1 : 0,
        'sort_order': sortOrder,
      };
}

class QuestionModel {
  final String id;
  final String topicId;
  final String levelId;
  final String type;
  final String prompt;
  final String explanation;
  final String audioAsset;
  final int difficulty;
  final int version;
  final List<QuestionOptionModel> options;

  const QuestionModel({
    required this.id,
    required this.topicId,
    required this.levelId,
    required this.type,
    required this.prompt,
    required this.explanation,
    required this.audioAsset,
    required this.difficulty,
    required this.version,
    required this.options,
  });

  QuestionOptionModel get correctOption =>
      options.firstWhere((o) => o.isCorrect, orElse: () => options.first);

  /// Whether this question is a visual Sight-Reading question (read note from staff without listening first)
  bool get isSightReading =>
      type == 'read_staff_note' || topicId == 'topic_staff_reading';

  /// Whether this question can show reference pitch C4 (Topic notes ear training, difficulty 1..3)
  bool get supportsReferencePitch =>
      topicId == 'topic_notes' &&
      !isSightReading &&
      difficulty <= 3 &&
      type != 'compare_pitch';

  /// Whether this question should display the interactive Musical Staff & Piano Keyboard helper
  bool get showPianoHelper =>
      topicId == 'topic_notes' ||
      topicId == 'topic_staff_reading' ||
      isSightReading;

  /// Whether black keys (#/b) are enabled on the interactive Piano helper for this question's level
  bool get allowBlackKeysOnPiano => difficulty == 2 || difficulty == 4;

  factory QuestionModel.fromMap(
    Map<String, dynamic> map, {
    List<QuestionOptionModel> options = const [],
  }) {
    return QuestionModel(
      id: map['id'] as String,
      topicId: map['topic_id'] as String,
      levelId: map['level_id'] as String,
      type: map['type'] as String? ?? 'listen_note',
      prompt: map['prompt'] as String,
      explanation: map['explanation'] as String? ?? '',
      audioAsset: map['audio_asset'] as String,
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
      version: (map['version'] as num?)?.toInt() ?? 1,
      options: options,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'level_id': levelId,
        'type': type,
        'prompt': prompt,
        'explanation': explanation,
        'audio_asset': audioAsset,
        'difficulty': difficulty,
        'version': version,
      };
}

class PracticeSessionModel {
  final String id;
  final String topicId;
  final String? levelId;
  final String mode; // 'quick', 'topic', 'review'
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // 'in_progress', 'completed', 'abandoned'
  final int totalQuestions;
  final int correctCount;
  final int durationSeconds;
  final String? topicName;
  final String? levelName;

  const PracticeSessionModel({
    required this.id,
    required this.topicId,
    this.levelId,
    required this.mode,
    required this.startedAt,
    this.endedAt,
    required this.status,
    required this.totalQuestions,
    required this.correctCount,
    this.durationSeconds = 0,
    this.topicName,
    this.levelName,
  });

  /// Accuracy = correct / total * 100%; guard against division by zero
  double get accuracyPercent =>
      totalQuestions <= 0 ? 0.0 : (correctCount / totalQuestions) * 100.0;

  static String fallbackTopicName(String topicId) {
    switch (topicId) {
      case 'topic_notes':
        return 'Nhận biết nốt';
      case 'topic_staff_reading':
        return 'Đọc nốt nhạc';
      case 'topic_intervals':
        return 'Nhận biết quãng';
      case 'topic_keys':
        return 'Nhận biết giọng';
      case 'topic_chords':
        return 'Nhận biết hợp âm';
      case 'topic_melody':
        return 'Nghe giai điệu';
      case 'topic_rhythm':
        return 'Nhận biết nhịp điệu';
      case 'topic_guitar_notes':
        return 'Nhớ nốt Cần đàn Guitar';
      case 'topic_guitar_chords':
        return 'Hợp âm Guitar';
      case 'topic_guitar_scales':
        return 'Bản đồ Scale Guitar';
      case 'topic_guitar_tabs':
        return 'Đọc Tab & Luyện ngón Guitar';
      default:
        return 'Luyện tập âm nhạc';
    }
  }

  static String fallbackLevelName(String? levelId) {
    if (levelId == null || levelId.isEmpty) return 'Cơ bản';
    if (levelId.contains('master') || levelId.contains('4')) {
      return 'Mức 4: Nâng cao';
    }
    if (levelId.contains('adv') || levelId.contains('3')) {
      return 'Mức 3: Nâng cao';
    }
    if (levelId.contains('inter') || levelId.contains('2')) {
      return 'Mức 2: Trung bình';
    }
    return 'Mức 1: Cơ bản';
  }

  factory PracticeSessionModel.fromMap(Map<String, dynamic> map) {
    final started = DateTime.tryParse(map['started_at'] as String? ?? '') ??
        DateTime.now();
    final endedStr = map['ended_at'] as String?;
    final ended = endedStr != null ? DateTime.tryParse(endedStr) : null;
    int duration = (map['duration_seconds'] as num?)?.toInt() ?? 0;
    if (duration <= 0 && ended != null) {
      duration = ended.difference(started).inSeconds.clamp(1, 7200);
    }
    final tId = map['topic_id'] as String? ?? 'topic_notes';
    final lId = map['level_id'] as String?;
    return PracticeSessionModel(
      id: map['id'] as String,
      topicId: tId,
      levelId: lId,
      mode: map['mode'] as String? ?? 'topic',
      startedAt: started,
      endedAt: ended,
      status: map['status'] as String? ?? 'completed',
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      durationSeconds: duration,
      topicName: (map['topic_name'] as String?) ?? fallbackTopicName(tId),
      levelName: (map['level_name'] as String?) ?? fallbackLevelName(lId),
    );
  }
}

class AnswerModel {
  final String id;
  final String sessionId;
  final String questionId;
  final String selectedOptionId;
  final bool isCorrect;
  final DateTime answeredAt;
  final int responseMs;

  const AnswerModel({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.selectedOptionId,
    required this.isCorrect,
    required this.answeredAt,
    required this.responseMs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'question_id': questionId,
        'selected_option_id': selectedOptionId,
        'is_correct': isCorrect ? 1 : 0,
        'answered_at': answeredAt.toIso8601String(),
        'response_ms': responseMs,
      };
}

class ReviewItemModel {
  final String id;
  final String questionId;
  final DateTime lastWrongAt;
  final int wrongCount;
  final int correctReviewCount;
  final String reviewStatus; // 'pending' or 'mastered'
  final QuestionModel? question;
  final String? topicName;

  const ReviewItemModel({
    required this.id,
    required this.questionId,
    required this.lastWrongAt,
    required this.wrongCount,
    required this.correctReviewCount,
    required this.reviewStatus,
    this.question,
    this.topicName,
  });

  /// Required consecutive correct answers in review to mark as mastered (Decision #4)
  static const int requiredConsecutiveCorrect = 2;

  int get remainingToMaster =>
      (requiredConsecutiveCorrect - correctReviewCount).clamp(0, requiredConsecutiveCorrect);

  factory ReviewItemModel.fromMap(
    Map<String, dynamic> map, {
    QuestionModel? question,
    String? topicName,
  }) {
    return ReviewItemModel(
      id: map['id'] as String,
      questionId: map['question_id'] as String,
      lastWrongAt:
          DateTime.tryParse(map['last_wrong_at'] as String? ?? '') ?? DateTime.now(),
      wrongCount: (map['wrong_count'] as num?)?.toInt() ?? 1,
      correctReviewCount: (map['correct_review_count'] as num?)?.toInt() ?? 0,
      reviewStatus: map['review_status'] as String? ?? 'pending',
      question: question,
      topicName: topicName,
    );
  }
}

class DailyActivityModel {
  final String activityDate; // YYYY-MM-DD
  final int answeredCount;
  final int correctCount;
  final int durationSeconds;

  const DailyActivityModel({
    required this.activityDate,
    required this.answeredCount,
    required this.correctCount,
    required this.durationSeconds,
  });

  double get accuracyPercent =>
      answeredCount <= 0 ? 0.0 : (correctCount / answeredCount) * 100.0;

  factory DailyActivityModel.fromMap(Map<String, dynamic> map) {
    return DailyActivityModel(
      activityDate: map['activity_date'] as String,
      answeredCount: (map['answered_count'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class MetronomePresetModel {
  final String id;
  final String name;
  final int bpm;
  final int numerator;
  final int denominator;
  final String soundType; // 'click', 'woodblock', 'bell'

  const MetronomePresetModel({
    required this.id,
    required this.name,
    required this.bpm,
    required this.numerator,
    required this.denominator,
    required this.soundType,
  });

  String get timeSignatureLabel => '$numerator/$denominator';

  factory MetronomePresetModel.fromMap(Map<String, dynamic> map) {
    return MetronomePresetModel(
      id: map['id'] as String,
      name: map['name'] as String,
      bpm: (map['bpm'] as num?)?.toInt() ?? 100,
      numerator: (map['numerator'] as num?)?.toInt() ?? 4,
      denominator: (map['denominator'] as num?)?.toInt() ?? 4,
      soundType: map['sound_type'] as String? ?? 'click',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'bpm': bpm,
        'numerator': numerator,
        'denominator': denominator,
        'sound_type': soundType,
      };
}

class TopicAccuracyStat {
  final String topicId;
  final String topicName;
  final int totalAnswered;
  final int correctCount;
  final int completedSessions;

  static const int minQuestionsThreshold = 5;

  const TopicAccuracyStat({
    required this.topicId,
    required this.topicName,
    required this.totalAnswered,
    required this.correctCount,
    required this.completedSessions,
  });

  bool get hasEnoughData => totalAnswered >= minQuestionsThreshold;

  double get accuracyPercent =>
      totalAnswered <= 0 ? 0.0 : (correctCount / totalAnswered) * 100.0;
}

class NoteMasteryStat {
  final String pitchClass; // 'C', 'C#', 'D', ..., 'B'
  final String solfegeLabel; // 'Đô', 'Đô#', 'Rê', ..., 'Si'
  final bool isSharp;
  final int totalAnswered;
  final int correctCount;

  const NoteMasteryStat({
    required this.pitchClass,
    required this.solfegeLabel,
    required this.isSharp,
    required this.totalAnswered,
    required this.correctCount,
  });

  double get accuracyPercent =>
      totalAnswered <= 0 ? 0.0 : (correctCount / totalAnswered) * 100.0;
}

class OverallProgressStats {
  final int totalAnswered;
  final int totalCorrect;
  final int totalDurationSeconds;
  final int currentStreakDays;
  final int pendingReviewCount;
  final List<TopicAccuracyStat> topicStats;
  final List<PracticeSessionModel> recentSessions;
  final List<DailyActivityModel> dailyActivities;
  final List<NoteMasteryStat> noteMasteryStats;
  final int todayAnsweredCount;
  final int dailyGoalTarget;
  final int bestScore;
  final int bestComboStreak;

  const OverallProgressStats({
    required this.totalAnswered,
    required this.totalCorrect,
    required this.totalDurationSeconds,
    required this.currentStreakDays,
    required this.pendingReviewCount,
    required this.topicStats,
    required this.recentSessions,
    required this.dailyActivities,
    this.noteMasteryStats = const [],
    this.todayAnsweredCount = 0,
    this.dailyGoalTarget = 20,
    this.bestScore = 0,
    this.bestComboStreak = 0,
  });

  bool get hasAnyHistory => totalAnswered > 0 || recentSessions.isNotEmpty;

  double get dailyGoalProgress =>
      dailyGoalTarget <= 0 ? 1.0 : (todayAnsweredCount / dailyGoalTarget).clamp(0.0, 1.0);

  bool get isDailyGoalReached => todayAnsweredCount >= dailyGoalTarget;

  int get completedSessionsCount {
    final fromTopics =
        topicStats.fold<int>(0, (sum, t) => sum + t.completedSessions);
    return fromTopics > 0 ? fromTopics : recentSessions.length;
  }

  double get overallAccuracyPercent =>
      totalAnswered <= 0 ? 0.0 : (totalCorrect / totalAnswered) * 100.0;
}

