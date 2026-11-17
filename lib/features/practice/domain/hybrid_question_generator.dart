import 'dart:math';

import '../../../core/audio/asset_validator.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/utils/note_formatter.dart';
import '../presentation/widgets/musical_staff_widget.dart';

class HybridQuestionGenerator {
  static const int _currentGeneratorVersion = 10;
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
    if (q.id.startsWith('dyn_') && q.version < _currentGeneratorVersion) {
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
    if (q.topicId.startsWith('topic_guitar_')) {
      // Guitar questions have curated homogeneous 4-option sets per question subtype;
      // preserve the exact 4 options and only shuffle their A/B/C/D slot positions.
      assembledOptions = [...q.options];
    } else if (q.options.length >= 4 && wrongSlotOpts.isNotEmpty) {
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
                'Trên khuông nhạc, hóa biểu của giọng $keyLabel gồm bao nhiêu dấu hóa?',
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

      // Mỗi câu hỏi Guitar có kiểu riêng (qType) và bộ 4 đáp án đồng nhất cùng loại (1 đáp án đúng + 3 đáp án nhiễu cùng bản chất)
      List<
          (
            String qType,
            String audioAsset,
            String optKey,
            String correctLabel,
            List<(String, String)> wrongOptions,
            String prompt,
            String desc,
          )> guitarSpecs = [];

      if (topicId == 'topic_guitar_notes') {
        final basicNotes = [
          (
            'guitar_fret_note',
            'assets/audio/notes/e2.wav',
            'GTR_S6_F0',
            'Mi trầm (E2)',
            [
              ('GTR_S5_F0', 'La trầm (A2)'),
              ('GTR_S4_F0', 'Rê trầm (D3)'),
              ('GTR_S3_F0', 'Sol trầm (G3)'),
            ],
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 6 buông dày nhất) và chọn tên nốt:',
            'Dây 6 buông là nốt Mi trầm (E2 – 82.4 Hz). Sau khi chọn đáp án, hệ thống phát vang đúng cao độ E2.'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/a2.wav',
            'GTR_S5_F0',
            'La trầm (A2)',
            [
              ('GTR_S6_F0', 'Mi trầm (E2)'),
              ('GTR_S4_F0', 'Rê trầm (D3)'),
              ('GTR_S2_F0', 'Si trầm (B3)'),
            ],
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 5 buông) và chọn tên nốt:',
            'Dây 5 buông là nốt La trầm (A2 – 110.0 Hz) — âm Bass gốc của hợp âm La Thứ (Am).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/d3.wav',
            'GTR_S4_F0',
            'Rê trầm (D3)',
            [
              ('GTR_S5_F0', 'La trầm (A2)'),
              ('GTR_S3_F0', 'Sol trầm (G3)'),
              ('GTR_S5_F3', 'Đô trầm (C3)'),
            ],
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 4 buông) và chọn tên nốt:',
            'Dây 4 buông là nốt Rê trầm (D3 – 146.8 Hz) — âm Bass gốc của hợp âm Rê Trưởng (D) và Rê Thứ (Dm).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/g3.wav',
            'GTR_S3_F0',
            'Sol trầm (G3)',
            [
              ('GTR_S4_F0', 'Rê trầm (D3)'),
              ('GTR_S2_F0', 'Si trầm (B3)'),
              ('GTR_S1_F0', 'Mi chuẩn (E4)'),
            ],
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 3 buông) và chọn tên nốt:',
            'Dây 3 buông là nốt Sol trầm (G3 – 196.0 Hz).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/b3.wav',
            'GTR_S2_F0',
            'Si trầm (B3)',
            [
              ('GTR_S3_F0', 'Sol trầm (G3)'),
              ('GTR_S1_F0', 'Mi chuẩn (E4)'),
              ('GTR_S2_F1', 'Đô chuẩn (C4)'),
            ],
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 2 buông) và chọn tên nốt:',
            'Dây 2 buông là nốt Si trầm (B3 – 246.9 Hz), nằm ngay dưới Đô chuẩn (C4) nửa cung.'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/e4.wav',
            'GTR_S1_F0',
            'Mi chuẩn (E4)',
            [
              ('GTR_S2_F0', 'Si trầm (B3)'),
              ('GTR_S3_F0', 'Sol trầm (G3)'),
              ('GTR_S1_F3', 'Sol chuẩn (G4)'),
            ],
            'Nhìn vị trí (?) trên cần đàn Guitar (Dây 1 buông mỏng nhất) và chọn tên nốt:',
            'Dây 1 buông (mỏng nhất dưới cùng) là nốt Mi chuẩn (E4 – 329.6 Hz), cao hơn Dây 6 buông 2 quãng tám.'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/g2.wav',
            'GTR_S6_F3',
            'Sol rất trầm (G2)',
            [
              ('GTR_S6_F1', 'Fa rất trầm (F2)'),
              ('GTR_S5_F3', 'Đô trầm (C3)'),
              ('GTR_S5_F0', 'La trầm (A2)'),
            ],
            'Nhìn vị trí (?) tại Dây 6 • Ngăn 3 (chấm mốc đầu tiên) và chọn tên nốt:',
            'Dây 6 buông là Mi (E2) → Ngăn 1 là Fa (F2) → Ngăn 3 là Sol rất trầm (G2 – 98.0 Hz).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/c3.wav',
            'GTR_S5_F3',
            'Đô trầm (C3)',
            [
              ('GTR_S5_F2', 'Si rất trầm (B2)'),
              ('GTR_S6_F3', 'Sol rất trầm (G2)'),
              ('GTR_S4_F0', 'Rê trầm (D3)'),
            ],
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 3 (nốt Bass của hợp âm Đô Trưởng) và chọn tên nốt:',
            'Dây 5 buông là La (A2) → Ngăn 2 là Si (B2) → Ngăn 3 là Đô trầm (C3 – 130.8 Hz).'
          ),
        ];

        final interNotes = [
          ...basicNotes,
          (
            'guitar_fret_note',
            'assets/audio/notes/a2.wav',
            'GTR_S6_F5',
            'La trầm (A2)',
            [
              ('GTR_S6_F3', 'Sol rất trầm (G2)'),
              ('GTR_S5_F3', 'Đô trầm (C3)'),
              ('GTR_S4_F0', 'Rê trầm (D3)'),
            ],
            'Nhìn vị trí (?) tại Dây 6 • Ngăn 5 (mốc so dây ngăn 5) và chọn tên nốt:',
            'Dây 6 Ngăn 5 là nốt La trầm (A2), trùng đúng cao độ với Dây 5 buông.'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/d3.wav',
            'GTR_S5_F5',
            'Rê trầm (D3)',
            [
              ('GTR_S5_F3', 'Đô trầm (C3)'),
              ('GTR_S5_F7', 'Mi trầm (E3)'),
              ('GTR_S3_F0', 'Sol trầm (G3)'),
            ],
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 5 và chọn tên nốt:',
            'Dây 5 Ngăn 5 là nốt Rê trầm (D3), trùng đúng cao độ với Dây 4 buông.'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/e3.wav',
            'GTR_S5_F7',
            'Mi trầm (E3)',
            [
              ('GTR_S5_F5', 'Rê trầm (D3)'),
              ('GTR_S4_F3', 'Fa trầm (F3)'),
              ('GTR_S3_F0', 'Sol trầm (G3)'),
            ],
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 7 (chấm mốc thứ 3) và chọn tên nốt:',
            'Từ Rê (Dây 5 Ngăn 5) tiến 1 cung (2 ngăn) lên Ngăn 7 là nốt Mi trầm (E3).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/c4.wav',
            'GTR_S2_F1',
            'Đô chuẩn (C4)',
            [
              ('GTR_S2_F0', 'Si trầm (B3)'),
              ('GTR_S2_F3', 'Rê chuẩn (D4)'),
              ('GTR_S1_F0', 'Mi chuẩn (E4)'),
            ],
            'Nhìn vị trí (?) tại Dây 2 • Ngăn 1 và chọn tên nốt:',
            'Dây 2 buông là Si (B3), tiến nửa cung vào Ngăn 1 là nốt Đô chuẩn (C4 – 261.6 Hz).'
          ),
        ];

        final advNotes = [
          ...interNotes,
          (
            'guitar_fret_note',
            'assets/audio/notes/fsharp2.wav',
            'GTR_S6_F2',
            'Fa# rất trầm (F#2)',
            [
              ('GTR_S6_F1', 'Fa rất trầm (F2)'),
              ('GTR_S6_F4', 'Sol# rất trầm (G#2)'),
              ('GTR_S5_F1', 'La# rất trầm (A#2)'),
            ],
            'Nhìn vị trí (?) tại Dây 6 • Ngăn 2 và chọn tên nốt có dấu hóa:',
            'Giữa Fa (Ngăn 1) và Sol (Ngăn 3) trên Dây 6 là nốt Fa thăng (F#2).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/csharp3.wav',
            'GTR_S5_F4',
            'Đô# trầm (C#3)',
            [
              ('GTR_S5_F3', 'Đô trầm (C3)'),
              ('GTR_S5_F6', 'Rê# trầm (D#3)'),
              ('GTR_S4_F4', 'Fa# trầm (F#3)'),
            ],
            'Nhìn vị trí (?) tại Dây 5 • Ngăn 4 và chọn tên nốt có dấu hóa:',
            'Từ Đô (Dây 5 Ngăn 3) tiến 1 ngăn lên Ngăn 4 là nốt Đô thăng (C#3).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/c5.wav',
            'GTR_S1_F8',
            'Đô cao (C5)',
            [
              ('GTR_S1_F7', 'Si chuẩn (B4)'),
              ('GTR_S1_F5', 'La chuẩn (A4)'),
              ('GTR_S1_F10', 'Rê cao (D5)'),
            ],
            'Nhìn vị trí (?) tại Dây 1 • Ngăn 8 và chọn tên nốt:',
            'Trên Dây 1 (e4): Ngăn 5 là La (A4) → Ngăn 7 là Si (B4) → Ngăn 8 là Đô cao (C5).'
          ),
          (
            'guitar_fret_note',
            'assets/audio/notes/a4.wav',
            'GTR_S2_F10',
            'La chuẩn (A4)',
            [
              ('GTR_S2_F8', 'Sol chuẩn (G4)'),
              ('GTR_S2_F12', 'Si chuẩn (B4)'),
              ('GTR_S1_F8', 'Đô cao (C5)'),
            ],
            'Nhìn vị trí (?) tại Dây 2 • Ngăn 10 và chọn tên nốt:',
            'Trên Dây 2: Ngăn 8 là Sol (G4), tiến 2 ngăn lên Ngăn 10 là nốt La chuẩn (A4 – 440 Hz).'
          ),
        ];

        guitarSpecs =
            isAdvanced ? advNotes : (isInter ? interNotes : basicNotes);
      } else if (topicId == 'topic_guitar_chords') {
        final basicChords = [
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_c_maj.wav',
            'GTR_CHORD_C',
            'Đô Trưởng (C • X-3-2-0-1-0)',
            [
              ('GTR_CHORD_Am', 'La Thứ (Am • X-0-2-2-1-0)'),
              ('GTR_CHORD_G', 'Sol Trưởng (G • 3-2-0-0-0-3)'),
              ('GTR_CHORD_F', 'Fa Trưởng (F • Chặn ngăn 1)'),
            ],
            'Nghe âm thanh & quan sát thế bấm trên cần đàn Guitar để chọn đúng hợp âm:',
            'Hợp âm Đô Trưởng (C): Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 5 ngăn 3.'
          ),
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_g_maj.wav',
            'GTR_CHORD_G',
            'Sol Trưởng (G • 3-2-0-0-0-3)',
            [
              ('GTR_CHORD_C', 'Đô Trưởng (C • X-3-2-0-1-0)'),
              ('GTR_CHORD_Em', 'Mi Thứ (Em • 0-2-2-0-0-0)'),
              ('GTR_CHORD_D', 'Rê Trưởng (D • X-X-0-2-3-2)'),
            ],
            'Nghe âm thanh & quan sát thế bấm 6 dây trên cần đàn để chọn tên hợp âm:',
            'Hợp âm Sol Trưởng (G): Ngón 1 Dây 5 ngăn 2 • Ngón 2 Dây 6 ngăn 3 • Ngón 3 Dây 1 ngăn 3.'
          ),
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_a_min.wav',
            'GTR_CHORD_Am',
            'La Thứ (Am • X-0-2-2-1-0)',
            [
              ('GTR_CHORD_C', 'Đô Trưởng (C • X-3-2-0-1-0)'),
              ('GTR_CHORD_E', 'Mi Trưởng (E • 0-2-2-1-0-0)'),
              ('GTR_CHORD_Dm', 'Rê Thứ (Dm • X-X-0-2-3-1)'),
            ],
            'Nghe âm thanh & quan sát thế bấm (Bass dây 5 buông) để chọn đúng hợp âm:',
            'Hợp âm La Thứ (Am): Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 3 ngăn 2.'
          ),
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_e_min.wav',
            'GTR_CHORD_Em',
            'Mi Thứ (Em • 0-2-2-0-0-0)',
            [
              ('GTR_CHORD_Am', 'La Thứ (Am • X-0-2-2-1-0)'),
              ('GTR_CHORD_E', 'Mi Trưởng (E • 0-2-2-1-0-0)'),
              ('GTR_CHORD_G', 'Sol Trưởng (G • 3-2-0-0-0-3)'),
            ],
            'Nghe âm thanh & quan sát thế bấm 2 ngón trên Dây 5 & Dây 4 ngăn 2 để chọn hợp âm:',
            'Hợp âm Mi Thứ (Em): Bấm Dây 5 ngăn 2 (Ngón 2) và Dây 4 ngăn 2 (Ngón 3), rải cả 6 dây.'
          ),
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_d_min.wav',
            'GTR_CHORD_Dm',
            'Rê Thứ (Dm • X-X-0-2-3-1)',
            [
              ('GTR_CHORD_D', 'Rê Trưởng (D • X-X-0-2-3-2)'),
              ('GTR_CHORD_Am', 'La Thứ (Am • X-0-2-2-1-0)'),
              ('GTR_CHORD_C', 'Đô Trưởng (C • X-3-2-0-1-0)'),
            ],
            'Nghe âm thanh & quan sát thế bấm ở 3 dây dưới (Bass dây 4 buông) để chọn hợp âm:',
            'Hợp âm Rê Thứ (Dm): Ngón 1 Dây 1 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 2 ngăn 3.'
          ),
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_d_maj.wav',
            'GTR_CHORD_D',
            'Rê Trưởng (D • X-X-0-2-3-2)',
            [
              ('GTR_CHORD_Dm', 'Rê Thứ (Dm • X-X-0-2-3-1)'),
              ('GTR_CHORD_G', 'Sol Trưởng (G • 3-2-0-0-0-3)'),
              ('GTR_CHORD_E', 'Mi Trưởng (E • 0-2-2-1-0-0)'),
            ],
            'Nghe âm thanh & quan sát thế bấm hình tam giác ở 3 dây dưới để chọn tên hợp âm:',
            'Hợp âm Rê Trưởng (D): Ngón 1 Dây 3 ngăn 2 • Ngón 2 Dây 1 ngăn 2 • Ngón 3 Dây 2 ngăn 3.'
          ),
        ];

        final interChords = [
          ...basicChords,
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_f_maj.wav',
            'GTR_CHORD_F',
            'Fa Trưởng (F • Chặn ngăn 1)',
            [
              ('GTR_CHORD_C', 'Đô Trưởng (C • X-3-2-0-1-0)'),
              ('GTR_CHORD_Dm', 'Rê Thứ (Dm • X-X-0-2-3-1)'),
              ('GTR_CHORD_G', 'Sol Trưởng (G • 3-2-0-0-0-3)'),
            ],
            'Nghe âm thanh & quan sát thế bấm chặn ngăn 1 trên cần đàn để chọn tên hợp âm:',
            'Hợp âm Fa Trưởng (F): Ngón 1 chặn ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 4 ngăn 3.'
          ),
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_e_maj.wav',
            'GTR_CHORD_E',
            'Mi Trưởng (E • 0-2-2-1-0-0)',
            [
              ('GTR_CHORD_Em', 'Mi Thứ (Em • 0-2-2-0-0-0)'),
              ('GTR_CHORD_Am', 'La Thứ (Am • X-0-2-2-1-0)'),
              ('GTR_CHORD_D', 'Rê Trưởng (D • X-X-0-2-3-2)'),
            ],
            'Nghe âm thanh & quan sát thế bấm (dịch dáng Am lên 1 dây) để chọn tên hợp âm:',
            'Hợp âm Mi Trưởng (E): Ngón 1 Dây 3 ngăn 1 • Ngón 2 Dây 5 ngăn 2 • Ngón 3 Dây 4 ngăn 2.'
          ),
        ];

        final advChords = [
          ...interChords,
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_c_maj7.wav',
            'GTR_CHORD_C',
            'Đô Bảy Trưởng (Cmaj7 • X-3-2-0-0-0)',
            [
              ('GTR_CHORD_Am7', 'La Bảy Thứ (Am7 • X-0-2-0-1-0)'),
              ('GTR_CHORD_G7', 'Sol Bảy Át (G7 • 3-2-0-0-0-1)'),
              ('GTR_CHORD_Csus4', 'Đô Treo Bậc 4 (Csus4 • X-3-3-0-1-1)'),
            ],
            'Nghe hợp âm & cho biết: khi bấm Đô Trưởng (C) rồi nhấc ngón trỏ khỏi Dây 2 ngăn 1 để vang Dây 2 buông (Si), ta được hợp âm gì?',
            'Thêm nốt Si (B – bậc 7 trưởng) vào hợp âm C tạo thành Đô Bảy Trưởng (Cmaj7) mang màu sắc sâu lắng.'
          ),
          (
            'guitar_chord_shape',
            'assets/audio/keys/chord_a_min7.wav',
            'GTR_CHORD_Am',
            'La Bảy Thứ (Am7 • X-0-2-0-1-0)',
            [
              ('GTR_CHORD_Cmaj7', 'Đô Bảy Trưởng (Cmaj7 • X-3-2-0-0-0)'),
              ('GTR_CHORD_G7', 'Sol Bảy Át (G7 • 3-2-0-0-0-1)'),
              ('GTR_CHORD_Em7', 'Mi Bảy Thứ (Em7 • 0-2-0-0-0-0)'),
            ],
            'Nghe hợp âm & cho biết: khi bấm La Thứ (Am) rồi nhấc ngón áp út khỏi Dây 3 ngăn 2 để vang Dây 3 buông (Sol), ta được hợp âm gì?',
            'Dây 3 buông là nốt Sol (bậc 7 thứ của La), kết hợp với La – Đô – Mi tạo thành hợp âm La Bảy Thứ (Am7).'
          ),
          (
            'guitar_chord_theory',
            'assets/audio/keys/c_major.wav',
            'GTR_THEORY_PROG_POP',
            'C – G – Am – F (Bậc I – V – vi – IV)',
            [
              ('GTR_THEORY_PROG_JAZZ', 'Dm7 – G7 – Cmaj7 (Bậc ii – V – I)'),
              ('GTR_THEORY_PROG_BLUES', 'C7 – F7 – G7 (Bậc I7 – IV7 – V7)'),
              ('GTR_THEORY_PROG_MIN', 'Am – Dm – E7 – Am (Bậc i – iv – V7 – i)'),
            ],
            'Vòng 4 hợp âm kinh điển bậc I – V – vi – IV trong giọng Đô Trưởng (vòng Canon / Pop Ballad) gồm những hợp âm nào?',
            'Trong giọng Đô Trưởng: Bậc I = C, Bậc V = G, Bậc vi = Am, Bậc IV = F.'
          ),
          (
            'guitar_chord_theory',
            'assets/audio/keys/chord_g_dom7.wav',
            'GTR_THEORY_PROG_JAZZ',
            'Dm7 – G7 – Cmaj7 (Bậc ii – V – I)',
            [
              ('GTR_THEORY_PROG_POP', 'C – G – Am – F (Bậc I – V – vi – IV)'),
              ('GTR_THEORY_PROG_ROCK', 'C – F – G – C (Bậc I – IV – V – I)'),
              ('GTR_THEORY_PROG_BALLAD', 'Am – F – C – G (Bậc vi – IV – I – V)'),
            ],
            'Trong giọng Đô Trưởng, tiến trình hòa thanh Jazz / R&B kinh điển bậc ii – V – I gồm 3 hợp âm nào?',
            'Bậc ii (Rê Bảy Thứ Dm7) → Bậc V (Sol Bảy Át G7) → giải kết về Bậc I (Đô Bảy Trưởng Cmaj7).'
          ),
          (
            'guitar_chord_theory',
            'assets/audio/keys/d_major.wav',
            'GTR_THEORY_CAPO_D',
            'Hợp âm Rê Trưởng (D Major – tăng 1 cung)',
            [
              ('GTR_THEORY_CAPO_E', 'Hợp âm Mi Trưởng (E Major – tăng 2 cung)'),
              ('GTR_THEORY_CAPO_F', 'Hợp âm Fa Trưởng (F Major – tăng 2,5 cung)'),
              ('GTR_THEORY_CAPO_G', 'Hợp âm Sol Trưởng (G Major – tăng 3,5 cung)'),
            ],
            'Khi kẹp Capo tại Ngăn 2 và bấm thế tay Đô Trưởng (C), cao độ thực tế vang lên là hợp âm nào?',
            'Mỗi ngăn Capo nâng cao độ lên 1 bán âm: Kẹp Capo ngăn 2 tăng 2 bán âm (1 cung), biến thế bấm C thành Rê Trưởng (D).'
          ),
        ];

        guitarSpecs =
            isAdvanced ? advChords : (isInter ? interChords : basicChords);
      } else if (topicId == 'topic_guitar_scales') {
        final basicScales = [
          (
            'guitar_scale_map',
            'assets/audio/notes/a2.wav',
            'GTR_SCALE_AM',
            'Ngũ cung La Thứ (Am Pentatonic: A–C–D–E–G)',
            [
              ('GTR_SCALE_C', 'Âm giai Đô Trưởng (C Major: C–D–E–F–G–A–B)'),
              ('GTR_SCALE_EM', 'Ngũ cung Mi Thứ (Em Pentatonic: E–G–A–B–D)'),
              ('GTR_SCALE_G', 'Âm giai Sol Trưởng (G Major: G–A–B–C–D–E–F#)'),
            ],
            'Quan sát Bản đồ Scale trên cần đàn (gồm 5 nốt La – Đô – Rê – Mi – Sol, Nốt Gốc màu Đỏ là La) và chọn tên Scale:',
            'Ngũ cung La Thứ (Am Pentatonic: A–C–D–E–G) gồm 5 nốt mỗi quãng tám, là bản đồ nền tảng số 1 để Solo Guitar.'
          ),
          (
            'guitar_scale_map',
            'assets/audio/notes/c3.wav',
            'GTR_SCALE_C',
            'Âm giai Đô Trưởng (C Major: C–D–E–F–G–A–B)',
            [
              ('GTR_SCALE_AM', 'Ngũ cung La Thứ (Am Pentatonic: A–C–D–E–G)'),
              ('GTR_SCALE_EM', 'Ngũ cung Mi Thứ (Em Pentatonic: E–G–A–B–D)'),
              ('GTR_SCALE_F', 'Âm giai Fa Trưởng (F Major: F–G–A–Bb–C–D–E)'),
            ],
            'Quan sát Bản đồ Scale 7 nốt tự nhiên trên cần đàn (Nốt Gốc màu Đỏ là Đô tại Dây 5 Ngăn 3) và chọn tên Scale:',
            'Âm giai Đô Trưởng (C Major) gồm 7 nốt tự nhiên (Đô–Rê–Mi–Fa–Sol–La–Si), có giọng Thứ song song là La Thứ.'
          ),
          (
            'guitar_scale_theory',
            'assets/audio/notes/a2.wav',
            'GTR_SCALE_AM',
            'Nốt Chủ âm (Root Note – Nốt Gốc của giọng)',
            [
              ('GTR_ROLE_DOM', 'Nốt Bậc 5 (Dominant – Nốt Át của giọng)'),
              ('GTR_ROLE_LEAD', 'Nốt Cảm âm (Leading Tone – Nốt dẫn bậc 7)'),
              ('GTR_ROLE_BLUE', 'Nốt Hoa mỹ (Blue Note – Nốt lướt nửa cung)'),
            ],
            'Trên Bản đồ Scale Guitar, các chấm màu Đỏ nổi bật (ghi chữ "Gốc") dùng để đánh dấu nốt nào?',
            'Nốt Chủ âm (Root Note / Nốt Gốc) là trung tâm điệu tính để mở đầu và kết câu Solo đúng giọng.'
          ),
          (
            'guitar_scale_theory',
            'assets/audio/notes/e4.wav',
            'GTR_S1_F12',
            'Ngăn 12 (Chấm đôi Inlay – cao hơn dây buông 1 quãng tám)',
            [
              ('GTR_FRET_5', 'Ngăn 5 (Chấm đơn thứ 2 – mốc so dây quãng 4)'),
              ('GTR_FRET_7', 'Ngăn 7 (Chấm đơn thứ 3 – mốc quãng 5 đúng)'),
              ('GTR_FRET_9', 'Ngăn 9 (Chấm đơn thứ 4 trên cần đàn)'),
            ],
            'Trên cần đàn Guitar, tại ngăn thứ mấy thì cả 6 dây lặp lại đúng tên nốt của 6 dây buông (E–A–D–G–B–e) cao hơn 1 quãng tám?',
            'Ngăn 12 chia đôi chiều dài dây đàn, nơi toàn bộ 6 dây lặp lại tên nốt dây buông ở quãng tám cao hơn.'
          ),
          (
            'guitar_scale_theory',
            'assets/audio/notes/c4.wav',
            'GTR_S5_F3',
            'Dây 3 • Ngăn 5 (nốt Đô chuẩn C4)',
            [
              ('GTR_POS_S4_F5', 'Dây 4 • Ngăn 5 (nốt Sol trầm G3)'),
              ('GTR_POS_S2_F3', 'Dây 2 • Ngăn 3 (nốt Rê chuẩn D4)'),
              ('GTR_POS_S3_F2', 'Dây 3 • Ngăn 2 (nốt La trầm A3)'),
            ],
            'Từ nốt Đô tại Dây 5 • Ngăn 3, áp dụng Quy tắc Quãng 8 chéo (xuống 2 dây + tiến 2 ngăn) sẽ tìm thấy nốt Đô tiếp theo ở đâu?',
            'Từ Dây 5 Ngăn 3: xuống 2 dây (về Dây 3) và tiến 2 ngăn (lên Ngăn 5) chính là nốt Đô chuẩn (C4).'
          ),
          (
            'guitar_scale_theory',
            'assets/audio/notes/g3.wav',
            'GTR_S6_F3',
            'Dây 4 • Ngăn 5 (nốt Sol trầm G3)',
            [
              ('GTR_POS_S3_F5', 'Dây 3 • Ngăn 5 (nốt Đô chuẩn C4)'),
              ('GTR_POS_S5_F5', 'Dây 5 • Ngăn 5 (nốt Rê trầm D3)'),
              ('GTR_POS_S4_F3', 'Dây 4 • Ngăn 3 (nốt Fa trầm F3)'),
            ],
            'Từ nốt Sol tại Dây 6 • Ngăn 3, áp dụng Quy tắc Quãng 8 chéo (xuống 2 dây + tiến 2 ngăn) sẽ gặp lại nốt Sol ở vị trí nào?',
            'Từ Dây 6 Ngăn 3: xuống 2 dây (về Dây 4) và tiến 2 ngăn (lên Ngăn 5) chính là nốt Sol trầm (G3).'
          ),
        ];

        final interScales = [
          ...basicScales,
          (
            'guitar_scale_map',
            'assets/audio/notes/e2.wav',
            'GTR_SCALE_EM',
            'Ngũ cung Mi Thứ (Em Pentatonic: E–G–A–B–D)',
            [
              ('GTR_SCALE_AM', 'Ngũ cung La Thứ (Am Pentatonic: A–C–D–E–G)'),
              ('GTR_SCALE_C', 'Âm giai Đô Trưởng (C Major: C–D–E–F–G–A–B)'),
              ('GTR_SCALE_DM', 'Ngũ cung Rê Thứ (Dm Pentatonic: D–F–G–A–C)'),
            ],
            'Quan sát Bản đồ Scale trên cần đàn (Nốt Gốc màu Đỏ là Mi: Mi – Sol – La – Si – Rê, tận dụng cả 5 dây buông) và chọn tên Scale:',
            'Ngũ cung Mi Thứ (Em Pentatonic: E–G–A–B–D) chứa trọn 5 dây buông của Guitar.'
          ),
          (
            'guitar_scale_theory',
            'assets/audio/notes/c4.wav',
            'GTR_S4_F3',
            'Tiến 3 ngăn (do khoảng cách Dây 3 sang Dây 2 chỉ là Quãng 3 trưởng)',
            [
              ('GTR_OCT_2', 'Tiến 2 ngăn (giống hệt như từ Dây 6 xuống Dây 4)'),
              ('GTR_OCT_1', 'Chỉ tiến 1 ngăn (do Dây 1 và Dây 2 là dây thép trơn)'),
              ('GTR_OCT_4', 'Tiến 4 ngăn (tương đương 2 cung nguyên trên cần đàn)'),
            ],
            'Khi tìm Quãng 8 chéo từ Dây 4 xuống Dây 2 (hoặc từ Dây 3 xuống Dây 1), ta cần tiến thêm mấy ngăn?',
            'Vì khoảng cách từ Dây 3 (G) sang Dây 2 (B) là Quãng 3 trưởng (hẹp hơn 1 ngăn so với Quãng 4 đúng), nên phải cộng bù thêm 1 ngăn = Tiến 3 ngăn.'
          ),
        ];

        final advScales = [
          ...interScales,
          (
            'guitar_scale_theory',
            'assets/audio/notes/b2.wav',
            'GTR_SCALE_AM',
            'Giữ nguyên hình dáng thế bấm và trượt cả bàn tay lên 2 ngăn (bắt đầu từ Ngăn 7)',
            [
              ('GTR_TRANS_DOWN2', 'Giữ nguyên thế bấm và lùi bàn tay về 2 ngăn (bắt đầu từ Ngăn 3)'),
              ('GTR_TRANS_REV', 'Đảo ngược thứ tự 4 ngón tay trái từ 1–2–3–4 thành 4–3–2–1 tại Ngăn 5'),
              ('GTR_TRANS_OPEN', 'Chỉ gảy trên 6 dây buông mà không bấm phím nào'),
            ],
            'Khi đã thuộc thế bấm Am Pentatonic ở Ngăn 5 (nốt gốc La), muốn dịch (Transpose) sang giọng Si Thứ (Bm Pentatonic) bạn làm thế nào?',
            'Từ La (Ngăn 5) lên Si (Ngăn 7) cách nhau 1 cung (2 ngăn): trên Guitar chỉ cần giữ nguyên hình thế bấm và trượt lên 2 ngăn!'
          ),
          (
            'guitar_scale_theory',
            'assets/audio/notes/c3.wav',
            'GTR_SCALE_C',
            'Hệ thống CAGED (5 thế bấm theo 5 dáng hợp âm C – A – G – E – D)',
            [
              ('GTR_SYS_SPIDER', 'Hệ thống Bò nhện Spider Walk 1–2–3–4'),
              ('GTR_SYS_PIMA', 'Hệ thống P – i – m – a (phân công 4 ngón tay phải)'),
              ('GTR_SYS_GRAND', 'Hệ thống Khóa Sol – Khóa Fa kép (Grand Staff)'),
            ],
            'Phương pháp chia toàn bộ cần đàn Guitar thành 5 khu vực nối tiếp nhau dựa theo 5 dáng hợp âm mở cơ bản gọi là gì?',
            'Hệ thống CAGED giúp người chơi nối liền hợp âm và Scale xuyên suốt từ Ngăn 0 lên Ngăn 12.'
          ),
        ];

        guitarSpecs =
            isAdvanced ? advScales : (isInter ? interScales : basicScales);
      } else {
        // topic_guitar_tabs (Đọc Tab 6 dây & Luyện ngón Spider 1-2-3-4)
        final basicTabs = [
          (
            'guitar_tab_read',
            'assets/audio/notes/g2.wav',
            'GTR_TAB_S6_F3',
            'Bấm Dây 6 (dày nhất) tại Ngăn 3',
            [
              ('GTR_TAB_S1_F3', 'Bấm Dây 1 (mỏng nhất) tại Ngăn 3'),
              ('GTR_TAB_S3_F6', 'Bấm Dây 3 tại Ngăn 6'),
              ('GTR_TAB_S6_F0', 'Gảy Dây 6 buông 3 lần liên tiếp'),
            ],
            'Quan sát số "3" nằm trên dòng kẻ dưới cùng (E|) của khuông Tab Guitar bên dưới, bạn thực hiện thao tác nào?',
            'Dòng dưới cùng (E|) của khuông Tab là Dây 6 trầm nhất; số 3 nghĩa là bấm Ngăn 3 trên Dây 6 (nốt Sol G2).'
          ),
          (
            'guitar_tab_read',
            'assets/audio/notes/c3.wav',
            'GTR_TAB_S5_F3',
            'Bấm Dây 5 (dây La) tại Ngăn 3',
            [
              ('GTR_TAB_S2_F3', 'Bấm Dây 2 (dây Si) tại Ngăn 3'),
              ('GTR_TAB_S3_F5', 'Bấm Dây 3 tại Ngăn 5'),
              ('GTR_TAB_S5_F0', 'Gảy Dây 5 buông không bấm phím'),
            ],
            'Quan sát số "3" nằm trên dòng kẻ A| (dòng thứ 2 từ dưới lên) của khuông Tab Guitar, bạn bấm ở đâu?',
            'Dòng A| đại diện cho Dây 5; số 3 nghĩa là bấm vào Ngăn 3 của Dây 5 (nốt Đô trầm C3).'
          ),
          (
            'guitar_tab_read',
            'assets/audio/notes/e4.wav',
            'GTR_TAB_S1_F0',
            'Gảy Dây 1 (mỏng nhất) buông không bấm phím',
            [
              ('GTR_TAB_S6_F0', 'Gảy Dây 6 (dày nhất) buông không bấm phím'),
              ('GTR_TAB_MUTE', 'Bịt tắt tiếng Dây 1 không được gảy'),
              ('GTR_TAB_S1_F1', 'Bấm Dây 1 tại Ngăn 1 bằng ngón trỏ'),
            ],
            'Quan sát số "0" nằm trên dòng kẻ trên cùng (e|) của khuông Tab Guitar, ký hiệu này hướng dẫn gì?',
            'Dòng trên cùng (e|) là Dây 1 mỏng nhất; số 0 nghĩa là gảy dây buông (nốt Mi E4) không bấm tay trái.'
          ),
          (
            'guitar_tab_read',
            'assets/audio/notes/d4.wav',
            'GTR_TAB_S2_F3',
            'Bấm Dây 2 (dây Si) tại Ngăn 3',
            [
              ('GTR_TAB_S5_F3', 'Bấm Dây 5 (dây La) tại Ngăn 3'),
              ('GTR_TAB_S3_F2', 'Bấm Dây 3 (dây Sol) tại Ngăn 2'),
              ('GTR_TAB_S2_F0', 'Gảy Dây 2 buông không bấm phím'),
            ],
            'Quan sát số "3" nằm trên dòng B| (dòng thứ 2 từ trên xuống) của khuông Tab Guitar, bạn thực hiện thế bấm nào?',
            'Dòng B| là Dây 2; số 3 nghĩa là bấm Ngăn 3 trên Dây 2 (nốt Rê chuẩn D4).'
          ),
          (
            'guitar_tab_theory',
            'assets/audio/notes/f2.wav',
            'GTR_TAB_SPIDER',
            'Ngón Trỏ (1) – Giữa (2) – Áp út (3) – Út (4) lần lượt trên 4 ngăn liên tiếp',
            [
              ('GTR_SPIDER_1', 'Chỉ dùng duy nhất 1 ngón trỏ trượt qua cả 4 ngăn liên tiếp'),
              ('GTR_SPIDER_THUMB', 'Dùng ngón cái tay trái bấm toàn bộ 6 dây đàn'),
              ('GTR_SPIDER_OPEN', 'Chỉ gảy các dây buông mà không cần bấm ngón tay trái'),
            ],
            'Trong bài tập luyện ngón "Bò nhện (Spider Walk 1–2–3–4)", 4 ngón tay trái được phân công như thế nào?',
            'Mỗi ngón tay trái phụ trách cố định 1 ngăn liên tiếp (Ngón 1 – 2 – 3 – 4) giúp độc lập ngón và mở rộng sải tay.'
          ),
          (
            'guitar_tab_theory',
            'assets/audio/keys/chord_c_maj.wav',
            'GTR_TAB_BALLAD_44',
            'Bass – 3 – 2 – 3 – 1 – 3 – 2 – 3 (8 nốt móc đơn đều đặn)',
            [
              ('GTR_RHY_VALSE', 'Bass – (321) – (321) theo chu kỳ 3 phách nhịp 3/4'),
              ('GTR_RHY_ALL6', 'Chỉ gảy lặp đi lặp lại duy nhất Dây 6 trầm'),
              ('GTR_RHY_MUTE', 'Đập tắt tiếng toàn bộ 6 dây trong suốt bài hát'),
            ],
            'Công thức rải dây tay phải kinh điển nhất cho điệu Ballad / Canon ở nhịp 4/4 trên Guitar là gì?',
            'Ở nhịp 4/4 Ballad: Ngón cái (P) gảy dây Bass, tiếp theo lần lượt rải Dây 3 – 2 – 3 – 1 – 3 – 2 – 3.'
          ),
        ];

        final interTabs = [
          ...basicTabs,
          (
            'guitar_tab_theory',
            'assets/audio/keys/chord_a_min.wav',
            'GTR_TAB_PIMA',
            'Ngón Cái (P: dây 4, 5, 6) • Trỏ (i: dây 3) • Giữa (m: dây 2) • Áp út (a: dây 1)',
            [
              ('GTR_PIMA_W1', 'Ngón Cái gảy dây 1 • Ngón Út gảy 3 dây Bass 4, 5, 6'),
              ('GTR_PIMA_W2', 'Chỉ dùng duy nhất ngón Trỏ gảy tất cả 6 dây từ trên xuống'),
              ('GTR_PIMA_W3', 'Ngón Áp út gảy dây 6 • Ngón Giữa gảy dây 5 • Ngón Trỏ gảy dây 4'),
            ],
            'Nguyên tắc chuẩn phân công 4 ngón tay phải (P – i – m – a) khi rải hợp âm Guitar là gì?',
            'Ngón cái (P) phụ trách 3 dây Bass (4, 5, 6); Ngón trỏ (i) gảy dây 3; Ngón giữa (m) gảy dây 2; Ngón áp út (a) gảy dây 1.'
          ),
          (
            'guitar_tab_theory',
            'assets/audio/keys/rhy_waltz_3_4.wav',
            'GTR_TAB_VALSE_34',
            'Bass – (321) – (321) hoặc Bass – 3 – (21) theo chu kỳ 3 phách',
            [
              ('GTR_VALSE_W1', 'Bass – 3 – 2 – 3 – 1 – 3 – 2 – 3 (8 nốt móc đơn nhịp 4/4)'),
              ('GTR_VALSE_W2', 'Gảy liên tiếp 4 dây Bass trong 4 phách đều nhau'),
              ('GTR_VALSE_W3', 'Chỉ quạt xuống 1 cái duy nhất rồi nghỉ hết bài'),
            ],
            'Công thức đệm tay phải đặc trưng cho nhịp 3/4 (Điệu Valse / Boston) trên Guitar là gì?',
            'Nhịp 3/4 có 3 phách (Bùm – Chát – Chát): Phách 1 gảy dây Bass, phách 2 và phách 3 móc đồng thời 3 dây treble (3-2-1).'
          ),
        ];

        final advTabs = [
          ...interTabs,
          (
            'guitar_tab_theory',
            'assets/audio/notes/g4.wav',
            'GTR_TECH_HAMMER',
            'Hammer-on (Luyến lên: Gảy nốt ngăn 5 rồi đập ngón tay trái xuống ngăn 7)',
            [
              ('GTR_TECH_PULL', 'Pull-off (Luyến xuống: Gảy ngăn 7 rồi kéo ngón nhả về ngăn 5)'),
              ('GTR_TECH_SLIDE', 'Slide (Trượt dọc ngón tay trên dây từ ngăn 5 lên ngăn 7)'),
              ('GTR_TECH_HARM', 'Harmonic (Chạm nhẹ ngón tay tạo âm bồi chuông ở ngăn 12)'),
            ],
            'Trên bản Tab Guitar, ký hiệu "5h7" hướng dẫn kỹ thuật diễn tấu nào?',
            'Chữ "h" là Hammer-on (Đập ngón luyến lên): Gảy vang ngăn 5 rồi đập nhanh ngón tay trái xuống ngăn 7.'
          ),
          (
            'guitar_tab_theory',
            'assets/audio/notes/e4.wav',
            'GTR_TECH_PULL',
            'Pull-off (Luyến xuống: Gảy ngăn 7 rồi bật nhẹ ngón nhả về ngăn 5)',
            [
              ('GTR_TECH_HAMMER', 'Hammer-on (Luyến lên: Gảy ngăn 5 rồi đập ngón xuống ngăn 7)'),
              ('GTR_TECH_SLIDE', 'Slide (Trượt ngón tay dọc dây từ ngăn 7 lên ngăn 9)'),
              ('GTR_TECH_BEND', 'Bend (Đẩy căng dây đàn lên phía trên để tăng cao độ)'),
            ],
            'Trên bản Tab Guitar, ký hiệu "7p5" hướng dẫn kỹ thuật diễn tấu nào?',
            'Chữ "p" là Pull-off (Kéo ngón luyến xuống): Gảy ngăn 7 rồi móc nhẹ ngón tay trái nhả về ngăn 5 đang giữ sẵn.'
          ),
          (
            'guitar_tab_theory',
            'assets/audio/notes/a4.wav',
            'GTR_TECH_SLIDE',
            'Slide (Trượt ngón: Gảy ngăn 5 và giữ lực miết dọc dây đàn tới ngăn 7)',
            [
              ('GTR_TECH_HAMMER', 'Hammer-on (Đập ngón tay trái không miết dây)'),
              ('GTR_TECH_PULL', 'Pull-off (Kéo ngón tay trái nhả về dây buông)'),
              ('GTR_TECH_MUTE', 'Palm Mute (Dùng cạnh bàn tay phải bịt nhẹ lên ngựa đàn)'),
            ],
            'Trên bản Tab Guitar, ký hiệu "5/7" (hoặc "5s7") biểu thị kỹ thuật nào?',
            'Dấu "/" hoặc "s" là Slide (Trượt ngón): Giữ nguyên lực bấm sau khi gảy ngăn 5 và trượt dọc dây đến ngăn 7.'
          ),
        ];

        guitarSpecs =
            isAdvanced ? advTabs : (isInter ? interTabs : basicTabs);
      }

      final passes = guitarSpecs.length < 10 ? 2 : 1;
      for (int pass = 0; pass < passes; pass++) {
        for (int i = 0; i < guitarSpecs.length; i++) {
          final (qType, audioAsset, optKey, correctLabel, wrongOpts, prompt, desc) =
              guitarSpecs[i];
          final qId = 'dyn_gtr_${topicId}_${levelId}_${i}_p$pass';

          final options = <QuestionOptionModel>[
            QuestionOptionModel(
              id: '${qId}_o1',
              questionId: qId,
              optionKey: optKey,
              label: correctLabel,
              isCorrect: true,
              sortOrder: 1,
            ),
            for (int w = 0; w < wrongOpts.length; w++)
              QuestionOptionModel(
                id: '${qId}_o${w + 2}',
                questionId: qId,
                optionKey: wrongOpts[w].$1,
                label: wrongOpts[w].$2,
                isCorrect: false,
                sortOrder: w + 2,
              ),
          ];

          generated.add(
            QuestionModel(
              id: qId,
              topicId: topicId,
              levelId: levelId,
              type: qType,
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
