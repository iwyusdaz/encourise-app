import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/learning_models.dart';

String _quizCacheId(
  String subject,
  String topicId,
  int grade,
  QuizQuestion question,
) {
  final source = [
    subject,
    topicId,
    grade,
    question.type,
    question.prompt,
    question.options.join('|'),
    question.acceptedAnswers.join('|'),
  ].join('::');
  return 'quiz_${source.hashCode.abs()}';
}

String questionJsonEncode(QuizQuestion question) =>
    jsonEncode(question.toJson());

QuizQuestion? questionJsonDecode(String raw, {required String topic}) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return QuizQuestion.fromJson(decoded, index: 0, topic: topic);
    }
  } catch (_) {}
  return null;
}

/// Singleton service for all on-device SQLite operations.
///
/// Tables are created automatically on first launch. All data stays
/// on-device until explicitly synced via the sync queue.
class DatabaseService {
  DatabaseService._();

  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();

  Database? _db;

  /// Returns the open database, creating tables on first access.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/encourise.db';

    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        grade          INTEGER NOT NULL,
        language       TEXT NOT NULL DEFAULT 'id',
        teaching_style TEXT NOT NULL DEFAULT 'encouraging',
        created_at     TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE topic_progress (
        student_id    TEXT NOT NULL,
        topic_id      TEXT NOT NULL,
        status        TEXT NOT NULL DEFAULT 'not_started',
        current_level INTEGER NOT NULL DEFAULT 1,
        accuracy      REAL NOT NULL DEFAULT 0.0,
        attempts      INTEGER NOT NULL DEFAULT 0,
        mastered_at   TEXT,
        PRIMARY KEY (student_id, topic_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id                TEXT PRIMARY KEY,
        student_id        TEXT NOT NULL,
        topic_id          TEXT NOT NULL,
        started_at        TEXT NOT NULL,
        ended_at          TEXT,
        questions         INTEGER NOT NULL DEFAULT 0,
        correct           INTEGER NOT NULL DEFAULT 0,
        xp_earned         INTEGER NOT NULL DEFAULT 0,
        mode              TEXT NOT NULL DEFAULT 'tutoring',
        conversation_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id           TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        created_at   TEXT NOT NULL,
        retry_count  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE learner_memory (
        student_id   TEXT PRIMARY KEY,
        summary_text TEXT NOT NULL DEFAULT '',
        profile_json TEXT NOT NULL DEFAULT '{}',
        updated_at   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id           TEXT PRIMARY KEY,
        student_id   TEXT NOT NULL,
        topic_id     TEXT NOT NULL,
        skill_tag    TEXT,
        content_text TEXT NOT NULL,
        created_at   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE guided_sessions (
        id           TEXT PRIMARY KEY,
        student_id   TEXT NOT NULL,
        topic_id     TEXT NOT NULL,
        steps_json   TEXT NOT NULL DEFAULT '[]',
        current_step INTEGER NOT NULL DEFAULT 0,
        status       TEXT NOT NULL DEFAULT 'in_progress',
        started_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      )
    ''');

    await _createIntelligenceTables(db);
    await _createTanyaTables(db);
    await _createQuizCacheTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to existing tables
      await db.execute(
        "ALTER TABLE students ADD COLUMN teaching_style TEXT NOT NULL DEFAULT 'encouraging'",
      );
      await db.execute(
        "ALTER TABLE sessions ADD COLUMN mode TEXT NOT NULL DEFAULT 'tutoring'",
      );
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN conversation_json TEXT',
      );

      // Create new tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS learner_memory (
          student_id   TEXT PRIMARY KEY,
          summary_text TEXT NOT NULL DEFAULT '',
          profile_json TEXT NOT NULL DEFAULT '{}',
          updated_at   TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS notes (
          id           TEXT PRIMARY KEY,
          student_id   TEXT NOT NULL,
          topic_id     TEXT NOT NULL,
          skill_tag    TEXT,
          content_text TEXT NOT NULL,
          created_at   TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS guided_sessions (
          id           TEXT PRIMARY KEY,
          student_id   TEXT NOT NULL,
          topic_id     TEXT NOT NULL,
          steps_json   TEXT NOT NULL DEFAULT '[]',
          current_step INTEGER NOT NULL DEFAULT 0,
          status       TEXT NOT NULL DEFAULT 'in_progress',
          started_at   TEXT NOT NULL,
          updated_at   TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await _createIntelligenceTables(db);
      await _safeAddColumn(db, 'notes', 'skill_tag TEXT');
    }

    if (oldVersion < 4) {
      await _createTanyaTables(db);
    }

    if (oldVersion < 5) {
      await _createQuizCacheTables(db);
    }
  }

  Future<void> _createIntelligenceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS skill_mastery (
        student_id          TEXT NOT NULL,
        topic_id            TEXT NOT NULL,
        skill_tag           TEXT NOT NULL,
        attempts            INTEGER NOT NULL DEFAULT 0,
        correct             INTEGER NOT NULL DEFAULT 0,
        hint_count          INTEGER NOT NULL DEFAULT 0,
        mastery_score       REAL NOT NULL DEFAULT 0.0,
        last_practiced_at   TEXT NOT NULL,
        updated_at          TEXT NOT NULL,
        PRIMARY KEY (student_id, topic_id, skill_tag)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS model_status (
        key        TEXT PRIMARY KEY,
        value      TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTanyaTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tanya_sessions (
        id                TEXT PRIMARY KEY,
        student_id        TEXT NOT NULL,
        title             TEXT NOT NULL DEFAULT 'Tanya Budi',
        summary           TEXT NOT NULL DEFAULT '',
        conversation_json TEXT NOT NULL DEFAULT '[]',
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createQuizCacheTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_question_cache (
        id             TEXT PRIMARY KEY,
        subject        TEXT NOT NULL,
        topic_id       TEXT NOT NULL,
        grade          INTEGER NOT NULL,
        difficulty     INTEGER NOT NULL DEFAULT 1,
        skill_tag      TEXT NOT NULL DEFAULT 'general',
        question_json  TEXT NOT NULL,
        created_at     TEXT NOT NULL,
        last_used_at   TEXT NOT NULL,
        use_count      INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_quiz_cache_lookup
      ON quiz_question_cache(subject, topic_id, grade, difficulty, skill_tag)
    ''');
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String columnSql,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {}
  }

  // -----------------------------------------------------------------------
  // Students
  // -----------------------------------------------------------------------

  /// Inserts or replaces a student record.
  Future<void> saveStudent(Map<String, dynamic> student) async {
    final db = await database;
    await db.insert(
      'students',
      student,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the first student found, or `null` if none exist.
  ///
  /// On a single-user device there is typically one student row.
  Future<Map<String, dynamic>?> getStudent() async {
    final db = await database;
    final rows = await db.query('students', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // -----------------------------------------------------------------------
  // Topic progress
  // -----------------------------------------------------------------------

  /// Inserts or updates progress for a specific topic.
  Future<void> upsertTopicProgress(Map<String, dynamic> progress) async {
    final db = await database;
    await db.insert(
      'topic_progress',
      progress,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all topic progress rows for the given [studentId].
  Future<List<Map<String, dynamic>>> getTopicProgress(String studentId) async {
    final db = await database;
    return db.query(
      'topic_progress',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  // -----------------------------------------------------------------------
  // Sessions
  // -----------------------------------------------------------------------

  /// Saves a completed (or in-progress) tutoring session.
  Future<void> saveSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all sessions for [studentId], most recent first.
  Future<List<Map<String, dynamic>>> getSessionHistory(String studentId) async {
    final db = await database;
    return db.query(
      'sessions',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'started_at DESC',
    );
  }

  // -----------------------------------------------------------------------
  // Tanya sessions
  // -----------------------------------------------------------------------

  Future<void> saveTanyaSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert(
      'tanya_sessions',
      session,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTanyaSessions(String studentId) async {
    final db = await database;
    return db.query(
      'tanya_sessions',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getTanyaSession(String id) async {
    final db = await database;
    final rows = await db.query(
      'tanya_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteTanyaSession(String id) async {
    final db = await database;
    await db.delete('tanya_sessions', where: 'id = ?', whereArgs: [id]);
  }

  // -----------------------------------------------------------------------
  // Sync queue
  // -----------------------------------------------------------------------

  /// Adds an item to the offline sync queue.
  ///
  /// The [item] map must include `id`, `payload_json`, and `created_at`.
  Future<void> addToSyncQueue(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all pending sync items ordered by creation date.
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<Map<String, int>> getSyncQueueSummary() async {
    final queue = await getSyncQueue();
    var highestRetry = 0;
    for (final item in queue) {
      final retry = item['retry_count'] as int? ?? 0;
      if (retry > highestRetry) highestRetry = retry;
    }
    return {'pending': queue.length, 'highestRetry': highestRetry};
  }

  /// Removes a successfully synced item from the queue.
  Future<void> markSynced(String id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Persists a failed sync attempt for later retry.
  Future<void> incrementSyncRetry(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'sync_queue',
      columns: ['retry_count'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final retryCount = (rows.first['retry_count'] as int? ?? 0) + 1;
    await db.update(
      'sync_queue',
      {'retry_count': retryCount, 'created_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -----------------------------------------------------------------------
  // Skill mastery
  // -----------------------------------------------------------------------

  Future<LearnerSkillMastery?> getSkillMastery(
    String studentId,
    String topicId,
    String skillTag,
  ) async {
    final db = await database;
    final rows = await db.query(
      'skill_mastery',
      where: 'student_id = ? AND topic_id = ? AND skill_tag = ?',
      whereArgs: [studentId, topicId, normalizeSkillTag(skillTag)],
      limit: 1,
    );
    return rows.isEmpty ? null : LearnerSkillMastery.fromRow(rows.first);
  }

  Future<List<LearnerSkillMastery>> getReviewSkills(
    String studentId, {
    int limit = 3,
  }) async {
    final db = await database;
    final rows = await db.query(
      'skill_mastery',
      where: 'student_id = ? AND attempts > 0 AND mastery_score < ?',
      whereArgs: [studentId, 0.65],
      orderBy: 'mastery_score ASC, updated_at DESC',
      limit: limit,
    );
    return rows.map(LearnerSkillMastery.fromRow).toList();
  }

  Future<LearnerSkillMastery> recordSkillAttempt({
    required String studentId,
    required String topicId,
    required String skillTag,
    required bool isCorrect,
    bool hintUsed = false,
  }) async {
    final db = await database;
    final normalizedSkill = normalizeSkillTag(skillTag);
    final now = DateTime.now().toIso8601String();
    final existing = await getSkillMastery(studentId, topicId, normalizedSkill);

    final attempts = (existing?.attempts ?? 0) + 1;
    final correct = (existing?.correct ?? 0) + (isCorrect ? 1 : 0);
    final hintCount = (existing?.hintCount ?? 0) + (hintUsed ? 1 : 0);
    final accuracy = attempts == 0 ? 0.0 : correct / attempts;
    final hintPenalty = (hintCount / attempts).clamp(0.0, 1.0) * 0.20;
    final masteryScore = (accuracy - hintPenalty).clamp(0.0, 1.0);

    final row = {
      'student_id': studentId,
      'topic_id': topicId,
      'skill_tag': normalizedSkill,
      'attempts': attempts,
      'correct': correct,
      'hint_count': hintCount,
      'mastery_score': masteryScore,
      'last_practiced_at': now,
      'updated_at': now,
    };

    await db.insert(
      'skill_mastery',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return LearnerSkillMastery.fromRow(row);
  }

  // -----------------------------------------------------------------------
  // Model status
  // -----------------------------------------------------------------------

  Future<void> saveModelStatus(String key, String value) async {
    final db = await database;
    await db.insert('model_status', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getModelStatus() async {
    final db = await database;
    final rows = await db.query('model_status');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  // -----------------------------------------------------------------------
  // Quiz question cache
  // -----------------------------------------------------------------------

  Future<void> saveQuizQuestionsToCache({
    required String subject,
    required String topicId,
    required int grade,
    required List<QuizQuestion> questions,
  }) async {
    if (questions.isEmpty) return;
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final question in questions) {
      batch.insert('quiz_question_cache', {
        'id': _quizCacheId(subject, topicId, grade, question),
        'subject': subject,
        'topic_id': topicId,
        'grade': grade,
        'difficulty': question.difficulty,
        'skill_tag': normalizeSkillTag(question.skillTag),
        'question_json': questionJsonEncode(question),
        'created_at': now,
        'last_used_at': now,
        'use_count': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<QuizQuestion?> getCachedQuizQuestion({
    required String subject,
    required String topicId,
    required int grade,
    required int difficulty,
    List<String> preferredSkillTags = const [],
    Set<String> excludeIds = const {},
    Set<String> excludePrompts = const {},
  }) async {
    final db = await database;
    final normalizedSkills = preferredSkillTags
        .map(normalizeSkillTag)
        .where((skill) => skill.trim().isNotEmpty)
        .toSet()
        .toList();

    Future<List<Map<String, dynamic>>> query({String? skillTag}) {
      final where = [
        'subject = ?',
        'topic_id = ?',
        'grade = ?',
        'difficulty <= ?',
        if (skillTag != null) 'skill_tag = ?',
      ].join(' AND ');
      return db.query(
        'quiz_question_cache',
        where: where,
        whereArgs: [subject, topicId, grade, difficulty.clamp(1, 3), ?skillTag],
        orderBy: 'use_count ASC, last_used_at ASC',
        limit: 12,
      );
    }

    final rows = <Map<String, dynamic>>[];
    for (final skill in normalizedSkills) {
      rows.addAll(await query(skillTag: skill));
    }
    rows.addAll(await query());

    for (final row in rows) {
      final raw = row['question_json'] as String? ?? '';
      final question = questionJsonDecode(raw, topic: topicId);
      if (question == null ||
          excludeIds.contains(question.id) ||
          excludePrompts.contains(question.prompt.trim())) {
        continue;
      }
      final now = DateTime.now().toIso8601String();
      await db.update(
        'quiz_question_cache',
        {'last_used_at': now, 'use_count': (row['use_count'] as int? ?? 0) + 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      return question;
    }
    return null;
  }

  Future<int> getQuizCacheCount({
    required String subject,
    required String topicId,
    required int grade,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM quiz_question_cache
      WHERE subject = ? AND topic_id = ? AND grade = ?
      ''',
      [subject, topicId, grade],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // -----------------------------------------------------------------------
  // Teaching style
  // -----------------------------------------------------------------------

  /// Updates the student's preferred teaching style.
  Future<void> updateTeachingStyle(String studentId, String style) async {
    final db = await database;
    await db.update(
      'students',
      {'teaching_style': style},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  // -----------------------------------------------------------------------
  // Learner memory
  // -----------------------------------------------------------------------

  /// Returns the learner memory for the given [studentId], or `null`.
  Future<Map<String, dynamic>?> getLearnerMemory(String studentId) async {
    final db = await database;
    final rows = await db.query(
      'learner_memory',
      where: 'student_id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts or replaces the learner memory record.
  Future<void> saveLearnerMemory(Map<String, dynamic> memory) async {
    final db = await database;
    await db.insert(
      'learner_memory',
      memory,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // -----------------------------------------------------------------------
  // Notes
  // -----------------------------------------------------------------------

  /// Saves a student note.
  Future<void> saveNote(Map<String, dynamic> note) async {
    final db = await database;
    await db.insert(
      'notes',
      note,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all notes for [studentId], newest first.
  Future<List<Map<String, dynamic>>> getNotes(String studentId) async {
    final db = await database;
    return db.query(
      'notes',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
  }

  /// Deletes a note by [id].
  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // -----------------------------------------------------------------------
  // Guided sessions
  // -----------------------------------------------------------------------

  /// Saves or updates a guided learning session.
  Future<void> saveGuidedSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert(
      'guided_sessions',
      session,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns a specific guided session by [id].
  Future<Map<String, dynamic>?> getGuidedSession(String id) async {
    final db = await database;
    final rows = await db.query(
      'guided_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Returns any in-progress guided session for this student + topic.
  /// If [topicId] is empty, returns the most recent open session regardless of topic.
  Future<Map<String, dynamic>?> getOpenGuidedSession(
    String studentId,
    String topicId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> rows;
    if (topicId.isEmpty) {
      rows = await db.query(
        'guided_sessions',
        where: "student_id = ? AND status = 'in_progress'",
        whereArgs: [studentId],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
    } else {
      rows = await db.query(
        'guided_sessions',
        where: "student_id = ? AND topic_id = ? AND status = 'in_progress'",
        whereArgs: [studentId, topicId],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
    }
    return rows.isEmpty ? null : rows.first;
  }

  /// Returns all in-progress guided sessions for this student.
  Future<List<Map<String, dynamic>>> getAllOpenGuidedSessions(
    String studentId,
  ) async {
    final db = await database;
    return db.query(
      'guided_sessions',
      where: "student_id = ? AND status = 'in_progress'",
      whereArgs: [studentId],
      orderBy: 'updated_at DESC',
    );
  }

  // -----------------------------------------------------------------------
  // Conversation persistence (session continuity)
  // -----------------------------------------------------------------------

  /// Saves conversation JSON to an existing session row.
  Future<void> saveConversation(String sessionId, String json) async {
    final db = await database;
    await db.update(
      'sessions',
      {'conversation_json': json},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // -----------------------------------------------------------------------
  // Maintenance
  // -----------------------------------------------------------------------

  /// Deletes all data from every table. Requires explicit confirmation
  /// in the UI before calling.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('sync_queue');
    await db.delete('sessions');
    await db.delete('topic_progress');
    await db.delete('learner_memory');
    await db.delete('notes');
    await db.delete('guided_sessions');
    await db.delete('tanya_sessions');
    await db.delete('quiz_question_cache');
    await db.delete('students');
  }
}
