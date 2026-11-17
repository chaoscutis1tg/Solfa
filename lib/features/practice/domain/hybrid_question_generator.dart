import 'dart:math';

import '../../../core/audio/asset_validator.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/utils/note_formatter.dart';
import '../presentation/widgets/musical_staff_widget.dart';

class HybridQuestionGenerator {
  static const int _currentGeneratorVersion = 6;
  static final Random _entropySource = Random();

  final AppDatabase _db;
  final AssetValidator _assetValidator;

  HybridQuestionGenerator(this._db, this._assetValidator);

  /// Generates a session question set for 'quick', 'topic', or 'review' mode.
  /// Supports deterministic [seed] for reproducible unit testing (Section 11.3),
  /// and high-entropy Concept-Stratified Bag Sampling + Dynamic Option Shuffling in live play.
  Future<({String topicId, String? levelId, List<QuestionModel> questions})>
      generateSessionQuestions({
    required String mode, // 'quick', 'topic', 'review'
    String? topicId,
    String? levelId,
    int targetCount = 10,
    int? seed,
    String? excludeAudioAsset,
    String? excludeOptionKey,
    bool ledgerOnly = false,
  }) async {
    final rng = seed != null
        ? Random(seed)
        : Random(
            DateTime.now().microsecondsSinceEpoch ^
                _entropySource.nextInt(0x7FFFFFFF),
          );

    if (mode == 'review') {
      final pending = await _db.getPendingReviewItems(topicId: topicId);
      final List<QuestionModel> validReviewQuestions = [];
      for (final item in pending) {
        final q = item.question;
        if (q != null && await _assetValidator.exists(q.audioAsset)) {
          validReviewQuestions.add(_shuffleExistingOptions(q, rng));
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
      resolvedTopicId = 'topic_notes';
      resolvedLevelId = levelId ?? 'lvl_notes_basic';
    } else if (levelId == null) {
      if (resolvedTopicId.startsWith('topic_guitar_')) {
        resolvedLevelId =
            '${resolvedTopicId.replaceFirst('topic_', 'lvl_')}_basic';
      } else {
        final levels = await _db.getLevelsByTopic(resolvedTopicId);
        resolvedLevelId =
            levels.isNotEmpty ? levels.first.id : 'lvl_notes_basic';
      }
    }

    // 1. Ensure dynamic hybrid pool is populated & up-to-date for this topic & level
    await _ensureDynamicQuestionsPersisted(
      topicId: resolvedTopicId,
      levelId: resolvedLevelId,
    );

    // 2. Load candidate questions from SQLite for the exact level
    List<QuestionModel> candidates = await _db.getQuestions(
      topicId: resolvedTopicId,
      levelId: resolvedLevelId,
    );

    // Filter out any legacy compare_pitch questions and enforce strict level-scope rules
    candidates = candidates
        .where((q) => _isQuestionValidForLevelScope(
              q,
              topicId: resolvedTopicId,
              levelId: resolvedLevelId,
            ))
        .toList();

    // Optional Ledger-Lines-Only filter for "Đọc nốt nhạc" (Chuyên luyện Dòng kẻ phụ)
    if (ledgerOnly && resolvedTopicId == 'topic_staff_reading') {
      final ledgerFiltered = candidates
          .where(
            (q) => MusicalStaffWidget.isLedgerLineNoteKey(
              q.correctOption.optionKey,
            ),
          )
          .toList();
      if (ledgerFiltered.isNotEmpty) {
        candidates = ledgerFiltered;
      }
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
    final List<QuestionModel> rawValidCandidates = [];
    for (final q in candidates) {
      final hasAudio = await _assetValidator.exists(q.audioAsset);
      final labels = q.options.map((o) => o.label).toSet();
      final correctCount = q.options.where((o) => o.isCorrect).length;
      if (hasAudio &&
          q.options.length >= 2 &&
          labels.length == q.options.length &&
          correctCount == 1) {
        rawValidCandidates.add(q);
      }
    }

    if (rawValidCandidates.isEmpty) {
      return (
        topicId: resolvedTopicId,
        levelId: resolvedLevelId,
        questions: <QuestionModel>[],
      );
    }

    // 4. Prefer canonical dynamic ('dyn_') questions when static seed questions duplicate
    // the exact same (type, audioAsset) so no note/interval/key gets double-weighted.
    final Set<String> dynamicTypeAudioKeys = rawValidCandidates
        .where((q) => q.id.startsWith('dyn_'))
        .map((q) => '${q.type}::${q.audioAsset}')
        .toSet();

    final List<QuestionModel> validCandidates = rawValidCandidates.where((q) {
      if (q.id.startsWith('dyn_')) return true;
      return !dynamicTypeAudioKeys.contains('${q.type}::${q.audioAsset}');
    }).toList();

    // 5. Build canonical option pools per question type in this level for fresh distractor sampling
    final Map<String, List<(String optionKey, String label)>> optionPoolByType =
        {};
    for (final q in validCandidates) {
      final list = optionPoolByType.putIfAbsent(q.type, () => []);
      for (final opt in q.options) {
        final normKey = opt.optionKey.toUpperCase();
        if (!list.any((e) => e.$1.toUpperCase() == normKey || e.$2 == opt.label)) {
          list.add((opt.optionKey, opt.label));
        }
      }
    }

    // 6. Group validCandidates by target concept so every note/interval/key/chord/melody/rhythm
    // in the level has 100% uniform probability and never repeats back-to-back.
    final Map<String, List<QuestionModel>> variantsByConcept = {};
    for (final q in validCandidates) {
      final cKey = _conceptGroupKey(q);
      variantsByConcept.putIfAbsent(cKey, () => []).add(q);
    }

    final List<String> conceptKeys = variantsByConcept.keys.toList();
    for (final list in variantsByConcept.values) {
      list.shuffle(rng);
    }
    final Map<String, int> variantCursor = {
      for (final k in conceptKeys) k: 0,
    };

    final List<QuestionModel> selected = [];
    final int windowSize = min(3, max(1, conceptKeys.length - 1));

    while (selected.length < targetCount) {
      final List<String> bag = [...conceptKeys]..shuffle(rng);

      while (bag.isNotEmpty && selected.length < targetCount) {
        final String? prevAudio = selected.isNotEmpty
            ? selected.last.audioAsset
            : excludeAudioAsset;
        final String? prevOptKey = selected.isNotEmpty
            ? selected.last.correctOption.optionKey.toUpperCase()
            : excludeOptionKey?.toUpperCase();

        // Recent concept keys in sliding window
        final Set<String> recentConceptKeys = {};
        for (int w = 1; w <= windowSize && selected.length - w >= 0; w++) {
          recentConceptKeys.add(_conceptGroupKey(selected[selected.length - w]));
        }

        // Check if last 2 binary questions had the same optionKey (e.g. 'major', 'major')
        String? forbiddenBinaryStreakKey;
        if (selected.length >= 2) {
          final k1 =
              selected[selected.length - 1].correctOption.optionKey.toUpperCase();
          final k2 =
              selected[selected.length - 2].correctOption.optionKey.toUpperCase();
          if (k1 == k2) {
            forbiddenBinaryStreakKey = k1;
          }
        }

        int chosenBagIdx = -1;

        // Pass 1: Strict sliding-window anti-repeat (no repeat in last windowSize questions,
        // no same audioAsset, no same optionKey as immediate predecessor, no 3-in-a-row binary key)
        for (int i = 0; i < bag.length; i++) {
          final cKey = bag[i];
          if (recentConceptKeys.contains(cKey)) continue;
          final variants = variantsByConcept[cKey]!;
          final cand = variants[variantCursor[cKey]! % variants.length];
          final candOptKey = cand.correctOption.optionKey.toUpperCase();

          if (prevAudio != null &&
              conceptKeys.length > 1 &&
              cand.audioAsset == prevAudio) {
            continue;
          }
          if (prevOptKey != null &&
              cand.options.length >= 4 &&
              conceptKeys.length > 2 &&
              candOptKey == prevOptKey) {
            continue;
          }
          if (forbiddenBinaryStreakKey != null &&
              cand.options.length == 2 &&
              candOptKey == forbiddenBinaryStreakKey) {
            continue;
          }
          chosenBagIdx = i;
          break;
        }

        // Pass 2: Immediate predecessor anti-repeat fallback
        if (chosenBagIdx == -1) {
          for (int i = 0; i < bag.length; i++) {
            final cKey = bag[i];
            final variants = variantsByConcept[cKey]!;
            final cand = variants[variantCursor[cKey]! % variants.length];
            final candOptKey = cand.correctOption.optionKey.toUpperCase();
            if (prevAudio != null &&
                conceptKeys.length > 1 &&
                cand.audioAsset == prevAudio) {
              continue;
            }
            if (prevOptKey != null &&
                cand.options.length >= 4 &&
                conceptKeys.length > 1 &&
                candOptKey == prevOptKey) {
              continue;
            }
            chosenBagIdx = i;
            break;
          }
        }

        if (chosenBagIdx == -1) {
          chosenBagIdx = 0;
        }

        final chosenConceptKey = bag.removeAt(chosenBagIdx);
        final variants = variantsByConcept[chosenConceptKey]!;
        final int curIdx = variantCursor[chosenConceptKey]!;
        final QuestionModel rawQuestion = variants[curIdx % variants.length];
        variantCursor[chosenConceptKey] = curIdx + 1;

        final QuestionModel randomizedQuestion = _randomizeQuestionOptions(
          rawQuestion,
          optionPoolByType[rawQuestion.type] ?? const [],
          rng,
        );
        selected.add(randomizedQuestion);
      }
    }

    return (
      topicId: resolvedTopicId,
      levelId: resolvedLevelId,
      questions: selected,
    );
  }

  /// Enforces level-specific musical constraints so out-of-scope legacy questions cannot leak in.
  bool _isQuestionValidForLevelScope(
    QuestionModel q, {
    required String topicId,
    required String levelId,
  }) {
    if (topicId == 'topic_notes' && q.type == 'compare_pitch') {
      return false;
    }
    final isMaster = levelId.contains('master') || levelId.contains('4');
    final isAdvanced = levelId.contains('adv') || levelId.contains('3');
    final isInter = levelId.contains('inter') || levelId.contains('2');

    if (topicId == 'topic_notes') {
      if (!isMaster && !isAdvanced && !isInter) {
        // Mức 1 (Basic): Chỉ 7 nốt tự nhiên trong quãng C4 (C4..B4), không dấu #/b
        return q.options.every(
          (o) => o.optionKey.endsWith('4') && !o.optionKey.contains('#'),
        );
      } else if (isInter) {
        // Mức 2 (Inter): Chỉ trong quãng C4 (C4..B4), có cả tự nhiên và dấu #/b
        return q.options.every((o) => o.optionKey.endsWith('4'));
      } else if (isAdvanced) {
        // Mức 3 (Adv): Đa quãng C3–C5 nhưng chỉ các nốt tự nhiên (không dấu #/b)
        return q.options.every((o) => !o.optionKey.contains('#'));
      }
    } else if (topicId == 'topic_staff_reading') {
      if (!isMaster && !isAdvanced && !isInter) {
        // Mức 1 (Basic): Khóa Sol tự nhiên (C4–B4) + Dòng kẻ phụ tự nhiên Khóa Sol (G3..C4, A5..C6), không dấu #/b
        return q.options.every(
          (o) =>
              !o.optionKey.contains('#') &&
              !o.optionKey.toUpperCase().endsWith('_FA'),
        );
      } else if (isInter) {
        // Mức 2 (Inter): Khóa Sol có cả tự nhiên và dấu #/b + Dòng kẻ phụ Khóa Sol
        return q.options.every(
          (o) => !o.optionKey.toUpperCase().endsWith('_FA'),
        );
      } else if (isAdvanced) {
        // Mức 3 (Adv): Khóa Sol & Khóa Fa tự nhiên (không dấu #/b) + Dòng kẻ phụ 2 khóa
        return q.options.every((o) => !o.optionKey.contains('#'));
      }
    }
    return true;
  }

  /// Computes the concept key used to stratify questions evenly across the level.
  String _conceptGroupKey(QuestionModel q) {
    if (q.options.length <= 2) {
      // Binary questions (e.g. Major vs Minor key_quality): stratify by audio file
      return '${q.type}::${q.audioAsset}';
    }
    return '${q.type}::${q.correctOption.optionKey.toUpperCase()}';
  }

  /// Shuffles only the option order (preserving original options) and updates sortOrder 1..N.
  QuestionModel _shuffleExistingOptions(QuestionModel q, Random rng) {
    final shuffled = [...q.options]..shuffle(rng);
    final updatedOptions = <QuestionOptionModel>[
      for (int i = 0; i < shuffled.length; i++)
        QuestionOptionModel(
          id: shuffled[i].id,
          questionId: shuffled[i].questionId,
          optionKey: shuffled[i].optionKey,
          label: shuffled[i].label,
          isCorrect: shuffled[i].isCorrect,
          sortOrder: i + 1,
        ),
    ];
    return QuestionModel(
      id: q.id,
      topicId: q.topicId,
      levelId: q.levelId,
      type: q.type,
      prompt: q.prompt
          .replaceAll(' (hoặc bấm trực tiếp phím đàn)', '')
          .replaceAll(' (hoặc bấm phím đàn)', ''),
      explanation: q.explanation,
      audioAsset: q.audioAsset,
      difficulty: q.difficulty,
      version: q.version,
      options: updatedOptions,
    );
  }

  /// Freshly samples random wrong distractors from the level's valid option pool (for 4-option questions)
  /// AND shuffles all option positions (A/B/C/D) using Fisher-Yates so neither distractors nor
  /// the correct answer's slot can ever be memorized or predicted.
  QuestionModel _randomizeQuestionOptions(
    QuestionModel q,
    List<(String optionKey, String label)> typeOptionPool,
    Random rng,
  ) {
    final correctOpt = q.correctOption;
    final wrongSlotOpts = q.options.where((o) => !o.isCorrect).toList();

    List<QuestionOptionModel> assembledOptions;
    if (q.options.length >= 4 && wrongSlotOpts.isNotEmpty) {
      final isNoteQuestion =
          q.type == 'listen_note' || q.type == 'read_staff_note';
      final correctPitchClass = NoteFormatter.cleanNoteKey(correctOpt.optionKey)
          .replaceAll(RegExp(r'[0-9]'), '')
          .toUpperCase();

      final shuffledPool = [...typeOptionPool]..shuffle(rng);
      final List<(String optionKey, String label)> selectedWrong = [];
      final Set<String> usedPitchClasses = {correctPitchClass};

      for (final cand in shuffledPool) {
        if (cand.$1.toUpperCase() == correctOpt.optionKey.toUpperCase() ||
            cand.$2 == correctOpt.label) {
          continue;
        }
        if (isNoteQuestion) {
          final candPc = NoteFormatter.cleanNoteKey(cand.$1)
              .replaceAll(RegExp(r'[0-9]'), '')
              .toUpperCase();
          if (usedPitchClasses.contains(candPc)) continue;
          usedPitchClasses.add(candPc);
        }
        selectedWrong.add(cand);
        if (selectedWrong.length >= wrongSlotOpts.length) break;
      }

      if (selectedWrong.length >= wrongSlotOpts.length) {
        assembledOptions = [
          correctOpt,
          for (int i = 0; i < wrongSlotOpts.length; i++)
            QuestionOptionModel(
              id: wrongSlotOpts[i].id,
              questionId: q.id,
              optionKey: selectedWrong[i].$1,
              label: selectedWrong[i].$2,
              isCorrect: false,
              sortOrder: i + 2,
            ),
        ];
      } else {
        assembledOptions = [...q.options];
      }
    } else {
      assembledOptions = [...q.options];
    }

    assembledOptions.shuffle(rng);
    final finalOptions = <QuestionOptionModel>[
      for (int idx = 0; idx < assembledOptions.length; idx++)
        QuestionOptionModel(
          id: assembledOptions[idx].id,
          questionId: q.id,
          optionKey: assembledOptions[idx].optionKey,
          label: assembledOptions[idx].label,
          isCorrect: assembledOptions[idx].isCorrect,
          sortOrder: idx + 1,
        ),
    ];

    return QuestionModel(
      id: q.id,
      topicId: q.topicId,
      levelId: q.levelId,
      type: q.type,
      prompt: q.prompt
          .replaceAll(' (hoặc bấm trực tiếp phím đàn)', '')
          .replaceAll(' (hoặc bấm phím đàn)', ''),
      explanation: q.explanation,
      audioAsset: q.audioAsset,
      difficulty: q.difficulty,
      version: q.version,
      options: finalOptions,
    );
  }

  /// Dynamically synthesizes structured questions from bundled audio assets and persists them
  /// into SQLite so every question has a stable ID for answers & review_items (Decision #3).
  Future<void> _ensureDynamicQuestionsPersisted({
    required String topicId,
    required String levelId,
  }) async {
    final existing = await _db.getQuestions(topicId: topicId, levelId: levelId);
    final currentDynamicCount = existing
        .where(
            (q) => q.id.startsWith('dyn_') && q.version >= _currentGeneratorVersion)
        .length;
    if (currentDynamicCount >= 12) return;

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

      // Dòng kẻ phụ Khóa Sol tự nhiên (1–2 dòng phụ dưới & trên: G3, A3, B3, A5, B5, C6)
      const trebleLedgerNatural = [
        (
          'g3',
          'G3_SOL',
          'Sol trầm (G3)',
          'Khóa Sol • Dưới dòng phụ 2: Nốt Sol trầm (G3) nằm sát dưới dòng kẻ phụ thứ 2 bên dưới khuông nhạc (đếm từ Đô C4 xuống: C4 [phụ 1] → B3 → A3 [phụ 2] → G3).'
        ),
        (
          'a3',
          'A3_SOL',
          'La trầm (A3)',
          'Khóa Sol • Dòng kẻ phụ 2 dưới: Nốt La trầm (A3) nằm chính giữa dòng kẻ phụ thứ 2 bên dưới khuông nhạc (thấp hơn Đô C4 một quãng 3 thứ).'
        ),
        (
          'b3',
          'B3_SOL',
          'Si trầm (B3)',
          'Khóa Sol • Dưới dòng phụ 1: Nốt Si trầm (B3) nằm sát ngay dưới dòng kẻ phụ thứ 1 (ngay dưới nốt Đô trung C4).'
        ),
        (
          'a5',
          'A5',
          'La cao (A5)',
          'Khóa Sol • Dòng kẻ phụ 1 trên: Nốt La cao (A5) nằm chính giữa dòng kẻ phụ thứ 1 phía trên dòng kẻ thứ 5.'
        ),
        (
          'b5',
          'B5',
          'Si cao (B5)',
          'Khóa Sol • Trên dòng phụ 1: Nốt Si cao (B5) nằm sát ngay phía trên dòng kẻ phụ thứ 1 phía trên khuông nhạc.'
        ),
        (
          'c6',
          'C6',
          'Đô rất cao (C6)',
          'Khóa Sol • Dòng kẻ phụ 2 trên: Nốt Đô rất cao (C6) nằm chính giữa dòng kẻ phụ thứ 2 phía trên khuông nhạc (đếm từ Fa F5 [dòng 5] lên: G5 → A5 [phụ 1] → B5 → C6 [phụ 2]).'
        ),
      ];

      // Dòng kẻ phụ Khóa Sol có dấu hóa (#/b)
      const trebleLedgerChromatic = [
        (
          'gsharp3',
          'G#3_SOL',
          'Sol# / Lab trầm (G#3)',
          'Khóa Sol • Dưới dòng phụ 2: Nốt Sol thăng trầm (G#3) nằm sát dưới dòng kẻ phụ thứ 2 bên dưới kèm dấu thăng (♯).'
        ),
        (
          'asharp3',
          'A#3_SOL',
          'La# / Sib trầm (A#3)',
          'Khóa Sol • Dòng kẻ phụ 2 dưới: Nốt La thăng trầm (A#3) nằm trên dòng kẻ phụ thứ 2 bên dưới kèm dấu thăng (♯).'
        ),
        (
          'asharp5',
          'A#5',
          'La# / Sib cao (A#5)',
          'Khóa Sol • Dòng kẻ phụ 1 trên: Nốt La thăng cao (A#5) nằm trên dòng kẻ phụ thứ 1 phía trên kèm dấu thăng (♯).'
        ),
      ];

      // Dòng kẻ phụ trên của Khóa Fa (C4, D4, C#4)
      const bassLedgerNatural = [
        (
          'c4',
          'C4_FA',
          'Đô trung (C4 • Khóa Fa)',
          'Khóa Fa • Dòng kẻ phụ 1 trên: Nốt Đô trung (C4) nằm chính giữa dòng kẻ phụ thứ 1 phía trên dòng kẻ thứ 5 (nốt La A3) của Khóa Fa.'
        ),
        (
          'd4',
          'D4_FA',
          'Rê trung (D4 • Khóa Fa)',
          'Khóa Fa • Trên dòng phụ 1: Nốt Rê trung (D4) nằm sát ngay phía trên dòng kẻ phụ thứ 1 phía trên khuông nhạc Khóa Fa.'
        ),
      ];

      const bassLedgerChromatic = [
        (
          'csharp4',
          'C#4_FA',
          'Đô# / Rêb (C#4 • Khóa Fa)',
          'Khóa Fa • Dòng kẻ phụ 1 trên: Nốt Đô thăng (C#4) nằm trên dòng kẻ phụ thứ 1 phía trên Khóa Fa kèm dấu thăng (♯).'
        ),
      ];

      final List<(String, String, String, String)> noteDefs;
      if (isStaffReading) {
        if (isMaster) {
          noteDefs = [
            ...level4MultiChromatic,
            ...trebleLedgerNatural
                .where((n) => n.$2.endsWith('_SOL') || n.$2 == 'C6'),
            ...trebleLedgerChromatic
                .where((n) => n.$2.endsWith('_SOL')),
            ...bassLedgerNatural,
            ...bassLedgerChromatic,
          ];
        } else if (isAdvanced) {
          noteDefs = [
            ...level3MultiNatural,
            ...trebleLedgerNatural
                .where((n) => n.$2.endsWith('_SOL') || n.$2 == 'C6'),
            ...bassLedgerNatural,
          ];
        } else if (isInter) {
          noteDefs = [
            ...level2C4Chromatic,
            ...trebleLedgerNatural,
            ...trebleLedgerChromatic,
          ];
        } else {
          noteDefs = [
            ...level1C4Natural,
            ...trebleLedgerNatural,
          ];
        }
      } else {
        noteDefs = isMaster
            ? level4MultiChromatic
            : (isAdvanced
                ? level3MultiNatural
                : (isInter ? level2C4Chromatic : level1C4Natural));
      }

      final String promptText;
      if (isStaffReading) {
        promptText = isMaster
            ? '[Đọc nốt • Mức 4 Khóa Sol & Fa + Dòng kẻ phụ #/b] Nhìn vị trí nốt trên khuông nhạc / dòng kẻ phụ và chọn tên nốt:'
            : (isAdvanced
                ? '[Đọc nốt • Mức 3 Khóa Sol & Fa + Dòng kẻ phụ] Quan sát Khóa nhạc cùng vị trí dòng/khe hoặc dòng kẻ phụ để chọn đúng nốt:'
                : (isInter
                    ? '[Đọc nốt • Mức 2 Khóa Sol + Dòng kẻ phụ & #/b] Quan sát nốt, dòng kẻ phụ và dấu hóa (♯) trên khuông nhạc để chọn đáp án:'
                    : '[Đọc nốt • Mức 1 Khóa Sol + Dòng kẻ phụ] Nhìn vị trí nốt trên 5 dòng kẻ nhạc và dòng kẻ phụ (G3–C6) để chọn đáp án đúng:'));
      } else {
        promptText = isMaster
            ? '[Mức 4 • C3–C5 Đầy đủ #/b] Nghe âm thanh (không tham chiếu C4) và chọn chính xác tên nốt:'
            : (isAdvanced
                ? '[Mức 3 • C3–C5 Tự nhiên] Nghe âm thanh (có thể đối chiếu C4) và chọn đúng tên nốt + quãng tám:'
                : (isInter
                    ? '[Mức 2 • C4 có dấu #/b] Nghe nốt nhạc trong quãng 4 và chọn đáp án đúng:'
                    : '[Mức 1 • C4 Tự nhiên] Nghe nốt nhạc trong quãng C4 và chọn đáp án đúng:'));
      }

      final passes = noteDefs.length < 10 ? 2 : 1;
      final idPrefix = isStaffReading ? 'dyn_staff' : 'dyn_note';
      final questionType = isStaffReading ? 'read_staff_note' : 'listen_note';

      for (int pass = 0; pass < passes; pass++) {
        for (int i = 0; i < noteDefs.length; i++) {
          final (fileKey, optKey, label, desc) = noteDefs[i];
          final idSlug = optKey.toLowerCase().replaceAll('#', 'sharp');
          final suffix = pass == 0 ? idSlug : '${idSlug}_v2';
          final qId = '${idPrefix}_${levelId}_$suffix';
          final step1 = pass == 0 ? 1 : 2;
          final step2 = pass == 0 ? 2 : 3;
          final step3 = pass == 0 ? 4 : 5;
          final distractors = <int>[];
          final usedLabels = <String>{label};

          for (final rawStep in [step1, step2, step3]) {
            final cand = (i + rawStep) % noteDefs.length;
            if (cand != i && !usedLabels.contains(noteDefs[cand].$3)) {
              distractors.add(cand);
              usedLabels.add(noteDefs[cand].$3);
            }
          }
          int fallbackOffset = 1;
          while (distractors.length < 3 && fallbackOffset <= noteDefs.length) {
            final cand = (i + fallbackOffset) % noteDefs.length;
            if (cand != i && !usedLabels.contains(noteDefs[cand].$3)) {
              distractors.add(cand);
              usedLabels.add(noteDefs[cand].$3);
            }
            fallbackOffset++;
          }
          final allIndices = [i, ...distractors];

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
              version: _currentGeneratorVersion,
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

      // Canonical (fileCode, optionKey, label, description)
      final intervalDefs = [
        (
          'maj2',
          'M2',
          'Quãng 2 trưởng',
          'Cách nhau 1 cung nguyên (2 nửa cung).'
        ),
        (
          'min3',
          'm3',
          'Quãng 3 thứ',
          'Cách nhau 1,5 cung (3 nửa cung), âm hưởng mềm mại trầm lắng.'
        ),
        (
          'maj3',
          'M3',
          'Quãng 3 trưởng',
          'Cách nhau 2 cung (4 nửa cung), âm hưởng tươi sáng rõ ràng.'
        ),
        (
          'p4',
          'P4',
          'Quãng 4 đúng',
          'Cách nhau 2,5 cung (5 nửa cung), âm hưởng mở đầu vững vàng.'
        ),
        (
          'p5',
          'P5',
          'Quãng 5 đúng',
          'Cách nhau 3,5 cung (7 nửa cung), độ hòa hợp rất vững chãi.'
        ),
        (
          'maj6',
          'M6',
          'Quãng 6 trưởng',
          'Cách nhau 4,5 cung (9 nửa cung), âm hưởng rộng mở ấm áp.'
        ),
        (
          'p8',
          'P8',
          'Quãng 8 đúng (Octave)',
          'Cách nhau 6 cung (12 nửa cung), lặp lại tên nốt ở quãng tám mới.'
        ),
        if (isInter || isAdvanced)
          (
            'min2',
            'm2',
            'Quãng 2 thứ',
            'Cách nhau nửa cung (1 bán âm), tạo cảm giác sát gần kịch tính.'
          ),
        if (isInter || isAdvanced)
          (
            'min6',
            'm6',
            'Quãng 6 thứ',
            'Cách nhau 4 cung (8 nửa cung), mang màu sắc trữ tình sâu lắng.'
          ),
        if (isAdvanced)
          (
            'tritone',
            'tritone',
            'Quãng 4 tăng / 5 giảm (Tritone)',
            'Cách nhau 3 cung nguyên (6 nửa cung), có độ căng hòa thanh mạnh.'
          ),
        if (isAdvanced)
          (
            'min7',
            'm7',
            'Quãng 7 thứ',
            'Cách nhau 5 cung (10 nửa cung), đặc trưng của hợp âm Bảy Át (Dominant 7).'
          ),
        if (isAdvanced)
          (
            'maj7',
            'M7',
            'Quãng 7 trưởng',
            'Cách nhau 5,5 cung (11 nửa cung), âm hưởng sắc nét hiện đại.'
          ),
      ];

      final roots = isAdvanced
          ? const [('c4', 'Đô C4'), ('g4', 'Sol G4')]
          : const [('c4', 'Đô C4'), ('f4', 'Fa F4'), ('g4', 'Sol G4')];

      for (final (rootCode, rootLabel) in roots) {
        for (int i = 0; i < intervalDefs.length; i++) {
          final (fileCode, optKey, label, desc) = intervalDefs[i];
          final qId = 'dyn_int_${levelId}_${rootCode}_${fileCode}_$modeSuffix';
          final distractors = <int>{
            (i + 1) % intervalDefs.length,
            (i + 2) % intervalDefs.length,
            (i + 4) % intervalDefs.length,
          };
          int fb = 1;
          while (distractors.length < 3) {
            final cand = (i + fb) % intervalDefs.length;
            if (cand != i) distractors.add(cand);
            fb++;
          }
          final allIndices = [i, ...distractors];

          final options = <QuestionOptionModel>[];
          for (int idx = 0; idx < allIndices.length; idx++) {
            final d = intervalDefs[allIndices[idx]];
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
              type: isAdvanced ? 'interval_harmonic' : 'interval_melodic',
              prompt: isAdvanced
                  ? 'Nghe hai nốt phát đồng thời (khởi từ $rootLabel) và chọn tên quãng hòa thanh:'
                  : (isInter
                      ? 'Nghe hai nốt đi xuống liên tiếp (từ quãng trên về $rootLabel) và xác định tên quãng:'
                      : 'Nghe hai nốt đi lên liên tiếp (khởi từ $rootLabel) và chọn tên quãng đúng:'),
              explanation: '$label (gốc $rootLabel): $desc',
              audioAsset:
                  'assets/audio/intervals/${rootCode}_${fileCode}_$modeSuffix.wav',
              difficulty: diff,
              version: _currentGeneratorVersion,
              options: options,
            ),
          );
        }
      }
    } else if (topicId == 'topic_keys') {
      final isAdvanced = levelId.contains('adv');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);

      // All 10 studio key cadences in assets/audio/keys/
      final allKeyItems = [
        (
          'c_major',
          'C',
          'Đô Trưởng (C Major)',
          'Chuỗi hòa âm I–IV–V–I ở giọng Đô Trưởng (0 dấu hóa), màu sắc tươi sáng vững chãi.',
          true,
          '0',
          '0 dấu hóa (Không thăng, không giáng)'
        ),
        (
          'a_minor',
          'Am',
          'La Thứ (A Minor)',
          'Chuỗi hòa âm i–iv–V–i ở giọng La Thứ (0 dấu hóa), màu sắc trầm lắng mềm mại.',
          false,
          '0',
          '0 dấu hóa (Không thăng, không giáng)'
        ),
        (
          'g_major',
          'G',
          'Sol Trưởng (G Major)',
          'Chuỗi hòa âm giọng Sol Trưởng (1 dấu thăng Fa#), âm hưởng sáng rõ.',
          true,
          '1s',
          '1 dấu thăng (Fa#)'
        ),
        (
          'e_minor',
          'Em',
          'Mi Thứ (E Minor)',
          'Chuỗi hòa âm giọng Mi Thứ (1 dấu thăng Fa#), giọng Thứ song song với Sol Trưởng.',
          false,
          '1s',
          '1 dấu thăng (Fa#)'
        ),
        (
          'f_major',
          'F',
          'Fa Trưởng (F Major)',
          'Chuỗi hòa âm giọng Fa Trưởng (1 dấu giáng Sib), ấm áp và mở rộng.',
          true,
          '1b',
          '1 dấu giáng (Sib)'
        ),
        (
          'd_minor',
          'Dm',
          'Rê Thứ (D Minor)',
          'Chuỗi hòa âm giọng Rê Thứ (1 dấu giáng Sib), giọng Thứ song song với Fa Trưởng.',
          false,
          '1b',
          '1 dấu giáng (Sib)'
        ),
        (
          'd_major',
          'D',
          'Rê Trưởng (D Major)',
          'Chuỗi hòa âm giọng Rê Trưởng (2 dấu thăng Fa#, Đô#), rực rỡ tươi sáng.',
          true,
          '2s',
          '2 dấu thăng (Fa#, Đô#)'
        ),
        (
          'b_minor',
          'Bm',
          'Si Thứ (B Minor)',
          'Chuỗi hòa âm giọng Si Thứ (2 dấu thăng Fa#, Đô#), giọng Thứ song song với Rê Trưởng.',
          false,
          '2s',
          '2 dấu thăng (Fa#, Đô#)'
        ),
        if (isAdvanced || diff == 1)
          (
            'bb_major',
            'Bb',
            'Si giáng Trưởng (Bb Major)',
            'Chuỗi hòa âm giọng Si giáng Trưởng (2 dấu giáng Sib, Mib), âm hưởng đầy đặn.',
            true,
            '2b',
            '2 dấu giáng (Sib, Mib)'
          ),
        if (isAdvanced || diff == 1)
          (
            'g_minor',
            'Gm',
            'Sol Thứ (G Minor)',
            'Chuỗi hòa âm giọng Sol Thứ (2 dấu giáng Sib, Mib), giọng Thứ song song với Si giáng Trưởng.',
            false,
            '2b',
            '2 dấu giáng (Sib, Mib)'
          ),
      ];

      for (int i = 0; i < allKeyItems.length; i++) {
        final (fileKey, optKey, keyLabel, desc, isMaj, _, _) = allKeyItems[i];
        final qId = 'dyn_key_${levelId}_$fileKey';

        final List<QuestionOptionModel> options;
        if (diff == 1) {
          options = [
            QuestionOptionModel(
              id: '${qId}_o1',
              questionId: qId,
              optionKey: 'major',
              label: 'Giọng Trưởng (Major)',
              isCorrect: isMaj,
              sortOrder: 1,
            ),
            QuestionOptionModel(
              id: '${qId}_o2',
              questionId: qId,
              optionKey: 'minor',
              label: 'Giọng Thứ (Minor)',
              isCorrect: !isMaj,
              sortOrder: 2,
            ),
          ];
        } else {
          final distractors = <int>{
            (i + 1) % allKeyItems.length,
            (i + 2) % allKeyItems.length,
            (i + 3) % allKeyItems.length,
          };
          final allIdx = [i, ...distractors];
          options = [
            for (int idx = 0; idx < allIdx.length; idx++)
              QuestionOptionModel(
                id: '${qId}_o${idx + 1}',
                questionId: qId,
                optionKey: allKeyItems[allIdx[idx]].$2,
                label: allKeyItems[allIdx[idx]].$3,
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
                ? 'Nghe chuỗi hòa âm I – IV – V – I và xác định màu sắc Trưởng hay Thứ:'
                : 'Nghe chuỗi hòa âm (có thể đối chiếu C4) và chọn đúng tên giọng:',
            explanation: desc,
            audioAsset: 'assets/audio/keys/$fileKey.wav',
            difficulty: diff,
            version: _currentGeneratorVersion,
            options: options,
          ),
        );
      }

      // Also generate key_signature questions across all levels of topic_keys
      const sigPool = [
        ('0', '0 dấu hóa (Không thăng, không giáng)'),
        ('1s', '1 dấu thăng (Fa#)'),
        ('1b', '1 dấu giáng (Sib)'),
        ('2s', '2 dấu thăng (Fa#, Đô#)'),
        ('2b', '2 dấu giáng (Sib, Mib)'),
      ];
      final sigItemCount = diff == 1 ? 6 : allKeyItems.length;
      for (int i = 0; i < sigItemCount; i++) {
        final (fileKey, _, keyLabel, desc, _, sigKey, sigLabel) =
            allKeyItems[i];
        final qId = 'dyn_keysig_${levelId}_$fileKey';
        final wrongSigs = sigPool.where((s) => s.$1 != sigKey).take(3).toList();
        final sigOptions = <QuestionOptionModel>[
          QuestionOptionModel(
            id: '${qId}_o1',
            questionId: qId,
            optionKey: sigKey,
            label: sigLabel,
            isCorrect: true,
            sortOrder: 1,
          ),
          for (int w = 0; w < wrongSigs.length; w++)
            QuestionOptionModel(
              id: '${qId}_o${w + 2}',
              questionId: qId,
              optionKey: wrongSigs[w].$1,
              label: wrongSigs[w].$2,
              isCorrect: false,
              sortOrder: w + 2,
            ),
        ];
        generated.add(
          QuestionModel(
            id: qId,
            topicId: topicId,
            levelId: levelId,
            type: 'key_signature',
            prompt:
                'Nghe chuỗi hòa âm giọng $keyLabel. Hóa biểu của giọng này có bao nhiêu dấu hóa?',
            explanation: '$keyLabel có hóa biểu: $sigLabel. $desc',
            audioAsset: 'assets/audio/keys/$fileKey.wav',
            difficulty: diff,
            version: _currentGeneratorVersion,
            options: sigOptions,
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
          final allIdx = [i, ...distractors];

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
              version: _currentGeneratorVersion,
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
          final allIdx = [i, ...distractors];

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
              version: _currentGeneratorVersion,
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
          final allIdx = [i, ...distractors];

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
              version: _currentGeneratorVersion,
              options: options,
            ),
          );
        }
      }
    } else if (topicId.startsWith('topic_guitar_')) {
      final isAdvanced = levelId.contains('adv') || levelId.contains('master');
      final isInter = levelId.contains('inter');
      final diff = isAdvanced ? 3 : (isInter ? 2 : 1);

      List<(String audioAsset, String optKey, String label, String prompt, String desc)>
          guitarPool = [];

      if (topicId == 'topic_guitar_notes') {
        final basicNotes = [
          (
            'assets/audio/notes/e3.wav',
            'GTR_S6_F0',
            'Mi trầm (E2 • Dây 6 buông)',
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 6 buông) và chọn tên nốt:',
            'Dây 6 buông (dây dày nhất trên cùng khi cầm đàn) là nốt Mi trầm (E2).'
          ),
          (
            'assets/audio/notes/a3.wav',
            'GTR_S5_F0',
            'La (A2 • Dây 5 buông)',
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 5 buông) và chọn tên nốt:',
            'Dây 5 buông là nốt La (A2) — âm Bass chuẩn của hợp âm La Thứ (Am).'
          ),
          (
            'assets/audio/notes/d3.wav',
            'GTR_S4_F0',
            'Rê (D3 • Dây 4 buông)',
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 4 buông) và chọn tên nốt:',
            'Dây 4 buông là nốt Rê (D3) — âm Bass chuẩn của hợp âm Rê Thứ (Dm).'
          ),
          (
            'assets/audio/notes/g3.wav',
            'GTR_S3_F0',
            'Sol (G3 • Dây 3 buông)',
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 3 buông) và chọn tên nốt:',
            'Dây 3 buông là nốt Sol (G3).'
          ),
          (
            'assets/audio/notes/b3.wav',
            'GTR_S2_F0',
            'Si (B3 • Dây 2 buông)',
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 2 buông) và chọn tên nốt:',
            'Dây 2 buông là nốt Si (B3).'
          ),
          (
            'assets/audio/notes/e4.wav',
            'GTR_S1_F0',
            'Mi cao (e4 • Dây 1 buông)',
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 1 buông mỏng nhất) và chọn tên nốt:',
            'Dây 1 buông (mỏng nhất dưới cùng) là nốt Mi cao (e4).'
          ),
          (
            'assets/audio/notes/g3.wav',
            'GTR_S6_F3',
            'Sol (G • Dây 6 Ngăn 3)',
            'Nhìn vị trí (?) tại Dây 6 • Ngăn 3 (chấm mốc đầu tiên) và chọn tên nốt:',
            'Dây 6 buông là Mi → Ngăn 1 là Fa → Ngăn 3 là Sol (G).'
          ),
          (
            'assets/audio/notes/c4.wav',
            'GTR_S5_F3',
            'Đô (C • Dây 5 Ngăn 3)',
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 3 và chọn tên nốt:',
            'Dây 5 buông là La → Ngăn 2 là Si → Ngăn 3 là Đô (C).'
          ),
        ];

        final interNotes = [
          ...basicNotes,
          (
            'assets/audio/notes/a3.wav',
            'GTR_S6_F5',
            'La (A • Dây 6 Ngăn 5)',
            'Nhìn vị trí (?) tại Dây 6 • Ngăn 5 và chọn tên nốt:',
            'Dây 6 Ngăn 5 là nốt La (A), trùng cao độ với Dây 5 buông (mốc so dây ngăn 5).'
          ),
          (
            'assets/audio/notes/d4.wav',
            'GTR_S5_F5',
            'Rê (D • Dây 5 Ngăn 5)',
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 5 và chọn tên nốt:',
            'Dây 5 Ngăn 5 là nốt Rê (D), trùng cao độ với Dây 4 buông.'
          ),
          (
            'assets/audio/notes/e4.wav',
            'GTR_S5_F7',
            'Mi (E • Dây 5 Ngăn 7)',
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 7 (chấm mốc thứ 3) và chọn tên nốt:',
            'Từ Rê (Ngăn 5 Dây 5) tiến 1 cung lên Ngăn 7 là nốt Mi (E).'
          ),
          (
            'assets/audio/notes/c4.wav',
            'GTR_S2_F1',
            'Đô (C4 • Dây 2 Ngăn 1)',
            'Nhìn vị trí (?) tại Dây 2 • Ngăn 1 và chọn tên nốt:',
            'Dây 2 buông là Si (B3), tiến nửa cung vào Ngăn 1 là nốt Đô chuẩn (C4).'
          ),
        ];

        final advNotes = [
          ...interNotes,
          (
            'assets/audio/notes/fsharp4.wav',
            'GTR_S6_F2',
            'Fa# (F# • Dây 6 Ngăn 2)',
            'Nhìn vị trí (?) tại Dây 6 • Ngăn 2 và chọn tên nốt có dấu hóa:',
            'Giữa Fa (Ngăn 1) và Sol (Ngăn 3) trên Dây 6 là nốt Fa thăng (F#).'
          ),
          (
            'assets/audio/notes/csharp4.wav',
            'GTR_S5_F4',
            'Đô# (C# • Dây 5 Ngăn 4)',
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 4 và chọn tên nốt:',
            'Từ Đô (Dây 5 Ngăn 3) tiến 1 ngăn lên Ngăn 4 là nốt Đô thăng (C#).'
          ),
          (
            'assets/audio/notes/c5.wav',
            'GTR_S1_F8',
            'Đô cao (C5 • Dây 1 Ngăn 8)',
            'Nhìn vị trí (?) tại Dây 1 • Ngăn 8 và chọn tên nốt:',
            'Trên Dây 1 (e4): Ngăn 5 là La (A4) → Ngăn 7 là Si (B4) → Ngăn 8 là Đô cao (C5).'
          ),
          (
            'assets/audio/notes/a4.wav',
            'GTR_S2_F10',
            'La cao (A4 • Dây 2 Ngăn 10)',
            'Nhìn vị trí (?) tại Dây 2 • Ngăn 10 và chọn tên nốt:',
            'Trên Dây 2: Ngăn 8 là Sol (G4), tiến 2 ngăn lên Ngăn 10 là nốt La chuẩn (A4).'
          ),
        ];

        guitarPool =
            isAdvanced ? advNotes : (isInter ? interNotes : basicNotes);
      } else if (topicId == 'topic_guitar_chords') {
        final basicChords = [
          (
            'assets/audio/keys/chord_c_maj.wav',
            'GTR_CHORD_C',
            'Đô Trưởng (C • X-3-2-0-1-0)',
            'Quan sát thế bấm ngón tay trên cần đàn Guitar và chọn đúng hợp âm:',
            'Hợp âm Đô Trưởng (C): Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 5 ngăn 3.'
          ),
          (
            'assets/audio/keys/chord_g_maj.wav',
            'GTR_CHORD_G',
            'Sol Trưởng (G • 3-2-0-0-0-3)',
            'Quan sát thế bấm 6 dây trên cần đàn Guitar và chọn tên hợp âm:',
            'Hợp âm Sol Trưởng (G): Ngón 1 Dây 5 ngăn 2 • Ngón 2 Dây 6 ngăn 3 • Ngón 3 Dây 1 ngăn 3.'
          ),
          (
            'assets/audio/keys/chord_a_min.wav',
            'GTR_CHORD_Am',
            'La Thứ (Am • X-0-2-2-1-0)',
            'Quan sát thế bấm trên cần đàn Guitar (Bass dây 5 buông) và chọn đúng hợp âm:',
            'Hợp âm La Thứ (Am): Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 3 ngăn 2.'
          ),
          (
            'assets/audio/keys/chord_d_min.wav',
            'GTR_CHORD_Em',
            'Mi Thứ (Em • 0-2-2-0-0-0)',
            'Quan sát thế bấm chỉ dùng 2 ngón trên Dây 5 & Dây 4 ngăn 2 và chọn hợp âm:',
            'Hợp âm Mi Thứ (Em): Bấm Dây 5 ngăn 2 và Dây 4 ngăn 2, rải vang cả 6 dây.'
          ),
          (
            'assets/audio/keys/chord_d_min.wav',
            'GTR_CHORD_Dm',
            'Rê Thứ (Dm • X-X-0-2-3-1)',
            'Quan sát thế bấm ở 3 dây dưới (Bass dây 4 buông) và chọn tên hợp âm:',
            'Hợp âm Rê Thứ (Dm): Ngón 1 Dây 1 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 2 ngăn 3.'
          ),
          (
            'assets/audio/keys/chord_g_maj.wav',
            'GTR_CHORD_D',
            'Rê Trưởng (D • X-X-0-2-3-2)',
            'Quan sát thế bấm hình tam giác ở 3 dây dưới và chọn tên hợp âm:',
            'Hợp âm Rê Trưởng (D): Ngón 1 Dây 3 ngăn 2 • Ngón 2 Dây 1 ngăn 2 • Ngón 3 Dây 2 ngăn 3.'
          ),
        ];

        final interChords = [
          ...basicChords,
          (
            'assets/audio/keys/chord_f_maj.wav',
            'GTR_CHORD_F',
            'Fa Trưởng (F • Chặn ngăn 1)',
            'Quan sát thế bấm chặn ngăn 1 trên cần đàn và chọn tên hợp âm:',
            'Hợp âm Fa Trưởng (F): Ngón 1 chặn ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 4 ngăn 3.'
          ),
          (
            'assets/audio/keys/chord_c_maj.wav',
            'GTR_CHORD_E',
            'Mi Trưởng (E • 0-2-2-1-0-0)',
            'Quan sát thế bấm giống Am nhưng dịch toàn bộ lên 1 dây và chọn hợp âm:',
            'Hợp âm Mi Trưởng (E): Ngón 1 Dây 3 ngăn 1 • Ngón 2 Dây 5 ngăn 2 • Ngón 3 Dây 4 ngăn 2.'
          ),
        ];

        final advChords = [
          ...interChords,
          (
            'assets/audio/keys/chord_c_maj7.wav',
            'GTR_CHORD_C',
            'Đô Bảy Trưởng (Cmaj7 • Bỏ ngón trỏ khỏi Dây 2)',
            'Khi đang bấm Đô Trưởng (C), nếu nhấc ngón trỏ (Dây 2 ngăn 1) ra thành Dây 2 buông (Si B) ta được hợp âm màu gì?',
            'Thêm nốt Si (B - bậc 7 trưởng) vào C tạo thành hợp âm Cmaj7 (X-3-2-0-0-0) rất êm dịu.'
          ),
          (
            'assets/audio/keys/chord_a_min7.wav',
            'GTR_CHORD_Am',
            'La Bảy Thứ (Am7 • X-0-2-0-1-0)',
            'Khi đang bấm La Thứ (Am), nhấc ngón áp út khỏi Dây 3 ngăn 2 để vang Dây 3 buông (Sol G) tạo thành hợp âm gì?',
            'Dây 3 buông là Sol (bậc 7 thứ của La), tạo thành hợp âm Am7 (X-0-2-0-1-0).'
          ),
          (
            'assets/audio/keys/c_major.wav',
            'GTR_CHORD_C',
            'Vòng Canon / Pop: C – G – Am – F (I – V – vi – IV)',
            'Vòng 4 hợp âm kinh điển bậc I – V – vi – IV trong giọng Đô Trưởng dùng cho hàng nghìn bài Pop/Ballad là gì?',
            'Trong giọng Đô Trưởng: Bậc I = C, Bậc V = G, Bậc vi = Am, Bậc IV = F.'
          ),
        ];

        guitarPool =
            isAdvanced ? advChords : (isInter ? interChords : basicChords);
      } else if (topicId == 'topic_guitar_scales') {
        final basicScales = [
          (
            'assets/audio/keys/a_minor.wav',
            'GTR_SCALE_AM',
            'Ngũ cung La Thứ (Am Pentatonic: A–C–D–E–G)',
            'Quan sát Bản đồ Scale trên cần đàn (5 nốt mỗi quãng tám, gốc La A) và chọn tên Scale:',
            'Am Pentatonic gồm 5 nốt (La – Đô – Rê – Mi – Sol), là bản đồ số 1 để chạy ngón Solo Guitar.'
          ),
          (
            'assets/audio/keys/c_major.wav',
            'GTR_SCALE_C',
            'Âm giai Đô Trưởng (C Major: C–D–E–F–G–A–B)',
            'Quan sát Bản đồ Scale 7 nốt tự nhiên (gốc Đô C tại Dây 5 Ngăn 3) và chọn đáp án:',
            'Scale Đô Trưởng gồm 7 nốt tự nhiên không thăng giáng, song song với La Thứ.'
          ),
          (
            'assets/audio/notes/a3.wav',
            'GTR_S6_F5',
            'Nốt Chủ âm (Root Note – Nốt Gốc)',
            'Trên Bản đồ Scale Guitar, chấm tròn màu Đỏ nổi bật dùng để chỉ nốt gì?',
            'Nốt Gốc (Root Note) là điểm tựa bắt đầu và kết thúc câu Solo đúng giọng.'
          ),
          (
            'assets/audio/notes/e4.wav',
            'GTR_S1_F0',
            'Ngăn 12 (Chấm đôi Inlay trên cần đàn)',
            'Trên cần đàn Guitar, ở ngăn thứ mấy thì toàn bộ 6 dây lặp lại đúng tên nốt của 6 dây buông?',
            'Ngăn 12 chia đôi chiều dài dây đàn, lặp lại đúng 6 nốt E–A–D–G–B–e cao hơn 1 quãng tám.'
          ),
          (
            'assets/audio/notes/c4.wav',
            'GTR_S5_F3',
            'Xuống 2 dây + Tiến thêm 2 ngăn (Dây 3 Ngăn 5)',
            'Từ nốt Đô (Dây 5 Ngăn 3), áp dụng Quy tắc Quãng 8 chéo sẽ tìm thấy nốt Đô tiếp theo ở đâu?',
            'Từ Dây 5: Lùi xuống 2 dây (về Dây 3) và tiến thêm 2 ngăn (từ Ngăn 3 lên Ngăn 5).'
          ),
          (
            'assets/audio/notes/g3.wav',
            'GTR_S6_F3',
            'Xuống 2 dây + Tiến thêm 2 ngăn (Dây 4 Ngăn 5)',
            'Từ nốt Sol (Dây 6 Ngăn 3), áp dụng Quy tắc Quãng 8 chéo sẽ gặp lại nốt Sol ở vị trí nào?',
            'Từ Dây 6 Ngăn 3: Xuống 2 dây (Dây 4) + tiến 2 ngăn (Ngăn 5) chính là nốt Sol cao hơn 1 quãng tám.'
          ),
        ];

        final interScales = [
          ...basicScales,
          (
            'assets/audio/notes/c4.wav',
            'GTR_S4_F10',
            'Xuống 2 dây + Tiến thêm 3 ngăn (do bù dây 2 Si)',
            'Từ Dây 4 hoặc Dây 3 lùi xuống 2 dây để tìm Quãng 8, ta cần tiến mấy ngăn (do đi qua Dây 2)?',
            'Vì khoảng cách Dây 3 sang Dây 2 là quãng 3 trưởng (thay vì quãng 4 đúng), khi đi qua Dây 2 cần cộng thêm 1 ngăn = Tiến 3 ngăn.'
          ),
          (
            'assets/audio/keys/e_minor.wav',
            'GTR_SCALE_AM',
            'Mi Thứ Ngũ Cung (Em Pentatonic: E–G–A–B–D)',
            'Scale Ngũ cung nào tận dụng được toàn bộ 5 dây buông (E, A, D, G, B) trên cần đàn Guitar?',
            'Em Pentatonic (E–G–A–B–D) chứa toàn bộ các nốt dây buông của Guitar.'
          ),
        ];

        final advScales = [
          ...interScales,
          (
            'assets/audio/keys/a_minor.wav',
            'GTR_SCALE_AM',
            'Dịch toàn bộ thế bấm lên 2 ngăn (bắt đầu từ Ngăn 7)',
            'Đang đánh mẫu Am Pentatonic ở Ngăn 5 (Gốc La), muốn chuyển (Transpose) sang giọng Si Thứ (Bm Pentatonic) ta làm thế nào?',
            'Trên Guitar, các mẫu Scale giữ nguyên hình dạng: từ La (Ngăn 5) tăng 1 cung lên Si (Ngăn 7) chỉ cần trượt cả bàn tay lên 2 ngăn!'
          ),
          (
            'assets/audio/keys/c_major.wav',
            'GTR_SCALE_C',
            'Hệ thống 5 thế bấm C – A – G – E – D nối liền 12 ngăn',
            'Phương pháp chia cần đàn thành 5 hộp thế bấm nối tiếp nhau theo 5 dáng hợp âm mở gọi là gì?',
            'Hệ thống CAGED giúp liên kết hợp âm và Scale xuyên suốt từ ngăn 0 đến ngăn 12.'
          ),
        ];

        guitarPool =
            isAdvanced ? advScales : (isInter ? interScales : basicScales);
      } else {
        // topic_guitar_tabs (Đọc Tab 6 dây & Luyện ngón Spider 1-2-3-4)
        final basicTabs = [
          (
            'assets/audio/notes/g3.wav',
            'GTR_TAB_S6_F3',
            'Bấm Dây 6 (dày nhất) tại Ngăn 3',
            'Nhìn ký hiệu số "3" nằm trên dòng kẻ dưới cùng (E|) của khuông Tab Guitar, bạn cần gảy như thế nào?',
            'Dòng dưới cùng của khuông Tab là Dây 6 (E2), số 3 nghĩa là bấm Ngăn 3 trên Dây 6.'
          ),
          (
            'assets/audio/notes/c4.wav',
            'GTR_TAB_S5_F3',
            'Bấm Dây 5 (La) tại Ngăn 3',
            'Nhìn ký hiệu số "3" trên dòng kẻ thứ 2 từ dưới lên (A|) của khuông Tab, bạn bấm ở đâu?',
            'Dòng A| đại diện cho Dây 5, số 3 nghĩa là bấm vào Ngăn 3 của Dây 5 (nốt Đô C).'
          ),
          (
            'assets/audio/notes/e4.wav',
            'GTR_TAB_S1_F0',
            'Gảy Dây 1 (mỏng nhất) buông không bấm',
            'Ký hiệu số "0" nằm trên dòng kẻ trên cùng (e|) của khuông Tab có ý nghĩa gì?',
            'Dòng trên cùng (e|) là Dây 1 mỏng nhất; số 0 nghĩa là gảy dây buông không bấm ngón tay trái.'
          ),
          (
            'assets/audio/notes/d4.wav',
            'GTR_TAB_S2_F3',
            'Bấm Dây 2 (Si) tại Ngăn 3',
            'Nhìn số "3" trên dòng B| (dòng thứ 2 từ trên xuống) của khuông Tab, bạn thực hiện thế bấm nào?',
            'Dòng B| là Dây 2; số 3 nghĩa là bấm Ngăn 3 trên Dây 2 (nốt Rê D4).'
          ),
          (
            'assets/audio/notes/f3.wav',
            'GTR_TAB_S6_F1',
            'Trỏ (1) – Giữa (2) – Áp út (3) – Út (4) trên 4 ngăn liên tiếp',
            'Trong bài luyện ngón "Bò nhện (Spider Walk 1–2–3–4)", 4 ngón tay trái được phân công như thế nào?',
            'Mỗi ngón phụ trách 1 ngăn liên tiếp (1–2–3–4) giúp mở rộng sải tay và độc lập ngón.'
          ),
          (
            'assets/audio/keys/chord_c_maj.wav',
            'GTR_CHORD_C',
            'Bass – 3 – 2 – 3 – 1 – 3 – 2 – 3',
            'Công thức rải dây tay phải phổ biến nhất cho điệu Ballad / Canon ở nhịp 4/4 là gì?',
            'Ngón cái gảy dây Bass, tiếp theo lần lượt gảy Dây 3 – 2 – 3 – 1 – 3 – 2 – 3.'
          ),
        ];

        final interTabs = [
          ...basicTabs,
          (
            'assets/audio/keys/chord_a_min.wav',
            'GTR_CHORD_Am',
            'Ngón Cái (P: dây 4,5,6) • Trỏ (i: dây 3) • Giữa (m: dây 2) • Áp út (a: dây 1)',
            'Nguyên tắc chuẩn phân công 4 ngón tay phải (P – i – m – a) khi rải hợp âm Guitar là gì?',
            'Ngón cái (P) phụ trách 3 dây Bass (4, 5, 6); Trỏ (i) gảy dây 3; Giữa (m) gảy dây 2; Áp út (a) gảy dây 1.'
          ),
          (
            'assets/audio/keys/rhy_waltz_3_4.wav',
            'GTR_CHORD_G',
            'Bass – (321) – (321) hoặc Bass – 3 – (21) – 3',
            'Công thức rải tay phải đặc trưng cho nhịp 3/4 (Điệu Valse / Boston) trên Guitar là gì?',
            'Nhịp 3/4 có 3 phách (Bùm – Chát – Chát): Phách 1 gảy Bass, phách 2 và 3 móc đồng thời 3 dây dưới (3-2-1).'
          ),
        ];

        final advTabs = [
          ...interTabs,
          (
            'assets/audio/notes/g4.wav',
            'GTR_TAB_S1_F3',
            'Hammer-on (Gảy ngăn 5 rồi đập ngón xuống ngăn 7)',
            'Trên bản Tab Guitar, ký hiệu "5h7" có ý nghĩa kỹ thuật là gì?',
            'Chữ "h" là Hammer-on (Luyến lên / Đập ngón): Gảy nốt ở ngăn 5 rồi dùng ngón tay trái đập mạnh vào ngăn 7.'
          ),
          (
            'assets/audio/notes/e4.wav',
            'GTR_TAB_S1_F0',
            'Pull-off (Kéo ngón từ ngăn 7 nhả về ngăn 5)',
            'Trên bản Tab Guitar, ký hiệu "7p5" hướng dẫn kỹ thuật gì?',
            'Chữ "p" là Pull-off (Luyến xuống / Kéo ngón): Từ ngăn 7 bật nhẹ ngón tay trái nhả về ngăn 5 đang giữ sẵn.'
          ),
          (
            'assets/audio/notes/a4.wav',
            'GTR_TAB_S2_F5',
            'Slide (Trượt ngón tay trên dây từ ngăn 5 lên ngăn 7)',
            'Trên bản Tab Guitar, ký hiệu "5/7" hoặc "5s7" biểu thị kỹ thuật nào?',
            'Dấu "/" hoặc "s" là Slide (Trượt ngón): Giữ lực bấm từ ngăn 5 và miết dọc dây đàn tới ngăn 7.'
          ),
        ];

        guitarPool =
            isAdvanced ? advTabs : (isInter ? interTabs : basicTabs);
      }

      final passes = guitarPool.length < 10 ? 2 : 1;
      for (int pass = 0; pass < passes; pass++) {
        for (int i = 0; i < guitarPool.length; i++) {
          final (audioAsset, optKey, label, prompt, desc) = guitarPool[i];
          final qId = 'dyn_gtr_${topicId}_${levelId}_${i}_p$pass';
          final step1 = pass == 0 ? 1 : 2;
          final step2 = pass == 0 ? 2 : 3;
          final step3 = pass == 0 ? 3 : 4;
          final distractors = <int>{
            (i + step1) % guitarPool.length,
            (i + step2) % guitarPool.length,
            (i + step3) % guitarPool.length,
          };
          int fb = 1;
          while (distractors.length < 3) {
            final cand = (i + fb) % guitarPool.length;
            if (cand != i) distractors.add(cand);
            fb++;
          }
          final allIdx = [i, ...distractors];

          final options = <QuestionOptionModel>[
            for (int idx = 0; idx < allIdx.length; idx++)
              QuestionOptionModel(
                id: '${qId}_o${idx + 1}',
                questionId: qId,
                optionKey: guitarPool[allIdx[idx]].$2,
                label: guitarPool[allIdx[idx]].$3,
                isCorrect: allIdx[idx] == i,
                sortOrder: idx + 1,
              ),
          ];

          generated.add(
            QuestionModel(
              id: qId,
              topicId: topicId,
              levelId: levelId,
              type: 'guitar_practice',
              prompt: prompt,
              explanation: desc,
              audioAsset: audioAsset,
              difficulty: diff,
              version: _currentGeneratorVersion,
              options: options,
            ),
          );
        }
      }
    }

    await _db.upsertQuestionsBatch(generated);
  }
}
