import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:encourise_mobile/models/learning_models.dart';
import 'package:encourise_mobile/services/database_service.dart';
import 'package:encourise_mobile/services/difficulty_adapter.dart';
import 'package:encourise_mobile/services/model_loader.dart';
import 'package:encourise_mobile/services/session_manager.dart';
import 'package:encourise_mobile/services/structured_tutor_service.dart';
import 'package:encourise_mobile/utils/answer_quality.dart';
import 'package:encourise_mobile/utils/prompt_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Structured tutor parsing', () {
    test('parses tutor turn JSON from fenced model output', () {
      final decoded = StructuredTutorService.decodeLooseJson('''
```json
{"is_correct":false,"confidence":0.7,"feedback":"Hampir benar","hint":"Samakan penyebut","next_question":"Apa penyebutnya?","skill_tag":"pecahan","difficulty":2,"should_advance":false}
```
''');

      expect(decoded, isA<Map<String, dynamic>>());
      final result = TutorTurnResult.fromJson(
        decoded! as Map<String, dynamic>,
        rawResponse: 'raw',
      );
      expect(result.isCorrect, isFalse);
      expect(result.hint, contains('penyebut'));
      expect(result.skillTag, 'pecahan');
    });

    test('parses partial and unclear tutor statuses without correctness', () {
      final partial = TutorTurnResult.fromJson({
        'status': 'partial',
        'feedback': 'Sebagian benar.',
        'hint': 'Tambahkan contoh.',
        'next_question': 'Coba beri contoh.',
        'skill_tag': 'pecahan',
      });
      final unclear = TutorTurnResult.fromJson({
        'status': 'unclear',
        'feedback': 'Belum cukup jelas.',
        'next_question': 'Tulis ulang lebih lengkap.',
      });

      expect(partial.status, 'partial');
      expect(partial.isCorrect, isFalse);
      expect(unclear.status, 'unclear');
      expect(unclear.isCorrect, isFalse);
    });

    test('parses quiz questions and normalizes answer key', () {
      final decoded = StructuredTutorService.decodeLooseJson('''
{"questions":[{"prompt":"1/2 artinya?","options":["satu dari dua","dua dari satu","nol","semua"],"correct_index":0,"explanation":"1/2 berarti satu dari dua bagian.","skill_tag":"arti pecahan","difficulty":1}]}
''');

      final questions = QuizQuestion.listFromJson(
        decoded,
        topic: 'Pecahan',
        desiredCount: 5,
      );
      expect(questions, hasLength(1));
      expect(questions.first.correctIndex, 0);
      expect(questions.first.skillTag, 'arti_pecahan');
    });

    test('parses objective fill blank quiz questions', () {
      final decoded = StructuredTutorService.decodeLooseJson('''
{"questions":[{"type":"fill_blank","prompt":"3/8 berarti 3 dari ... bagian.","accepted_answers":["8","delapan"],"explanation":"Penyebut 8 menunjukkan total bagian.","skill_tag":"arti pecahan","difficulty":1}]}
''');

      final questions = QuizQuestion.listFromJson(
        decoded,
        topic: 'Pecahan',
        desiredCount: 1,
      );

      expect(questions, hasLength(1));
      expect(questions.first.type, 'fill_blank');
      expect(questions.first.acceptedAnswers, contains('delapan'));
      expect(questions.first.isValidObjective, isTrue);
    });

    test('parses compact tutor and quiz JSON for faster local generation', () {
      final result = TutorTurnResult.fromJson({
        's': 'partial',
        'c': false,
        'conf': 0.7,
        'f': 'Sebagian benar.',
        'h': 'Tambahkan contoh.',
        'n': 'Apa contohnya?',
        'skill': 'pecahan',
        'd': 1,
        'adv': false,
      });
      final decoded = StructuredTutorService.decodeLooseJson('''
{"questions":[{"id":"q1","t":"mc","q":"2+3=?","o":["4","5","6","7"],"a":1,"ans":[],"ex":"2+3=5.","skill":"penjumlahan","d":1}]}
''');
      final questions = QuizQuestion.listFromJson(
        decoded,
        topic: 'Penjumlahan',
        desiredCount: 1,
      );

      expect(result.status, 'partial');
      expect(result.feedback, 'Sebagian benar.');
      expect(questions, hasLength(1));
      expect(questions.first.prompt, '2+3=?');
      expect(questions.first.correctIndex, 1);
      expect(questions.first.skillTag, 'penjumlahan');
    });

    test(
      'repairs simple integer arithmetic answer keys from generated quiz',
      () {
        final decoded = StructuredTutorService.decodeLooseJson('''
{"questions":[{"type":"multiple_choice","prompt":"Hasil dari (-15) + 8 - (-4) adalah berapa?","options":["17","-17","3","-3"],"correct_index":0,"explanation":"Jawaban yang benar adalah 17.","skill_tag":"operasi bilangan bulat","difficulty":1}]}
''');

        final questions = QuizQuestion.listFromJson(
          decoded,
          topic: 'Bilangan Bulat',
          desiredCount: 1,
        );

        expect(questions, hasLength(1));
        expect(questions.first.correctIndex, 3);
        expect(questions.first.explanation, contains('-3'));
      },
    );

    test('falls back to usable quiz questions for malformed output', () {
      final questions = QuizQuestion.listFromJson(
        'bukan json',
        topic: 'Pecahan',
        desiredCount: 2,
      );

      expect(questions, hasLength(2));
      expect(questions.first.prompt, contains('Pecahan'));
      expect(questions.first.explanation, isNotEmpty);
    });

    test('fast tutor evaluation handles clear short answers locally', () {
      final result = StructuredTutorService.fastEvaluateAnswer(
        topic: 'Bilangan Bulat dan Pecahan',
        studentAnswer: 'Pecahan adalah bagian dari keseluruhan',
        difficulty: 1,
        keyConcepts:
            'Operasi bilangan bulat, pecahan biasa/campuran/desimal, operasi pecahan.',
      );

      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);
      expect(result.rawResponse, '[local_fast_evaluation]');
      expect(result.studentText, contains('Benar'));
    });

    test('fast tutor evaluation accepts concrete fraction examples', () {
      final result = StructuredTutorService.fastEvaluateAnswer(
        topic: 'Bilangan Bulat dan Pecahan',
        studentAnswer: '3/8 berarti 3 dari 8 bagian yang sama besar',
        difficulty: 2,
        keyConcepts:
            'Operasi bilangan bulat, pecahan biasa/campuran/desimal, operasi pecahan.',
      );

      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);
      expect(result.studentText, contains('Benar'));
      expect(result.feedback, contains('contoh 3/8'));
      expect(result.feedback, isNot(contains('bilangan dan bulat')));
    });

    test('local quiz generation creates distinct usable options', () {
      final questions = StructuredTutorService.buildLocalQuiz(
        topic: 'Bilangan Bulat dan Pecahan',
        grade: 7,
        questionCount: 3,
        keyConcepts:
            'Operasi bilangan bulat, pecahan biasa/campuran/desimal, operasi pecahan.',
      );

      expect(questions, hasLength(3));
      expect(questions.first.options.toSet(), hasLength(4));
      expect(questions.first.explanation, isNotEmpty);
      expect(questions.first.prompt, 'Apa arti 3/8?');
      expect(questions.first.explanation, contains('total 8 bagian'));
      expect(
        questions.map((q) => q.correctIndex).toSet().length,
        greaterThan(1),
      );
    });
  });

  group('Session response cleanup', () {
    test('removes filler openings from normal answers', () {
      final cleaned = SessionManager.cleanResponse(
        'Hai, pecahan adalah bagian dari satu utuh. Contoh: 1/2 berarti satu dari dua bagian.',
      );

      expect(cleaned.startsWith('Hai'), isFalse);
      expect(cleaned, startsWith('pecahan adalah'));
    });

    test('preserves JSON responses unchanged', () {
      const raw =
          '{"is_correct":true,"feedback":"Baik sebagai isi JSON, bukan filler."}';

      expect(SessionManager.cleanResponse(raw), raw);
    });

    test('keeps useful answer if prefix cleanup would be too aggressive', () {
      expect(SessionManager.cleanResponse('Oke.'), 'Oke.');
    });
  });

  group('Answer quality rules', () {
    test(
      'flags filler, emoji, missing task, and LaTeX in learning answers',
      () {
        final issues = AnswerQualityValidator.validateLearningAnswer(
          r'Hai, pecahan itu keren 😊. Rumusnya \frac{1}{2}.',
        );

        expect(issues.map((issue) => issue.code), contains('filler_opening'));
        expect(issues.map((issue) => issue.code), contains('emoji'));
        expect(issues.map((issue) => issue.code), contains('latex'));
        expect(
          issues.map((issue) => issue.code),
          contains('missing_next_task'),
        );
      },
    );

    test('accepts direct concrete learning answer', () {
      final issues = AnswerQualityValidator.validateLearningAnswer(
        'Pecahan berarti bagian dari satu utuh; contoh 3/8 berarti 3 dari 8 bagian yang sama besar. Coba tulis satu contoh pecahan lain.',
      );

      expect(issues, isEmpty);
    });

    test('shared prompt builders include direct-answer rules', () {
      final tutorPrompt = buildTutorEvaluationPrompt(
        topic: 'Pecahan',
        grade: 5,
        difficulty: 1,
        studentAnswer: '1/2 adalah setengah',
      );
      final quizPrompt = buildQuizGenerationPrompt(
        topic: 'Rantai Makanan',
        grade: 4,
        questionCount: 3,
        subject: 'ipa',
      );

      expect(tutorPrompt, contains('Jangan mulai dengan "Hai"'));
      expect(tutorPrompt, contains('Balas JSON valid saja'));
      expect(quizPrompt, contains('Pilihan jawaban harus berbeda makna'));
      expect(quizPrompt, contains('Jangan LaTeX'));
    });
  });

  group('Adaptive logic', () {
    test('uses confidence and mastery to avoid premature level up', () {
      final adapter = DifficultyAdapter();
      adapter.recordStructuredAnswer(
        isCorrect: true,
        confidence: 0.9,
        skillMastery: 0.3,
      );
      adapter.recordStructuredAnswer(
        isCorrect: true,
        confidence: 0.9,
        skillMastery: 0.3,
      );
      final action = adapter.recordStructuredAnswer(
        isCorrect: true,
        confidence: 0.9,
        skillMastery: 0.3,
      );

      expect(action, AdapterAction.normal);
      expect(adapter.currentLevel, 1);
    });

    test('flags weak performance after repeated misses', () {
      final adapter = DifficultyAdapter();
      for (var i = 0; i < 5; i++) {
        adapter.recordStructuredAnswer(isCorrect: false, confidence: 0.8);
      }
      final action = adapter.recordStructuredAnswer(
        isCorrect: false,
        confidence: 0.8,
      );
      expect(action, AdapterAction.flagWeak);
      expect(adapter.isFlagged, isTrue);
    });
  });

  group('Model compatibility', () {
    test('rejects pre-MTP model size and accepts May 2026 bundle size', () {
      expect(ModelLoader.isCompatibleSize(2583085056), isFalse);
      expect(ModelLoader.isCompatibleSize(2588147712), isTrue);
    });
  });

  group('Database intelligence tables', () {
    test('records sync retries and skill mastery', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();

      await db.addToSyncQueue({
        'id': 'retry_test',
        'payload_json': '{"table":"sessions_cloud","data":{}}',
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
      await db.incrementSyncRetry('retry_test');
      final queue = await db.getSyncQueue();
      expect(queue.first['retry_count'], 1);
      final syncSummary = await db.getSyncQueueSummary();
      expect(syncSummary['pending'], 1);
      expect(syncSummary['highestRetry'], 1);

      final mastery = await db.recordSkillAttempt(
        studentId: 'student_1',
        topicId: 'Pecahan',
        skillTag: 'arti pecahan',
        isCorrect: true,
      );
      expect(mastery.skillTag, 'arti_pecahan');
      expect(mastery.masteryScore, greaterThan(0.7));

      await db.clearAllData();
    });

    test('persists performance diagnostics in model status', () async {
      final db = DatabaseService.instance;
      await db.saveModelStatus('last_chat_flow', 'free_chat');
      await db.saveModelStatus('last_chat_total_time_ms', '1234');
      await db.saveModelStatus('last_chat_timed_out', 'false');
      final status = await db.getModelStatus();

      expect(status['last_chat_flow'], 'free_chat');
      expect(status['last_chat_total_time_ms'], '1234');
      expect(status['last_chat_timed_out'], 'false');
    });

    test('persists Tanya sessions locally', () async {
      final db = DatabaseService.instance;
      await db.saveTanyaSession({
        'id': 'tanya_test',
        'student_id': 'student_1',
        'title': 'Pecahan PR',
        'summary': 'Membahas PR pecahan.',
        'conversation_json': '[]',
        'created_at': '2026-05-12T00:00:00.000',
        'updated_at': '2026-05-12T00:01:00.000',
      });

      final sessions = await db.getTanyaSessions('student_1');
      expect(sessions, hasLength(1));
      expect(sessions.first['title'], 'Pecahan PR');

      await db.deleteTanyaSession('tanya_test');
      expect(await db.getTanyaSessions('student_1'), isEmpty);
    });

    test('caches AI-generated quiz questions for reuse', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();
      const question = QuizQuestion(
        id: 'q1',
        type: 'true_false',
        prompt: '3/8 berarti 3 dari 8 bagian yang sama besar.',
        options: ['Benar', 'Salah'],
        correctIndex: 0,
        explanation:
            'Pernyataan ini benar, jadi jawaban yang tepat adalah Benar.',
        skillTag: 'arti_pecahan',
        difficulty: 1,
      );

      await db.saveQuizQuestionsToCache(
        subject: 'math',
        topicId: 'Pecahan',
        grade: 5,
        questions: const [question],
      );

      expect(
        await db.getQuizCacheCount(
          subject: 'math',
          topicId: 'Pecahan',
          grade: 5,
        ),
        1,
      );

      final cached = await db.getCachedQuizQuestion(
        subject: 'math',
        topicId: 'Pecahan',
        grade: 5,
        difficulty: 1,
      );
      expect(cached, isNotNull);
      expect(cached!.prompt, question.prompt);
      expect(cached.type, 'true_false');

      final excluded = await db.getCachedQuizQuestion(
        subject: 'math',
        topicId: 'Pecahan',
        grade: 5,
        difficulty: 1,
        excludePrompts: {question.prompt},
      );
      expect(excluded, isNull);

      await db.clearAllData();
    });
  });
}
