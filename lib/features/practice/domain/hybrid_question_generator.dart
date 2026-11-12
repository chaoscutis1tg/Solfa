import 'dart:math';

import '../../../core/audio/asset_validator.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/domain_models.dart';

class HybridQuestionGenerator {
  final AppDatabase _db;
  final AssetValidator _assetValidator;

  HybridQuestionGenerator(this._db, this._assetValidator);

  /// Generates a session question set for 'quick', 'topic', or 'review' mode.
  /// Supports deterministic [seed] for reproducible unit testing (Section 11.3).
  Future<({String topicId, String? levelId, List<QuestionModel> questions})>
      generateSessionQuestions({
    required String mode, // 'quick', 'topic', 'review'
    String? topicId,
    String? levelId,
    int targetCount = 10,
    int? seed,
  }) async {
    final rng = Random(seed);

    if (mode == 'review') {
      final pending = await _db.getPendingReviewItems(topicId: topicId);
      final List<QuestionModel> validReviewQuestions = [];
      for (final item in pending) {
        final q = item.question;
        if (q != null && await _assetValidator.exists(q.audioAsset)) {
          validReviewQuestions.add(q);
        }
        if (validReviewQuestions.length >= targetCount) break;
      }
      final resolvedTopic = topicId ??
          (validReviewQuestions.isNotEmpty
              ? validReviewQuestions.first.topicId
              : 'topic_notes');
      return (
        topicId: resolvedTopic,
        levelId: null,
        questions: validReviewQuestions,
      );
    }

    // Resolve topic & level for 'quick' or 'topic' mode (UC-02)
    String resolvedTopicId = topicId ?? 'topic_notes';
    String resolvedLevelId = levelId ?? 'lvl_notes_basic';

    if (mode == 'quick' && topicId == null) {
      final stats = await _db.getOverallProgressStats();
      if (!stats.hasAnyHistory) {
        // New user -> default to Basic Note Recognition (UC-02)
        resolvedTopicId = 'topic_notes';
        resolvedLevelId = 'lvl_notes_basic';
      } else {
        // Returning user -> pick topic with lowest accuracy or least practiced
        final sortedTopics = [...stats.topicStats]..sort((a, b) {
            if (a.totalAnswered == 0 && b.totalAnswered > 0) return -1;
            if (b.totalAnswered == 0 && a.totalAnswered > 0) return 1;
            return a.accuracyPercent.compareTo(b.accuracyPercent);
          });
        if (sortedTopics.isNotEmpty) {
          resolvedTopicId = sortedTopics.first.topicId;
        }
        final levels = await _db.getLevelsByTopic(resolvedTopicId);
        resolvedLevelId = levels.isNotEmpty ? levels.first.id : 'lvl_notes_basic';
      }
    } else if (levelId == null) {
      final levels = await _db.getLevelsByTopic(resolvedTopicId);
      resolvedLevelId = levels.isNotEmpty ? levels.first.id : 'lvl_notes_basic';
    }

    // 1. Ensure dynamic hybrid pool is populated for this topic & level
    await _ensureDynamicQuestionsPersisted(
      topicId: resolvedTopicId,
      levelId: resolvedLevelId,
    );

    // 2. Load candidate questions from SQLite
    List<QuestionModel> candidates = await _db.getQuestions(
      topicId: resolvedTopicId,
      levelId: resolvedLevelId,
    );

    // Fallback to all levels in the topic if needed to reach targetCount
    if (candidates.length < targetCount) {
      final allInTopic = await _db.getQuestions(topicId: resolvedTopicId);
      final existingIds = candidates.map((q) => q.id).toSet();
      for (final q in allInTopic) {
        if (!existingIds.contains(q.id)) {
          candidates.add(q);
        }
      }
    }

    // 3. Validate audio assets (BR-08) and ensure non-duplicate option labels
    final List<QuestionModel> validCandidates = [];
    for (final q in candidates) {
      final hasAudio = await _assetValidator.exists(q.audioAsset);
      final labels = q.options.map((o) => o.label).toSet();
      final correctCount = q.options.where((o) => o.isCorrect).length;
      if (hasAudio &&
          q.options.length >= 2 &&
          labels.length == q.options.length &&
          correctCount == 1) {
        validCandidates.add(q);
      }
    }

    validCandidates.shuffle(rng);
    final selected = validCandidates.take(targetCount).toList();

    return (
      topicId: resolvedTopicId,
      levelId: resolvedLevelId,
      questions: selected,
    );
  }

