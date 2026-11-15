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
        resolvedLevelId = levelId ?? 'lvl_notes_basic';
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
        resolvedLevelId = (resolvedTopicId == 'topic_notes' && levelId != null)
            ? levelId
            : (levels.isNotEmpty ? levels.first.id : 'lvl_notes_basic');
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

    // 2. Load candidate questions from SQLite for the exact level
    List<QuestionModel> candidates = await _db.getQuestions(
      topicId: resolvedTopicId,
      levelId: resolvedLevelId,
    );

    // Filter out any legacy compare_pitch questions if topic_notes
    if (resolvedTopicId == 'topic_notes') {
      candidates =
          candidates.where((q) => q.type != 'compare_pitch').toList();
    }

    // Fallback to all levels in the topic ONLY if this level has 0 questions
    if (candidates.isEmpty) {
      final allInTopic = await _db.getQuestions(topicId: resolvedTopicId);
      for (final q in allInTopic) {
        if (resolvedTopicId != 'topic_notes' || q.type != 'compare_pitch') {
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

    if (validCandidates.isEmpty) {
      return (
        topicId: resolvedTopicId,
        levelId: resolvedLevelId,
        questions: <QuestionModel>[],
      );
    }

    validCandidates.shuffle(rng);
    final List<QuestionModel> selected = [];
    while (selected.length < targetCount) {
      final pool = [...validCandidates]..shuffle(rng);
      // Avoid immediate back-to-back identical audio asset at boundary
      if (selected.isNotEmpty &&
          pool.length > 1 &&
          pool.first.audioAsset == selected.last.audioAsset) {
        final first = pool.removeAt(0);
        pool.add(first);
      }
      final needed = targetCount - selected.length;
      selected.addAll(pool.take(needed));
    }

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
    final nonCompareExisting = existing
        .where((q) => topicId != 'topic_notes' || q.type != 'compare_pitch')
        .toList();
    if (nonCompareExisting.length >= 14) return;

    final List<QuestionModel> generated = [];

    if (topicId == 'topic_notes' || topicId == 'topic_staff_reading') {
      final isStaffReading = topicId == 'topic_staff_reading';
      final isMaster = levelId.contains('master') || levelId.contains('4');
      final isAdvanced = levelId.contains('adv') || levelId.contains('3');
      final isInter = levelId.contains('inter') || levelId.contains('2');
      final diff = isMaster
          ? 4
          : (isAdvanced
              ? 3
              : (isInter ? 2 : 1));

      // Mức 1: Chỉ 7 nốt tự nhiên trong quãng C4 (C4..B4), không dấu #/b
      final level1C4Natural = [
        (
          'c4',
          'C4',
          'Đô (C4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Đô chuẩn (C4) nằm trên 1 dòng kẻ phụ ngay bên dưới dòng kẻ thứ 1.'
              : 'Nốt Đô (C4) nằm ngay bên trái cụm 2 phím đen, tần số 261.6 Hz.'
        ),
        (
          'd4',
          'D4',
          'Rê (D4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Rê (D4) nằm sát ngay bên dưới dòng kẻ thứ 1 (dưới cùng).'
              : 'Nốt Rê (D4) nằm giữa 2 phím đen C# và D#, cao hơn Đô 1 cung.'
        ),
        (
          'e4',
          'E4',
          'Mi (E4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Mi (E4) nằm chính giữa dòng kẻ thứ 1 (dưới cùng) của khuông nhạc.'
              : 'Nốt Mi (E4) nằm bên phải cụm 2 phím đen, là bậc III của Đô Trưởng.'
        ),
        (
          'f4',
          'F4',
          'Fa (F4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Fa (F4) nằm gọn trong khe thứ 1 (giữa dòng 1 và dòng 2).'
              : 'Nốt Fa (F4) nằm bên trái cụm 3 phím đen, cách Mi nửa cung.'
        ),
        (
          'g4',
          'G4',
          'Sol (G4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Sol (G4) nằm trên dòng kẻ thứ 2 (tâm vòng xoắn của ký hiệu Khóa Sol).'
              : 'Nốt Sol (G4) cách Đô (C4) một quãng 5 đúng vững chãi.'
        ),
        (
          'a4',
          'A4',
          'La (A4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt La (A4) nằm trong khe thứ 2 (giữa dòng 2 và dòng 3).'
              : 'Nốt La (A4) có tần số chuẩn 440 Hz, bậc VI trong giọng Đô Trưởng.'
        ),
        (
          'b4',
          'B4',
          'Si (B4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Si (B4) nằm chính giữa dòng kẻ thứ 3 (dòng giữa khuông nhạc).'
              : 'Nốt Si (B4) là nốt dẫn nằm ngay dưới Đô cao (C5) nửa cung.'
        ),
      ];

      // Mức 2: Gói gọn trong quãng C4 (C4..B4) có thêm 5 nốt dấu thăng/giáng (#/b)
      final level2C4Chromatic = [
        ...level1C4Natural,
        (
          'csharp4',
          'C#4',
          'Đô# / Rêb (C#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Đô thăng (C#4) nằm trên dòng kẻ phụ dưới cùng kèm dấu thăng (♯).'
              : 'Nốt Đô thăng (C#4 / Db4) là phím đen đầu tiên trong cụm 2 phím đen.'
        ),
        (
          'dsharp4',
          'D#4',
          'Rê# / Mib (D#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Rê thăng (D#4) nằm sát dưới dòng kẻ 1 kèm dấu thăng (♯).'
              : 'Nốt Rê thăng (D#4 / Eb4) là phím đen thứ hai trong cụm 2 phím đen.'
        ),
        (
          'fsharp4',
          'F#4',
          'Fa# / Solb (F#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Fa thăng (F#4) nằm ở khe thứ 1 kèm dấu thăng (♯).'
              : 'Nốt Fa thăng (F#4 / Gb4) là phím đen đầu tiên trong cụm 3 phím đen.'
        ),
        (
          'gsharp4',
          'G#4',
          'Sol# / Lab (G#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Sol thăng (G#4) nằm trên dòng kẻ thứ 2 kèm dấu thăng (♯).'
              : 'Nốt Sol thăng (G#4 / Ab4) nằm ở giữa cụm 3 phím đen.'
        ),
        (
          'asharp4',
          'A#4',
          'La# / Sib (A#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt La thăng (A#4) nằm ở khe thứ 2 kèm dấu thăng (♯).'
              : 'Nốt La thăng (A#4 / Bb4) là phím đen ngoài cùng bên phải cụm 3 phím đen.'
        ),
      ];

      // Mức 3: Đa quãng tám C3–C5 nhưng chỉ các nốt tự nhiên (không dấu #/b)
      final level3MultiNatural = [
        (
          'c3',
          'C3',
          'Đô trầm (C3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Đô trầm (C3) nằm ở khe thứ 2 (từ dưới lên) của khuông nhạc Khóa Fa.'
              : 'Nốt Đô quãng 3 (C3 - 130.8 Hz), thấp hơn Đô chuẩn (C4) đúng 1 quãng tám.'
        ),
        (
          'd3',
          'D3',
          'Rê trầm (D3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Rê trầm (D3) nằm chính giữa dòng kẻ thứ 3 (dòng giữa) của Khóa Fa.'
              : 'Nốt Rê quãng 3 (D3 - 146.8 Hz), âm vực trầm ấm.'
        ),
        (
          'e3',
          'E3',
          'Mi trầm (E3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Mi trầm (E3) nằm ở khe thứ 3 của khuông nhạc Khóa Fa.'
              : 'Nốt Mi quãng 3 (E3 - 164.8 Hz), bậc III ở quãng tám dưới.'
        ),
        (
          'f3',
          'F3',
          'Fa trầm (F3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Fa trầm (F3) nằm trên dòng kẻ thứ 4 (giữa 2 dấu chấm của Khóa Fa).'
              : 'Nốt Fa quãng 3 (F3 - 174.6 Hz), nằm ở quãng tám trầm.'
        ),
        (
          'g3',
          'G3',
          'Sol trầm (G3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Sol trầm (G3) nằm ở khe thứ 4 (giữa dòng 4 và dòng 5) của Khóa Fa.'
              : 'Nốt Sol quãng 3 (G3 - 196.0 Hz), nằm ở âm vực trầm ấm dưới C4.'
        ),
        (
          'a3',
          'A3',
          'La trầm (A3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt La trầm (A3) nằm trên dòng kẻ thứ 5 (trên cùng) của khuông nhạc Khóa Fa.'
              : 'Nốt La quãng 3 (A3 - 220.0 Hz), thấp hơn La chuẩn (A4) đúng 1 quãng tám.'
        ),
        (
          'b3',
          'B3',
          'Si trầm (B3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Si trầm (B3) nằm sát ngay phía trên dòng kẻ thứ 5 của Khóa Fa.'
              : 'Nốt Si quãng 3 (B3 - 246.9 Hz), nằm ngay dưới Đô chuẩn (C4) nửa cung.'
        ),
        ...level1C4Natural,
        (
          'c5',
          'C5',
          'Đô cao (C5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Đô cao (C5) nằm trong khe thứ 3 (giữa dòng 3 và dòng 4).'
              : 'Nốt Đô quãng 5 (C5 - 523.3 Hz), cao hơn Đô chuẩn (C4) đúng 1 quãng tám.'
        ),
        (
          'd5',
          'D5',
          'Rê cao (D5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Rê cao (D5) nằm trên dòng kẻ thứ 4 của khuông nhạc Khóa Sol.'
              : 'Nốt Rê quãng 5 (D5 - 587.3 Hz), âm vực cao sáng.'
        ),
        (
          'e5',
          'E5',
          'Mi cao (E5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Mi cao (E5) nằm trong khe thứ 4 (khe trên cùng) của Khóa Sol.'
              : 'Nốt Mi quãng 5 (E5 - 659.3 Hz), mang âm sắc sáng rõ ở quãng tám trên.'
        ),
        (
          'f5',
          'F5',
          'Fa cao (F5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Fa cao (F5) nằm trên dòng kẻ thứ 5 (trên cùng) của Khóa Sol.'
              : 'Nốt Fa quãng 5 (F5 - 698.5 Hz), cao hơn Mi cao nửa cung.'
        ),
        (
          'g5',
          'G5',
          'Sol cao (G5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Sol cao (G5) nằm sát ngay phía trên dòng kẻ thứ 5.'
              : 'Nốt Sol quãng 5 (G5 - 784.0 Hz), nằm ở âm vực cao trong sáng.'
        ),
        (
          'a5',
          'A5',
          'La cao (A5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt La cao (A5) nằm trên 1 dòng kẻ phụ phía trên khuông nhạc Khóa Sol.'
              : 'Nốt La quãng 5 (A5 - 880.0 Hz), cao hơn La chuẩn (A4) đúng 1 quãng tám.'
        ),
        (
          'b5',
          'B5',
          'Si cao (B5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Si cao (B5) nằm ngay phía trên dòng kẻ phụ thứ 1 trên khuông Khóa Sol.'
              : 'Nốt Si quãng 5 (B5 - 987.8 Hz), dẫn lên Đô C6.'
        ),
      ];

      // Mức 4: Đa quãng tám C3–C5 đầy đủ cả tự nhiên lẫn dấu hóa (#/b)
      final level4MultiChromatic = [
        ...level3MultiNatural,
        (
          'csharp3',
          'C#3',
          'Đô# / Rêb trầm (C#3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Đô thăng trầm (C#3) nằm ở khe thứ 2 kèm dấu thăng (♯).'
              : 'Nốt Đô thăng ở quãng 3 trầm (C#3 / Db3).'
        ),
        (
          'dsharp3',
          'D#3',
          'Rê# / Mib trầm (D#3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Rê thăng trầm (D#3) nằm trên dòng kẻ thứ 3 kèm dấu thăng (♯).'
              : 'Nốt Rê thăng ở quãng 3 trầm (D#3 / Eb3).'
        ),
        (
          'fsharp3',
          'F#3',
          'Fa# / Solb trầm (F#3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Fa thăng trầm (F#3) nằm trên dòng kẻ thứ 4 kèm dấu thăng (♯).'
              : 'Nốt Fa thăng ở quãng 3 trầm (F#3 / Gb3).'
        ),
        (
          'gsharp3',
          'G#3',
          'Sol# / Lab trầm (G#3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt Sol thăng trầm (G#3) nằm ở khe thứ 4 kèm dấu thăng (♯).'
              : 'Nốt Sol thăng ở quãng 3 trầm (G#3 / Ab3).'
        ),
        (
          'asharp3',
          'A#3',
          'La# / Sib trầm (A#3)',
          isStaffReading
              ? 'Khóa Fa (𝄢): Nốt La thăng trầm (A#3) nằm trên dòng kẻ thứ 5 kèm dấu thăng (♯).'
              : 'Nốt La thăng ở quãng 3 trầm (A#3 / Bb3).'
        ),
        (
          'csharp4',
          'C#4',
          'Đô# / Rêb (C#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Đô thăng (C#4) nằm trên dòng kẻ phụ dưới kèm dấu thăng (♯).'
              : 'Nốt Đô thăng quãng 4 (C#4 / Db4).'
        ),
        (
          'dsharp4',
          'D#4',
          'Rê# / Mib (D#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Rê thăng (D#4) nằm sát dưới dòng kẻ 1 kèm dấu thăng (♯).'
              : 'Nốt Rê thăng quãng 4 (D#4 / Eb4).'
        ),
        (
          'fsharp4',
          'F#4',
          'Fa# / Solb (F#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Fa thăng (F#4) nằm ở khe thứ 1 kèm dấu thăng (♯).'
              : 'Nốt Fa thăng quãng 4 (F#4 / Gb4).'
        ),
        (
          'gsharp4',
          'G#4',
          'Sol# / Lab (G#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Sol thăng (G#4) nằm trên dòng kẻ thứ 2 kèm dấu thăng (♯).'
              : 'Nốt Sol thăng quãng 4 (G#4 / Ab4).'
        ),
        (
          'asharp4',
          'A#4',
          'La# / Sib (A#4)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt La thăng (A#4) nằm ở khe thứ 2 kèm dấu thăng (♯).'
              : 'Nốt La thăng quãng 4 (A#4 / Bb4).'
        ),
        (
          'csharp5',
          'C#5',
          'Đô# / Rêb cao (C#5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Đô thăng cao (C#5) nằm ở khe thứ 3 kèm dấu thăng (♯).'
              : 'Nốt Đô thăng ở quãng 5 cao (C#5 / Db5).'
        ),
        (
          'dsharp5',
          'D#5',
          'Rê# / Mib cao (D#5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Rê thăng cao (D#5) nằm trên dòng kẻ thứ 4 kèm dấu thăng (♯).'
              : 'Nốt Rê thăng ở quãng 5 cao (D#5 / Eb5).'
        ),
        (
          'fsharp5',
          'F#5',
          'Fa# / Solb cao (F#5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Fa thăng cao (F#5) nằm trên dòng kẻ thứ 5 kèm dấu thăng (♯).'
              : 'Nốt Fa thăng ở quãng 5 cao (F#5 / Gb5).'
        ),
        (
          'gsharp5',
          'G#5',
          'Sol# / Lab cao (G#5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt Sol thăng cao (G#5) nằm sát trên dòng kẻ 5 kèm dấu thăng (♯).'
              : 'Nốt Sol thăng ở quãng 5 cao (G#5 / Ab5).'
        ),
        (
          'asharp5',
          'A#5',
          'La# / Sib cao (A#5)',
          isStaffReading
              ? 'Khóa Sol (𝄞): Nốt La thăng cao (A#5) nằm trên dòng kẻ phụ trên kèm dấu thăng (♯).'
              : 'Nốt La thăng ở quãng 5 cao (A#5 / Bb5).'
        ),
      ];

      final noteDefs = isMaster
          ? level4MultiChromatic
          : (isAdvanced
              ? level3MultiNatural
              : (isInter ? level2C4Chromatic : level1C4Natural));

      final String promptText;
      if (isStaffReading) {
        promptText = isMaster
            ? '[Đọc nốt • Mức 4 Khóa Sol & Fa đầy đủ #/b] Nhìn vị trí nốt trên khuông nhạc và chọn tên nốt (hoặc bấm phím đàn):'
            : (isAdvanced
                ? '[Đọc nốt • Mức 3 Khóa Sol & Fa C3–C5] Quan sát Khóa nhạc (𝄞/𝄢) cùng vị trí dòng/khe để chọn đúng nốt:'
                : (isInter
                    ? '[Đọc nốt • Mức 2 Khóa Sol có dấu #/b] Quan sát nốt và dấu hóa (♯) trên khuông nhạc để chọn đáp án:'
                    : '[Đọc nốt • Mức 1 Khóa Sol C4–B4] Nhìn vị trí nốt trên 5 dòng kẻ nhạc và chọn đáp án đúng (hoặc bấm phím đàn):'));
      } else {
        promptText = isMaster
            ? '[Mức 4 • C3–C5 Đầy đủ #/b] Nghe âm thanh (không tham chiếu C4) và chọn chính xác tên nốt:'
            : (isAdvanced
                ? '[Mức 3 • C3–C5 Tự nhiên] Nghe âm thanh (có thể đối chiếu C4) và chọn đúng tên nốt + quãng tám:'
                : (isInter
                    ? '[Mức 2 • C4 có dấu #/b] Nghe nốt nhạc trong quãng 4 và chọn đáp án đúng (hoặc bấm phím đàn):'
                    : '[Mức 1 • C4 Tự nhiên] Nghe nốt nhạc trong quãng C4 và chọn đáp án đúng (hoặc bấm phím đàn):'));
      }

      // Generate 2 distractor sets for Level 1 so it has 14 rich questions, and 1 set for Levels 2..4
      final passes = diff == 1 ? 2 : 1;
      final idPrefix = isStaffReading ? 'dyn_staff' : 'dyn_note';
      final questionType = isStaffReading ? 'read_staff_note' : 'listen_note';

      for (int pass = 0; pass < passes; pass++) {
        for (int i = 0; i < noteDefs.length; i++) {
          final (fileKey, optKey, label, desc) = noteDefs[i];
          final suffix = pass == 0 ? fileKey : '${fileKey}_v2';
          final qId = '${idPrefix}_${levelId}_$suffix';
          final step1 = pass == 0 ? 1 : 2;
          final step2 = pass == 0 ? 2 : 3;
          final step3 = pass == 0 ? 4 : 5;
          final distractors = <int>{
            (i + step1) % noteDefs.length,
            (i + step2) % noteDefs.length,
            (i + step3) % noteDefs.length,
          };
          int fallbackOffset = 1;
          while (distractors.length < 3) {
            final cand = (i + fallbackOffset) % noteDefs.length;
            if (cand != i) distractors.add(cand);
            fallbackOffset++;
          }
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
              type: questionType,
              prompt: promptText,
              explanation: desc,
              audioAsset: 'assets/audio/notes/$fileKey.wav',
              difficulty: diff,
              version: 2,
              options: options,
            ),
          );
        }
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
    } else if (topicId == 'topic_chords') {
      final isAdvanced = levelId.contains('adv');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);

      final basicChords = [
        (
          'chord_c_maj',
          'C_maj',
          'Đô Trưởng (C Major)',
          'Hợp âm 3 Trưởng (C – E – G): Quãng 3 trưởng ở dưới + quãng 3 thứ ở trên, âm hưởng tươi sáng vững chãi.'
        ),
        (
          'chord_a_min',
          'A_min',
          'La Thứ (A Minor)',
          'Hợp âm 3 Thứ (A – C – E): Quãng 3 thứ ở dưới + quãng 3 trưởng ở trên, âm hưởng mềm mại trầm lắng.'
        ),
        (
          'chord_c_min',
          'C_min',
          'Đô Thứ (C Minor)',
          'Hợp âm Đô Thứ (C – Eb – G): Hạ bậc III nửa cung từ Mi xuống Mi giáng tạo màu sắc Thứ rõ rệt.'
        ),
        (
          'chord_f_maj',
          'F_maj',
          'Fa Trưởng (F Major)',
          'Hợp âm Fa Trưởng (F – A – C): Bậc IV ấm áp và mở rộng trong giọng Đô Trưởng.'
        ),
        (
          'chord_d_min',
          'D_min',
          'Rê Thứ (D Minor)',
          'Hợp âm Rê Thứ (D – F – A): Hợp âm 3 Thứ bậc II mang màu sắc sâu lắng.'
        ),
        (
          'chord_g_maj',
          'G_maj',
          'Sol Trưởng (G Major)',
          'Hợp âm Sol Trưởng (G – B – D): Bậc V sáng rõ và giàu năng lượng.'
        ),
      ];

      final interChords = [
        ...basicChords,
        (
          'chord_c_dim',
          'C_dim',
          'Hợp âm Giảm (Cdim – C°)',
          'Hợp âm 3 Giảm (C – Eb – Gb): Chồng 2 quãng 3 thứ liên tiếp (có quãng 5 giảm), tạo cảm giác kịch tính cần giải quyết.'
        ),
        (
          'chord_c_aug',
          'C_aug',
          'Hợp âm Tăng (Caug – C+)',
          'Hợp âm 3 Tăng (C – E – G#): Chồng 2 quãng 3 trưởng liên tiếp (quãng 5 tăng), mang màu sắc lơ lửng huyền ảo.'
        ),
      ];

      final advChords = [
        ...interChords,
        (
          'chord_c_sus4',
          'C_sus4',
          'Hợp âm Treo (Csus4)',
          'Hợp âm Treo bậc 4 (C – F – G): Thay bậc 3 bằng bậc 4 đúng tạo cảm giác chờ đợi hút về hợp âm Trưởng.'
        ),
        (
          'chord_c_maj7',
          'C_maj7',
          'Hợp âm Bảy Trưởng (Cmaj7)',
          'Hợp âm Bảy Trưởng (C – E – G – B): Hợp âm 3 Trưởng cộng thêm quãng 7 trưởng, màu sắc Jazz/Ballad sang trọng.'
        ),
        (
          'chord_a_min7',
          'A_min7',
          'Hợp âm Bảy Thứ (Am7)',
          'Hợp âm Bảy Thứ (A – C – E – G): Hợp âm 3 Thứ cộng quãng 7 thứ êm dịu, rất phổ biến trong nhạc Pop & R&B.'
        ),
        (
          'chord_g_dom7',
          'G_dom7',
          'Hợp âm Bảy Át (G7 – Dominant 7)',
          'Hợp âm Bảy Át (G – B – D – F): Hợp âm 3 Trưởng cộng quãng 7 thứ (chứa quãng Tritone B–F), hút mạnh về chủ âm Đô.'
        ),
      ];

      final chordPool =
          isAdvanced ? advChords : (isInter ? interChords : basicChords);
      final passes = chordPool.length < 10 ? 2 : 1;

      for (int pass = 0; pass < passes; pass++) {
        for (int i = 0; i < chordPool.length; i++) {
          final (fileKey, optKey, label, desc) = chordPool[i];
          final suffix = pass == 0 ? fileKey : '${fileKey}_v2';
          final qId = 'dyn_chd_${levelId}_$suffix';
          final step1 = pass == 0 ? 1 : 2;
          final step2 = pass == 0 ? 2 : 3;
          final step3 = pass == 0 ? 3 : 4;
          final distractors = <int>{
            (i + step1) % chordPool.length,
            (i + step2) % chordPool.length,
            (i + step3) % chordPool.length,
          };
          int fb = 1;
          while (distractors.length < 3) {
            final cand = (i + fb) % chordPool.length;
            if (cand != i) distractors.add(cand);
            fb++;
          }
          final allIdx = [i, ...distractors]..sort();

          final options = <QuestionOptionModel>[
            for (int idx = 0; idx < allIdx.length; idx++)
              QuestionOptionModel(
                id: '${qId}_o${idx + 1}',
                questionId: qId,
                optionKey: chordPool[allIdx[idx]].$2,
                label: chordPool[allIdx[idx]].$3,
                isCorrect: allIdx[idx] == i,
                sortOrder: idx + 1,
              ),
          ];

          generated.add(
            QuestionModel(
              id: qId,
              topicId: topicId,
              levelId: levelId,
              type: 'chord_quality',
              prompt: isAdvanced
                  ? '[Hợp âm Nâng cao] Nghe các nốt rải & hợp âm vang lên để nhận diện Hợp âm 7 / Sus4:'
                  : (isInter
                      ? '[Hợp âm Trung bình] Nghe màu sắc hòa thanh và phân biệt Trưởng, Thứ, Tăng, Giảm:'
                      : '[Hợp âm Cơ bản] Nghe hợp âm rải + hòa âm và chọn đúng tên hợp âm Trưởng / Thứ:'),
              explanation: desc,
              audioAsset: 'assets/audio/keys/$fileKey.wav',
              difficulty: diff,
              version: 1,
              options: options,
            ),
          );
        }
      }
    } else if (topicId == 'topic_melody') {
      final isAdvanced = levelId.contains('adv');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);

      final basicMelodies = [
        (
          'mel_c_d_e',
          'C_D_E',
          'Đô – Rê – Mi (C4 → D4 → E4)',
          'Ba nốt đi lên liền bậc khởi đầu từ Đô chuẩn (C4 – D4 – E4).'
        ),
        (
          'mel_e_d_c',
          'E_D_C',
          'Mi – Rê – Đô (E4 → D4 → C4)',
          'Ba nốt đi xuống liền bậc kết thúc vững chãi về chủ âm Đô (E4 – D4 – C4).'
        ),
        (
          'mel_c_e_g',
          'C_E_G',
          'Đô – Mi – Sol (C4 → E4 → G4)',
          'Ba nốt đi lên rải theo hợp âm Đô Trưởng (Bậc I – III – V).'
        ),
        (
          'mel_g_e_c',
          'G_E_C',
          'Sol – Mi – Đô (G4 → E4 → C4)',
          'Ba nốt đi xuống rải hợp âm Đô Trưởng từ bậc V về bậc I (G4 – E4 – C4).'
        ),
        (
          'mel_c_f_g',
          'C_F_G',
          'Đô – Fa – Sol (C4 → F4 → G4)',
          'Bước nhảy quãng 4 đúng từ Đô lên Fa rồi tiến lên Sol (Bậc I – IV – V).'
        ),
        (
          'mel_g_a_g',
          'G_A_G',
          'Sol – La – Sol (G4 → A4 → G4)',
          'Nốt thêu lượn lên 1 cung từ Sol lên La rồi quay về Sol (G4 – A4 – G4).'
        ),
      ];

      final interMelodies = [
        ...basicMelodies,
        (
          'mel_c_d_e_g',
          'C_D_E_G',
          'Đô – Rê – Mi – Sol (C4→D4→E4→G4)',
          'Giai điệu Ngũ cung 4 nốt đi lên tươi sáng (Đô – Rê – Mi – Sol).'
        ),
        (
          'mel_g_f_e_d',
          'G_F_E_D',
          'Sol – Fa – Mi – Rê (G4→F4→E4→D4)',
          'Bốn nốt đi xuống liền bậc đều đặn từ Sol về Rê.'
        ),
        (
          'mel_e_g_a_g',
          'E_G_A_G',
          'Mi – Sol – La – Sol (E4→G4→A4→G4)',
          'Mẫu giai điệu 4 nốt mang âm hưởng dân ca mềm mại.'
        ),
      ];

      final advMelodies = [
        ...interMelodies,
        (
          'mel_c_e_g_c5',
          'C_E_G_C5',
          'Đô – Mi – Sol – Đô cao (C4→E4→G4→C5)',
          'Rải hợp âm Đô Trưởng trọn vẹn 1 quãng tám từ C4 lên C5.'
        ),
        (
          'mel_a3_c4_e4_a4',
          'A3_C4_E4_A4',
          'La trầm – Đô – Mi – La (A3→C4→E4→A4)',
          'Rải hợp âm La Thứ trọn 1 quãng tám từ La trầm (A3) lên La chuẩn (A4).'
        ),
        (
          'mel_d_f_a_g',
          'D_F_A_G',
          'Rê – Fa – La – Sol (D4→F4→A4→G4)',
          'Giai điệu rải hợp âm Rê Thứ (D–F–A) rồi giải quyết về Sol (G4).'
        ),
      ];

      final melPool =
          isAdvanced ? advMelodies : (isInter ? interMelodies : basicMelodies);
      final passes = melPool.length < 10 ? 2 : 1;

      for (int pass = 0; pass < passes; pass++) {
        for (int i = 0; i < melPool.length; i++) {
          final (fileKey, optKey, label, desc) = melPool[i];
          final suffix = pass == 0 ? fileKey : '${fileKey}_v2';
          final qId = 'dyn_mel_${levelId}_$suffix';
          final step1 = pass == 0 ? 1 : 2;
          final step2 = pass == 0 ? 2 : 3;
          final step3 = pass == 0 ? 3 : 4;
          final distractors = <int>{
            (i + step1) % melPool.length,
            (i + step2) % melPool.length,
            (i + step3) % melPool.length,
          };
          int fb = 1;
          while (distractors.length < 3) {
            final cand = (i + fb) % melPool.length;
            if (cand != i) distractors.add(cand);
            fb++;
          }
          final allIdx = [i, ...distractors]..sort();

          final options = <QuestionOptionModel>[
            for (int idx = 0; idx < allIdx.length; idx++)
              QuestionOptionModel(
                id: '${qId}_o${idx + 1}',
                questionId: qId,
                optionKey: melPool[allIdx[idx]].$2,
                label: melPool[allIdx[idx]].$3,
                isCorrect: allIdx[idx] == i,
                sortOrder: idx + 1,
              ),
          ];

          generated.add(
            QuestionModel(
              id: qId,
              topicId: topicId,
              levelId: levelId,
              type: 'melody_dictation',
              prompt: isAdvanced
                  ? '[Giai điệu Nâng cao] Nghe nét nhạc 4 nốt (nhảy quãng / rải hợp âm) và chọn chuỗi nốt đúng:'
                  : (isInter
                      ? '[Giai điệu Trung bình] Nghe chuỗi 3–4 nốt nhạc và chọn đúng thứ tự cao độ:'
                      : '[Giai điệu Cơ bản] Nghe nét giai điệu 3 nốt ngắn và chọn đúng thứ tự các nốt:'),
              explanation: desc,
              audioAsset: 'assets/audio/keys/$fileKey.wav',
              difficulty: diff,
              version: 1,
              options: options,
            ),
          );
        }
      }
    } else if (topicId == 'topic_rhythm') {
      final isAdvanced = levelId.contains('adv');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);

      final basicRhythms = [
        (
          'rhy_quarter_4_4',
          'Q4',
          '4 nốt Đen đều (♩ ♩ ♩ ♩)',
          'Bốn phách nốt Đen đều đặn trong ô nhịp 4/4, phách 1 có trọng âm mạnh.'
        ),
        (
          'rhy_half_notes',
          'H2',
          '2 nốt Trắng ngân dài (𝅗𝅥  𝅗𝅥)',
          'Hai nốt Trắng, mỗi nốt ngân dài đúng 2 phách (vang lên ở phách 1 và phách 3).'
        ),
        (
          'rhy_eighth_pair',
          'E8',
          'Chùm Móc đơn đôi đều (♪♪ ♪♪ ♪♪ ♪♪)',
          'Mỗi phách chia đôi đều thành 2 nốt Móc đơn (tổng cộng 8 tiếng trong 1 ô nhịp 4/4).'
        ),
        (
          'rhy_quarter_eighth',
          'QE',
          'Đen – Đôi móc đơn (♩  ♪♪  ♩  ♪♪)',
          'Phách 1 & 3 là nốt Đen; phách 2 & 4 chia đôi thành cặp nốt Móc đơn.'
        ),
        (
          'rhy_march_2_4',
          'M24',
          'Nhịp 2/4 Hành khúc (Mạnh – Nhẹ)',
          'Chu kỳ 2 phách (Mạnh – Nhẹ | Mạnh – Nhẹ) dứt khoát đặc trưng của nhịp 2/4.'
        ),
        (
          'rhy_waltz_3_4',
          'W34',
          'Nhịp 3/4 Waltz (Mạnh – Nhẹ – Nhẹ)',
          'Chu kỳ 3 phách nhịp nhàng (Bùm – Chát – Chát) đặc trưng của điệu Valse 3/4.'
        ),
      ];

      final interRhythms = [
        ...basicRhythms,
        (
          'rhy_triplet',
          'TRIP',
          'Chùm ba Liên 3 (♪♪♪  ♪♪♪)',
          'Mỗi phách được chia đều thành 3 nốt (Liên ba - Triplet) tạo cảm giác xoay tròn mềm mại.'
        ),
        (
          'rhy_sixteenth',
          'SIX16',
          'Chùm bốn Móc kép nhanh (♬ ♬ ♩ ♩)',
          'Hai phách đầu chia nhỏ thành 4 nốt Móc kép nhanh gấp đôi móc đơn, hai phách sau là nốt Đen.'
        ),
        (
          'rhy_dotted_eighth',
          'DOT8',
          'Móc đơn chấm dôi + Móc kép (♪.  sixteenth)',
          'Nốt đầu ngân 3/4 phách kèm nốt móc kép bật nhanh cuối phách, tạo độ nảy khỏe khoắn.'
        ),
      ];

      final advRhythms = [
        ...interRhythms,
        (
          'rhy_syncopated',
          'SYNC',
          'Tiết tấu Đảo phách (Syncopation ♪ ♩ ♪)',
          'Trọng âm rơi vào nửa sau của phách 1 và ngân qua đầu phách 2 (Đảo phách - Syncopation).'
        ),
        (
          'rhy_gallop',
          'GAL',
          'Tiết tấu Phi ngựa (♪ ♬ – Móc đơn + 2 Móc kép)',
          'Nửa đầu phách là 1 nốt móc đơn, nửa sau là 2 nốt móc kép liên tiếp gợi nhịp vó ngựa.'
        ),
        (
          'rhy_compound_6_8',
          'C68',
          'Nhịp Kép 6/8 (2 trọng âm chùm 3)',
          'Ô nhịp gồm 6 móc đơn chia thành 2 cụm 3 (nhấn mạnh ở nốt 1 và nốt 4).'
        ),
      ];

      final rhyPool =
          isAdvanced ? advRhythms : (isInter ? interRhythms : basicRhythms);
      final passes = rhyPool.length < 10 ? 2 : 1;

      for (int pass = 0; pass < passes; pass++) {
        for (int i = 0; i < rhyPool.length; i++) {
          final (fileKey, optKey, label, desc) = rhyPool[i];
          final suffix = pass == 0 ? fileKey : '${fileKey}_v2';
          final qId = 'dyn_rhy_${levelId}_$suffix';
          final step1 = pass == 0 ? 1 : 2;
          final step2 = pass == 0 ? 2 : 3;
          final step3 = pass == 0 ? 3 : 4;
          final distractors = <int>{
            (i + step1) % rhyPool.length,
            (i + step2) % rhyPool.length,
            (i + step3) % rhyPool.length,
          };
          int fb = 1;
          while (distractors.length < 3) {
            final cand = (i + fb) % rhyPool.length;
            if (cand != i) distractors.add(cand);
            fb++;
          }
          final allIdx = [i, ...distractors]..sort();

          final options = <QuestionOptionModel>[
            for (int idx = 0; idx < allIdx.length; idx++)
              QuestionOptionModel(
                id: '${qId}_o${idx + 1}',
                questionId: qId,
                optionKey: rhyPool[allIdx[idx]].$2,
                label: rhyPool[allIdx[idx]].$3,
                isCorrect: allIdx[idx] == i,
                sortOrder: idx + 1,
              ),
          ];

          generated.add(
            QuestionModel(
              id: qId,
              topicId: topicId,
              levelId: levelId,
              type: 'rhythm_pattern',
              prompt: isAdvanced
                  ? '[Nhịp điệu Nâng cao] Nghe mẫu tiết tấu và nhận diện Đảo phách / Phi ngựa / Nhịp 6/8:'
                  : (isInter
                      ? '[Nhịp điệu Trung bình] Nghe tiết tấu và phân biệt Liên 3, Móc kép, Móc đơn chấm dôi:'
                      : '[Nhịp điệu Cơ bản] Nghe mẫu gõ tiết tấu và chọn đúng hình nốt / loại nhịp:'),
              explanation: desc,
              audioAsset: 'assets/audio/keys/$fileKey.wav',
              difficulty: diff,
              version: 1,
              options: options,
            ),
          );
        }
      }
    }

    for (final q in generated) {
      await _db.upsertQuestion(q);
    }
  }
}

