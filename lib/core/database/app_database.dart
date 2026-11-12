import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/domain_models.dart';

class AppDatabase {
  static const int schemaVersion = 2;
  Database? _db;
  final String? _customPath;

  AppDatabase({String? customPath}) : _customPath = customPath;

  /// Creates an isolated in-memory database instance for automated testing.
  factory AppDatabase.inMemory() {
    return AppDatabase(customPath: inMemoryDatabasePath);
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String dbPath;
    if (_customPath != null) {
      dbPath = _customPath;
    } else {
      final folder = await getDatabasesPath();
      dbPath = p.join(folder, 'solfa_offline.db');
    }

    return openDatabase(
      dbPath,
      version: schemaVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Safe migration (TC-14): preserve existing user progress tables
        await _createTables(db);
        if (oldVersion < 2) {
          // Ensure duration_seconds column exists on practice_sessions
          try {
            await db.execute(
              'ALTER TABLE practice_sessions ADD COLUMN duration_seconds INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {
            // Column already exists
          }
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS topics (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 1,
        is_enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS levels (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        difficulty INTEGER NOT NULL DEFAULT 1,
        unlock_rule TEXT NOT NULL DEFAULT 'always_unlocked',
        FOREIGN KEY (topic_id) REFERENCES topics(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS questions (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        level_id TEXT NOT NULL,
        type TEXT NOT NULL,
        prompt TEXT NOT NULL,
        explanation TEXT NOT NULL,
        audio_asset TEXT NOT NULL,
        difficulty INTEGER NOT NULL DEFAULT 1,
        version INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (topic_id) REFERENCES topics(id),
        FOREIGN KEY (level_id) REFERENCES levels(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS question_options (
        id TEXT PRIMARY KEY,
        question_id TEXT NOT NULL,
        option_key TEXT NOT NULL,
        label TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (question_id) REFERENCES questions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS practice_sessions (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        level_id TEXT,
        mode TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        status TEXT NOT NULL,
        total_questions INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        duration_seconds INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS answers (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        selected_option_id TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        answered_at TEXT NOT NULL,
        response_ms INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES practice_sessions(id),
        FOREIGN KEY (question_id) REFERENCES questions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS review_items (
        id TEXT PRIMARY KEY,
        question_id TEXT NOT NULL UNIQUE,
        last_wrong_at TEXT NOT NULL,
        wrong_count INTEGER NOT NULL DEFAULT 1,
        correct_review_count INTEGER NOT NULL DEFAULT 0,
        review_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (question_id) REFERENCES questions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_activity (
        activity_date TEXT PRIMARY KEY,
        answered_count INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        duration_seconds INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS metronome_presets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        bpm INTEGER NOT NULL DEFAULT 100,
        numerator INTEGER NOT NULL DEFAULT 4,
        denominator INTEGER NOT NULL DEFAULT 4,
        sound_type TEXT NOT NULL DEFAULT 'click'
      )
    ''');
  }

  /// Seeds static content from assets/data/seed_content.json or provided Map.
  /// Preserves user history across content updates.
  Future<void> seedContent({Map<String, dynamic>? overrideSeedJson}) async {
    final db = await database;
    final Map<String, dynamic> data;
    if (overrideSeedJson != null) {
      data = overrideSeedJson;
    } else {
      final raw = await rootBundle.loadString('assets/data/seed_content.json');
      data = jsonDecode(raw) as Map<String, dynamic>;
    }

    await db.transaction((txn) async {
      final topics = (data['topics'] as List<dynamic>? ?? []);
      for (final t in topics) {
        final map = Map<String, dynamic>.from(t as Map);
        await txn.insert(
          'topics',
          {
            'id': map['id'],
            'code': map['code'],
            'name': map['name'],
            'description': map['description'] ?? '',
            'sort_order': map['sort_order'] ?? 1,
            'is_enabled': (map['is_enabled'] == true || map['is_enabled'] == 1) ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final levels = (data['levels'] as List<dynamic>? ?? []);
      for (final l in levels) {
        final map = Map<String, dynamic>.from(l as Map);
        await txn.insert(
          'levels',
          {
            'id': map['id'],
            'topic_id': map['topic_id'],
            'code': map['code'],
            'name': map['name'],
            'difficulty': map['difficulty'] ?? 1,
            'unlock_rule': map['unlock_rule'] ?? 'always_unlocked',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final questions = (data['questions'] as List<dynamic>? ?? []);
      for (final q in questions) {
        final qMap = Map<String, dynamic>.from(q as Map);
        final options = (qMap.remove('options') as List<dynamic>? ?? []);
        await txn.insert(
          'questions',
          {
            'id': qMap['id'],
            'topic_id': qMap['topic_id'],
            'level_id': qMap['level_id'],
            'type': qMap['type'] ?? 'listen_note',
            'prompt': qMap['prompt'],
            'explanation': qMap['explanation'] ?? '',
            'audio_asset': qMap['audio_asset'],
            'difficulty': qMap['difficulty'] ?? 1,
            'version': qMap['version'] ?? 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final opt in options) {
          final oMap = Map<String, dynamic>.from(opt as Map);
          await txn.insert(
            'question_options',
            {
              'id': oMap['id'],
              'question_id': qMap['id'],
              'option_key': oMap['option_key'],
              'label': oMap['label'],
              'is_correct': (oMap['is_correct'] == true || oMap['is_correct'] == 1) ? 1 : 0,
              'sort_order': oMap['sort_order'] ?? 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final presets = (data['metronome_presets'] as List<dynamic>? ?? []);
      for (final pItem in presets) {
        final pMap = Map<String, dynamic>.from(pItem as Map);
        await txn.insert(
          'metronome_presets',
          pMap,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Inserts or updates a dynamically generated question so that it has a valid FK for answers & review_items.
  Future<void> upsertQuestion(QuestionModel question) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'questions',
        question.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final opt in question.options) {
        await txn.insert(
          'question_options',
          opt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<TopicModel>> getTopics({bool onlyEnabled = false}) async {
    final db = await database;
    final rows = await db.query(
      'topics',
      where: onlyEnabled ? 'is_enabled = 1' : null,
      orderBy: 'sort_order ASC',
    );
    return rows.map(TopicModel.fromMap).toList();
  }

  Future<List<LevelModel>> getLevelsByTopic(String topicId) async {
    final db = await database;
    final rows = await db.query(
      'levels',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'difficulty ASC',
    );
    return rows.map(LevelModel.fromMap).toList();
  }

  /// Checks if a level is unlocked based on completed sessions with >= 70% accuracy,
  /// or if manual unlock setting is enabled.
  Future<bool> isLevelUnlocked(LevelModel level) async {
    if (level.difficulty <= 1 || level.unlockRule == 'always_unlocked') {
      return true;
    }
    final unlockAll = await getSetting('unlock_all_levels');
    if (unlockAll == 'true') return true;

    final db = await database;
    final prevDiff = level.difficulty - 1;
    final prevLevels = await db.query(
      'levels',
      where: 'topic_id = ? AND difficulty = ?',
      whereArgs: [level.topicId, prevDiff],
    );
    if (prevLevels.isEmpty) return true;
    final prevLevelId = prevLevels.first['id'] as String;

    final sessions = await db.query(
      'practice_sessions',
      where: "topic_id = ? AND level_id = ? AND status = 'completed' AND total_questions > 0",
      whereArgs: [level.topicId, prevLevelId],
    );
    int qualifyingCount = 0;
    for (final s in sessions) {
      final total = (s['total_questions'] as num?)?.toInt() ?? 0;
      final correct = (s['correct_count'] as num?)?.toInt() ?? 0;
      if (total > 0 && (correct / total) >= 0.70) {
        qualifyingCount++;
      }
    }
    return qualifyingCount >= 2;
  }

  Future<List<QuestionModel>> getQuestions({
    required String topicId,
    String? levelId,
  }) async {
    final db = await database;
    final qRows = await db.query(
      'questions',
      where: levelId != null ? 'topic_id = ? AND level_id = ?' : 'topic_id = ?',
      whereArgs: levelId != null ? [topicId, levelId] : [topicId],
    );
    final List<QuestionModel> result = [];
    for (final qRow in qRows) {
      final qId = qRow['id'] as String;
      final optRows = await db.query(
        'question_options',
        where: 'question_id = ?',
        whereArgs: [qId],
        orderBy: 'sort_order ASC',
      );
      final options = optRows.map(QuestionOptionModel.fromMap).toList();
      if (options.isNotEmpty) {
        result.add(QuestionModel.fromMap(qRow, options: options));
      }
    }
    return result;
  }

  Future<QuestionModel?> getQuestionById(String questionId) async {
    final db = await database;
    final qRows = await db.query(
      'questions',
      where: 'id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    if (qRows.isEmpty) return null;
    final optRows = await db.query(
      'question_options',
      where: 'question_id = ?',
      whereArgs: [questionId],
      orderBy: 'sort_order ASC',
    );
    final options = optRows.map(QuestionOptionModel.fromMap).toList();
    return QuestionModel.fromMap(qRows.first, options: options);
  }

  /// Creates an in_progress session at the start of practice (BR-07).
  Future<void> createPracticeSession({
    required String sessionId,
    required String topicId,
    String? levelId,
    required String mode,
    required int totalQuestions,
    DateTime? startedAt,
  }) async {
    final db = await database;
    await db.insert(
      'practice_sessions',
      {
        'id': sessionId,
        'topic_id': topicId,
        'level_id': levelId,
        'mode': mode,
        'started_at': (startedAt ?? DateTime.now()).toIso8601String(),
        'ended_at': null,
        'status': 'in_progress',
        'total_questions': totalQuestions,
        'correct_count': 0,
        'duration_seconds': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marks an unfinished session as abandoned if the user exits early (BR-07).
  Future<void> abandonSession(String sessionId) async {
    final db = await database;
    await db.update(
      'practice_sessions',
      {
        'status': 'abandoned',
        'ended_at': DateTime.now().toIso8601String(),
      },
      where: "id = ? AND status = 'in_progress'",
      whereArgs: [sessionId],
    );
  }

  /// Completes a practice or review session atomically inside a SQLite transaction (NFR-03, BR-05, Decision #4).
  Future<void> completeSessionTransaction({
    required String sessionId,
    required String mode, // 'quick', 'topic', 'review'
    required List<AnswerModel> answers,
    required int activeDurationSeconds,
    DateTime? completedAt,
  }) async {
    final db = await database;
    final now = completedAt ?? DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final correctCount = answers.where((a) => a.isCorrect).length;

    await db.transaction((txn) async {
      // 1. Update practice_sessions
      await txn.update(
        'practice_sessions',
        {
          'ended_at': now.toIso8601String(),
          'status': 'completed',
          'total_questions': answers.length,
          'correct_count': correctCount,
          'duration_seconds': activeDurationSeconds,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      // 2. Insert each answer & update review_items
      for (final ans in answers) {
        await txn.insert(
          'answers',
          ans.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final existingReview = await txn.query(
          'review_items',
          where: 'question_id = ?',
          whereArgs: [ans.questionId],
          limit: 1,
        );

        if (!ans.isCorrect) {
          // Wrong answer -> add to review_items or reset consecutive correct counter to 0
          if (existingReview.isEmpty) {
            await txn.insert('review_items', {
              'id': 'rev_${ans.questionId}',
              'question_id': ans.questionId,
              'last_wrong_at': now.toIso8601String(),
              'wrong_count': 1,
              'correct_review_count': 0,
              'review_status': 'pending',
            });
          } else {
            final prevWrong = (existingReview.first['wrong_count'] as num?)?.toInt() ?? 1;
            await txn.update(
              'review_items',
              {
                'last_wrong_at': now.toIso8601String(),
                'wrong_count': prevWrong + 1,
                'correct_review_count': 0,
                'review_status': 'pending',
              },
              where: 'question_id = ?',
              whereArgs: [ans.questionId],
            );
          }
        } else if (mode == 'review' && existingReview.isNotEmpty) {
          // Correct answer in a Review session -> increment consecutive correct count
          // Decision #4: Only mark 'mastered' after 2 consecutive correct answers in review
          final prevCorrect =
              (existingReview.first['correct_review_count'] as num?)?.toInt() ?? 0;
          final nextCorrect = prevCorrect + 1;
          final nextStatus =
              nextCorrect >= ReviewItemModel.requiredConsecutiveCorrect
                  ? 'mastered'
                  : 'pending';
          await txn.update(
            'review_items',
            {
              'correct_review_count': nextCorrect,
              'review_status': nextStatus,
            },
            where: 'question_id = ?',
            whereArgs: [ans.questionId],
          );
        }
      }

      // 3. Upsert daily_activity
      final existingDaily = await txn.query(
        'daily_activity',
        where: 'activity_date = ?',
        whereArgs: [dateKey],
        limit: 1,
      );
      if (existingDaily.isEmpty) {
        await txn.insert('daily_activity', {
          'activity_date': dateKey,
          'answered_count': answers.length,
          'correct_count': correctCount,
          'duration_seconds': activeDurationSeconds,
        });
      } else {
        final prevAns = (existingDaily.first['answered_count'] as num?)?.toInt() ?? 0;
        final prevCor = (existingDaily.first['correct_count'] as num?)?.toInt() ?? 0;
        final prevDur = (existingDaily.first['duration_seconds'] as num?)?.toInt() ?? 0;
        await txn.update(
          'daily_activity',
          {
            'answered_count': prevAns + answers.length,
            'correct_count': prevCor + correctCount,
            'duration_seconds': prevDur + activeDurationSeconds,
          },
          where: 'activity_date = ?',
          whereArgs: [dateKey],
        );
      }
    });
  }

  /// Retrieves pending review items, optionally filtered by topicId.
  Future<List<ReviewItemModel>> getPendingReviewItems({String? topicId}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.*, q.topic_id, t.name AS topic_name
      FROM review_items r
      INNER JOIN questions q ON q.id = r.question_id
      INNER JOIN topics t ON t.id = q.topic_id
      WHERE r.review_status = 'pending'
      ${topicId != null ? 'AND q.topic_id = ?' : ''}
      ORDER BY r.wrong_count DESC, r.last_wrong_at DESC
    ''', topicId != null ? [topicId] : []);

    final List<ReviewItemModel> items = [];
    for (final row in rows) {
      final qId = row['question_id'] as String;
      final qModel = await getQuestionById(qId);
      if (qModel != null) {
        items.add(
          ReviewItemModel.fromMap(
            row,
            question: qModel,
            topicName: row['topic_name'] as String?,
          ),
        );
      }
    }
    return items;
  }

  /// Calculates comprehensive progress statistics (UC-13).
  Future<OverallProgressStats> getOverallProgressStats() async {
    final db = await database;

    final totalsRow = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_questions), 0) AS total_answered,
        COALESCE(SUM(correct_count), 0) AS total_correct,
        COALESCE(SUM(duration_seconds), 0) AS total_duration
      FROM practice_sessions
      WHERE status = 'completed'
    ''');

    final totalAnswered = (totalsRow.first['total_answered'] as num?)?.toInt() ?? 0;
    final totalCorrect = (totalsRow.first['total_correct'] as num?)?.toInt() ?? 0;
    final totalDuration = (totalsRow.first['total_duration'] as num?)?.toInt() ?? 0;

    final pendingRows = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM review_items WHERE review_status = 'pending'
    ''');
    final pendingCount = (pendingRows.first['cnt'] as num?)?.toInt() ?? 0;

    // Accuracy per enabled topic
    final topicRows = await db.rawQuery('''
      SELECT
        t.id AS topic_id,
        t.name AS topic_name,
        COUNT(a.id) AS answered_cnt,
        COALESCE(SUM(CASE WHEN a.is_correct = 1 THEN 1 ELSE 0 END), 0) AS correct_cnt,
        (
          SELECT COUNT(*)
          FROM practice_sessions ps
          WHERE ps.topic_id = t.id AND ps.status = 'completed'
        ) AS session_cnt
      FROM topics t
      LEFT JOIN questions q ON q.topic_id = t.id
      LEFT JOIN answers a ON a.question_id = q.id
      LEFT JOIN practice_sessions s ON s.id = a.session_id AND s.status = 'completed'
      WHERE t.is_enabled = 1
      GROUP BY t.id, t.name
      ORDER BY t.sort_order ASC
    ''');

    final topicStats = topicRows.map((r) {
      return TopicAccuracyStat(
        topicId: r['topic_id'] as String,
        topicName: r['topic_name'] as String,
        totalAnswered: (r['answered_cnt'] as num?)?.toInt() ?? 0,
        correctCount: (r['correct_cnt'] as num?)?.toInt() ?? 0,
        completedSessions: (r['session_cnt'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // Recent completed sessions
    final sessionRows = await db.rawQuery('''
      SELECT ps.*, t.name AS topic_name, l.name AS level_name
      FROM practice_sessions ps
      LEFT JOIN topics t ON t.id = ps.topic_id
      LEFT JOIN levels l ON l.id = ps.level_id
      WHERE ps.status = 'completed'
      ORDER BY ps.started_at DESC
      LIMIT 30
    ''');
    final recentSessions = sessionRows.map(PracticeSessionModel.fromMap).toList();

    // Daily activities & Streak calculation
    final dailyRows = await db.query(
      'daily_activity',
      where: 'answered_count > 0',
      orderBy: 'activity_date DESC',
      limit: 30,
    );
    final dailyList = dailyRows.map(DailyActivityModel.fromMap).toList();
    final streak = _calculateStreakDays(dailyList);

    return OverallProgressStats(
      totalAnswered: totalAnswered,
      totalCorrect: totalCorrect,
      totalDurationSeconds: totalDuration,
      currentStreakDays: streak,
      pendingReviewCount: pendingCount,
      topicStats: topicStats,
      recentSessions: recentSessions,
      dailyActivities: dailyList,
    );
  }

  int _calculateStreakDays(List<DailyActivityModel> sortedDescActivities) {
    if (sortedDescActivities.isEmpty) return 0;
    final activeDates = sortedDescActivities.map((d) => d.activityDate).toSet();
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayKey =
        DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));

    DateTime cursor;
    if (activeDates.contains(todayKey)) {
      cursor = today;
    } else if (activeDates.contains(yesterdayKey)) {
      cursor = today.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    int streak = 0;
    while (true) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      if (activeDates.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // Settings helpers
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    return {
      for (final r in rows) (r['key'] as String): (r['value'] as String),
    };
  }

  // Metronome Presets
  Future<List<MetronomePresetModel>> getMetronomePresets() async {
    final db = await database;
    final rows = await db.query('metronome_presets', orderBy: 'bpm ASC');
    return rows.map(MetronomePresetModel.fromMap).toList();
  }

  Future<void> saveMetronomePreset(MetronomePresetModel preset) async {
    final db = await database;
    await db.insert(
      'metronome_presets',
      preset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMetronomePreset(String id) async {
    final db = await database;
    await db.delete('metronome_presets', where: 'id = ?', whereArgs: [id]);
  }

  /// Clears user learning history while keeping topics, levels, seed questions, and app settings (BR-14).
  Future<void> clearLearningHistory() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('answers');
      await txn.delete('practice_sessions');
      await txn.delete('review_items');
      await txn.delete('daily_activity');
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