  /// Dynamically synthesizes structured questions from bundled audio assets and persists them
  /// into SQLite so every question has a stable ID for answers & review_items (Decision #3).
  Future<void> _ensureDynamicQuestionsPersisted({
    required String topicId,
    required String levelId,
  }) async {
    final existing = await _db.getQuestions(topicId: topicId, levelId: levelId);
    if (existing.length >= 12) return;

    final List<QuestionModel> generated = [];

    if (topicId == 'topic_notes') {
      final isAdvanced = levelId.contains('adv');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);

      final baseNotes = [
        ('c4', 'C4', 'Đô (C4)', 'Nốt Đô (C4) nằm ngay bên trái cụm 2 phím đen, tần số 261.6 Hz.'),
        ('d4', 'D4', 'Rê (D4)', 'Nốt Rê (D4) nằm giữa 2 phím đen C# và D#, cao hơn Đô 1 cung.'),
        ('e4', 'E4', 'Mi (E4)', 'Nốt Mi (E4) nằm bên phải cụm 2 phím đen, là bậc III của Đô Trưởng.'),
        ('f4', 'F4', 'Fa (F4)', 'Nốt Fa (F4) nằm bên trái cụm 3 phím đen, cách Mi nửa cung.'),
        ('g4', 'G4', 'Sol (G4)', 'Nốt Sol (G4) cách Đô (C4) một quãng 5 đúng vững chãi.'),
        ('a4', 'A4', 'La (A4)', 'Nốt La (A4) có tần số chuẩn 440 Hz, bậc VI trong giọng Đô Trưởng.'),
        ('b4', 'B4', 'Si (B4)', 'Nốt Si (B4) là nốt dẫn nằm ngay dưới Đô cao (C5) nửa cung.'),
      ];

      final interAccidentalNotes = [
        ('csharp4', 'C#4', 'Đô# / Rêb (C#4)', 'Nốt Đô thăng (C#4 / Db4) là phím đen đầu tiên trong cụm 2 phím đen.'),
        ('dsharp4', 'D#4', 'Rê# / Mib (D#4)', 'Nốt Rê thăng (D#4 / Eb4) tạo quãng 3 thứ trầm buồn khi tính từ Đô (C4).'),
        ('fsharp4', 'F#4', 'Fa# / Solb (F#4)', 'Nốt Fa thăng (F#4 / Gb4) là phím đen đầu tiên trong cụm 3 phím đen.'),
        ('gsharp4', 'G#4', 'Sol# / Lab (G#4)', 'Nốt Sol thăng (G#4 / Ab4) nằm ở giữa cụm 3 phím đen.'),
        ('asharp4', 'A#4', 'La# / Sib (A#4)', 'Nốt La thăng (A#4 / Bb4) là phím đen ngoài cùng bên phải của cụm 3 phím đen.'),
      ];

      final advMultiOctaveNotes = [
        ('c3', 'C3', 'Đô trầm (C3)', 'Nốt Đô quãng 3 (C3 - 130.8 Hz), thấp hơn Đô chuẩn (C4) đúng 1 quãng tám.'),
        ('g3', 'G3', 'Sol trầm (G3)', 'Nốt Sol quãng 3 (G3 - 196.0 Hz), nằm ở âm vực trầm ấm dưới C4.'),
        ('a3', 'A3', 'La trầm (A3)', 'Nốt La quãng 3 (A3 - 220.0 Hz), thấp hơn La chuẩn (A4) đúng 1 quãng tám.'),
        ('c5', 'C5', 'Đô cao (C5)', 'Nốt Đô quãng 5 (C5 - 523.3 Hz), cao hơn Đô chuẩn (C4) đúng 1 quãng tám.'),
        ('e5', 'E5', 'Mi cao (E5)', 'Nốt Mi quãng 5 (E5 - 659.3 Hz), mang âm sắc sáng rõ ở quãng tám trên.'),
        ('g5', 'G5', 'Sol cao (G5)', 'Nốt Sol quãng 5 (G5 - 784.0 Hz), nằm ở âm vực cao trong sáng.'),
      ];

      final noteDefs = [
        ...baseNotes,
        if (isInter) ...interAccidentalNotes,
        if (isAdvanced) ...advMultiOctaveNotes,
      ];

      for (int i = 0; i < noteDefs.length; i++) {
        final (fileKey, optKey, label, desc) = noteDefs[i];
        final qId = 'dyn_note_${levelId}_$fileKey';
        final distractors = <int>[
          (i + 1) % noteDefs.length,
          (i + 2) % noteDefs.length,
          (i + 4) % noteDefs.length,
        ];
        final allIndices = [i, ...distractors]..sort();

        final options = <QuestionOptionModel>[];
        for (int idx = 0; idx < allIndices.length; idx++) {
          final d = noteDefs[allIndices[idx]];
          options.add(
            QuestionOptionModel(
              id: '${qId}_o${idx + 1}',
              questionId: qId,
              optionKey: d.$2,
              label: d.$3,
              isCorrect: allIndices[idx] == i,
              sortOrder: idx + 1,
            ),
          );
        }

        generated.add(
          QuestionModel(
            id: qId,
            topicId: topicId,
            levelId: levelId,
            type: i.isEven ? 'listen_note' : 'piano_key',
            prompt: isAdvanced
                ? '[Nâng cao - Đa quãng tám] Nghe âm thanh (không tham chiếu C4) và chọn chính xác tên nốt:'
                : (isInter
                    ? 'Nghe cao độ nốt nhạc (bao gồm cả dấu hóa #/b, đối chiếu C4) và chọn đáp án đúng:'
                    : 'Nghe nốt nhạc (có thể bấm nghe nốt chuẩn Đô C4) và chọn đáp án đúng:'),
            explanation: desc,
            audioAsset: 'assets/audio/notes/$fileKey.wav',
            difficulty: diff,
            version: 1,
            options: options,
          ),
        );
      }
    } else if (topicId == 'topic_intervals') {
      final isAdvanced = levelId.contains('adv');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);
      final modeSuffix = isAdvanced ? 'harm' : (isInter ? 'desc' : 'asc');

      final intervalDefs = [
        ('maj2', 'Quãng 2 trưởng', 'Cách nhau 1 cung nguyên (2 nửa cung).'),
        ('min3', 'Quãng 3 thứ', 'Cách nhau 1,5 cung (3 nửa cung), âm hưởng mềm mại/trầm.'),
        ('maj3', 'Quãng 3 trưởng', 'Cách nhau 2 cung (4 nửa cung), âm hưởng sáng rõ.'),
        ('p4', 'Quãng 4 đúng', 'Cách nhau 2,5 cung (5 nửa cung), âm hưởng mở đầu vững vàng.'),
        ('p5', 'Quãng 5 đúng', 'Cách nhau 3,5 cung (7 nửa cung), độ hòa hợp rất vững.'),
        ('maj6', 'Quãng 6 trưởng', 'Cách nhau 4,5 cung (9 nửa cung), âm hưởng ấm áp.'),
        ('p8', 'Quãng 8 đúng (Octave)', 'Cách nhau 6 cung (12 nửa cung), lặp lại tên nốt ở quãng tám mới.'),
        if (isInter || isAdvanced)
          ('min2', 'Quãng 2 thứ', 'Cách nhau nửa cung (1 bán âm), tạo cảm giác sát gần kịch tính.'),
        if (isAdvanced)
          ('tritone', 'Quãng 4 tăng / 5 giảm (Tritone)', 'Cách nhau 3 cung nguyên (6 nửa cung), có độ căng hòa thanh mạnh.'),
        if (isAdvanced)
          ('maj7', 'Quãng 7 trưởng', 'Cách nhau 5,5 cung (11 nửa cung), âm hưởng sắc nét hiện đại.'),
      ];

      for (int i = 0; i < intervalDefs.length; i++) {
        final (code, label, desc) = intervalDefs[i];
        final root = i.isEven ? 'c4' : 'f4';
        final qId = 'dyn_int_${levelId}_${root}_${code}_$modeSuffix';
        final distractors = <int>[
          (i + 1) % intervalDefs.length,
          (i + 2) % intervalDefs.length,
          (i + 4) % intervalDefs.length,
        ];
        final allIndices = [i, ...distractors]..sort();

        final options = <QuestionOptionModel>[];
        for (int idx = 0; idx < allIndices.length; idx++) {
          final d = intervalDefs[allIndices[idx]];
          options.add(
            QuestionOptionModel(
              id: '${qId}_o${idx + 1}',
              questionId: qId,
              optionKey: d.$1,
              label: d.$2,
              isCorrect: allIndices[idx] == i,
              sortOrder: idx + 1,
            ),
          );
        }

        generated.add(
          QuestionModel(
            id: qId,
            topicId: topicId,
            levelId: levelId,
            type: isAdvanced ? 'interval_harmonic' : 'interval_melodic',
            prompt: isAdvanced
                ? 'Nghe hai nốt phát đồng thời (quãng hòa thanh) và chọn tên quãng:'
                : (isInter
                    ? 'Nghe hai nốt đi xuống liên tiếp và xác định quãng giữa chúng:'
                    : 'Nghe hai nốt đi lên liên tiếp và chọn tên quãng đúng:'),
            explanation: '$label: $desc',
            audioAsset: 'assets/audio/intervals/${root}_${code}_$modeSuffix.wav',
            difficulty: diff,
            version: 1,
            options: options,
          ),
        );
      }
    } else if (topicId == 'topic_keys') {
      final isAdvanced = levelId.contains('adv');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);

      final keyItems = [
        (
          'c_major',
          'Đô Trưởng (C Major)',
          'Giọng Trưởng (Major)',
          'Chuỗi hòa âm I-IV-V-I ở giọng Đô Trưởng (0 dấu hóa), màu sắc tươi sáng.',
          true
        ),
        (
          'a_minor',
          'La Thứ (A Minor)',
          'Giọng Thứ (Minor)',
          'Chuỗi hòa âm i-iv-V-i ở giọng La Thứ (0 dấu hóa), màu sắc trầm lắng.',
          false
        ),
        (
          'g_major',
          'Sol Trưởng (G Major)',
          'Giọng Trưởng (Major)',
          'Chuỗi hòa âm giọng Sol Trưởng (1 dấu thăng Fa#), âm hưởng sáng rõ.',
          true
        ),
        (
          'e_minor',
          'Mi Thứ (E Minor)',
          'Giọng Thứ (Minor)',
          'Chuỗi hòa âm giọng Mi Thứ (1 dấu thăng Fa#), song song với Sol Trưởng.',
          false
        ),
        (
          'f_major',
          'Fa Trưởng (F Major)',
          'Giọng Trưởng (Major)',
          'Chuỗi hòa âm giọng Fa Trưởng (1 dấu giáng Sib), ấm áp và vững chãi.',
          true
        ),
        (
          'd_minor',
          'Rê Thứ (D Minor)',
          'Giọng Thứ (Minor)',
          'Chuỗi hòa âm giọng Rê Thứ (1 dấu giáng Sib), song song với Fa Trưởng.',
          false
        ),
        (
          'd_major',
          'Rê Trưởng (D Major)',
          'Giọng Trưởng (Major)',
          'Chuỗi hòa âm giọng Rê Trưởng (2 dấu thăng Fa#, Đô#).',
          true
        ),
        (
          'b_minor',
          'Si Thứ (B Minor)',
          'Giọng Thứ (Minor)',
          'Chuỗi hòa âm giọng Si Thứ (2 dấu thăng Fa#, Đô#).',
          false
        ),
      ];

      for (int i = 0; i < keyItems.length; i++) {
        final (fileKey, keyLabel, qualityLabel, desc, isMaj) = keyItems[i];
        final qId = 'dyn_key_${levelId}_$fileKey';

        final List<QuestionOptionModel> options;
        if (diff == 1) {
          options = [
            QuestionOptionModel(
              id: '${qId}_o1',
              questionId: qId,
              optionKey: 'major',
              label: 'Giọng Trưởng (Major) – tươi sáng',
              isCorrect: isMaj,
              sortOrder: 1,
            ),
            QuestionOptionModel(
              id: '${qId}_o2',
              questionId: qId,
              optionKey: 'minor',
              label: 'Giọng Thứ (Minor) – trầm lắng',
              isCorrect: !isMaj,
              sortOrder: 2,
            ),
          ];
        } else {
          final distractors = <int>[
            (i + 1) % keyItems.length,
            (i + 2) % keyItems.length,
            (i + 3) % keyItems.length,
          ];
          final allIdx = [i, ...distractors]..sort();
          options = [
            for (int idx = 0; idx < allIdx.length; idx++)
              QuestionOptionModel(
                id: '${qId}_o${idx + 1}',
                questionId: qId,
                optionKey: keyItems[allIdx[idx]].$1,
                label: keyItems[allIdx[idx]].$2,
                isCorrect: allIdx[idx] == i,
                sortOrder: idx + 1,
              ),
          ];
        }

        generated.add(
          QuestionModel(
            id: qId,
            topicId: topicId,
            levelId: levelId,
            type: diff == 1 ? 'key_quality' : 'key_center',
            prompt: diff == 1
                ? 'Nghe chuỗi hòa âm và xác định màu sắc Trưởng hay Thứ:'
                : 'Nghe chuỗi hòa âm (có thể đối chiếu C4) và chọn tên giọng đúng:',
            explanation: desc,
            audioAsset: 'assets/audio/keys/$fileKey.wav',
            difficulty: diff,
            version: 1,
            options: options,
          ),
        );
      }
    }

    for (final q in generated) {
      await _db.upsertQuestion(q);
    }
  }
}

