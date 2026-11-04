import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:encourise_mobile/main.dart';
import 'package:encourise_mobile/models/learning_models.dart';
import 'package:encourise_mobile/screens/notes_screen.dart';
import 'package:encourise_mobile/screens/guided_learning_screen.dart';
import 'package:encourise_mobile/screens/home_screen.dart';
import 'package:encourise_mobile/screens/quiz_screen.dart';
import 'package:encourise_mobile/screens/settings_screen.dart';
import 'package:encourise_mobile/screens/tutoring_screen.dart';
import 'package:encourise_mobile/screens/topic_list_screen.dart';
import 'package:encourise_mobile/utils/curriculum_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('QuizScreen', () {
    testWidgets('renders generated options and grades locally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuizScreen(
            subject: 'math',
            topic: 'Pecahan',
            grade: 5,
            disablePersistence: true,
            initialQuestions: const [
              QuizQuestion(
                id: 'q1',
                prompt: 'Berapa hasil 1/2 + 1/2?',
                options: ['1/4', '1', '2', '1/2'],
                correctIndex: 1,
                explanation: '1/2 + 1/2 sama dengan 1.',
                skillTag: 'penjumlahan_pecahan',
                difficulty: 1,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Berapa hasil 1/2 + 1/2?'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Soal 1/1'), findsOneWidget);

      await tester.tap(find.text('1/4'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        find.textContaining('sama dengan 1', skipOffstage: false),
        findsOneWidget,
      );

      await tester.tap(find.text('Selesaikan Kuis'));
      await tester.pumpAndSettle();

      expect(find.text('Kuis selesai!'), findsOneWidget);
      expect(find.text('Benar 0/1 • XP +5'), findsOneWidget);
    });
  });

  group('TutoringScreen', () {
    testWidgets('uses structured evaluation for wrong answers and hints', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TutoringScreen(
            subject: 'math',
            topic: 'Pecahan',
            grade: 5,
            disablePersistence: true,
            initialGreeting:
                'Kita belajar Pecahan. Menurutmu, apa bagian paling penting dari topik ini?',
            answerEvaluator: (_) async => const TutorTurnResult(
              isCorrect: false,
              confidence: 0.4,
              feedback: 'Belum tepat, penyebutnya perlu disamakan.',
              hint: 'Ubah menjadi penyebut yang sama dulu.',
              nextQuestion: 'Coba ulangi dengan penyebut 4.',
              skillTag: 'penyebut_sama',
              difficulty: 1,
              shouldAdvance: false,
              rawResponse: '{}',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Kita belajar Pecahan'), findsOneWidget);
      expect(find.textContaining('Halo'), findsNothing);
      expect(find.textContaining('Hai'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Jawabannya 3');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Jawabannya 3'), findsOneWidget);
      expect(
        find.textContaining('Belum tepat, penyebutnya perlu disamakan.'),
        findsOneWidget,
      );
      expect(find.textContaining('Petunjuk:'), findsOneWidget);
      expect(
        find.textContaining('Coba ulangi dengan penyebut 4.'),
        findsOneWidget,
      );
    });
  });

  group('GuidedLearningScreen', () {
    testWidgets('starts each step without filler greeting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GuidedLearningScreen(
            subject: 'math',
            topic: 'Pecahan',
            grade: 5,
            initialSteps: [
              {
                'step': 1,
                'title': 'Pengertian Dasar',
                'description': 'Memahami arti pecahan',
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Konsep: Pengertian Dasar'), findsOneWidget);
      expect(
        find.textContaining('Contoh: 3/8 berarti 3 dari 8 bagian'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Tugas: jelaskan satu contoh Pecahan dengan caramu sendiri',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Hai'), findsNothing);
      expect(find.textContaining('Halo'), findsNothing);
    });
  });

  group('TopicListScreen', () {
    testWidgets('shows all Mata Pelajaran learning modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TopicListScreen(
            subject: SubjectData(
              key: 'matematika',
              name: 'Matematika',
              icon: Icons.calculate_rounded,
            ),
            grade: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Operasi Pecahan'));
      await tester.pumpAndSettle();

      expect(find.text('Pahami'), findsOneWidget);
      expect(find.text('Tes Diri'), findsOneWidget);
      expect(find.text('Jalur Belajar'), findsOneWidget);
      expect(
        find.textContaining('Pahami untuk memahami konsep'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Pilih ini untuk mengecek pemahaman dengan soal pilihan ganda',
        ),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen', () {
    testWidgets('prioritizes open guided sessions over review skills', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(
            testData: HomeScreenTestData(
              studentName: 'Ayu',
              openGuidedSession: {'topic_id': 'Pecahan', 'current_step': 1},
              reviewSkills: [
                LearnerSkillMastery(
                  skillTag: 'penyebut_sama',
                  topicId: 'Pecahan',
                  attempts: 3,
                  correct: 1,
                  hintCount: 1,
                  masteryScore: 0.35,
                  lastPracticedAt: '2026-05-06T00:00:00.000',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Halo Ayu'), findsOneWidget);
      expect(find.text('AI siap'), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing);
      expect(find.text('Lanjut Jalur Belajar'), findsOneWidget);
      expect(find.text('Review yang disarankan'), findsNothing);
    });

    testWidgets('shows review card before generic subject starts', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(
            testData: HomeScreenTestData(
              studentName: 'Ayu',
              reviewSkills: [
                LearnerSkillMastery(
                  skillTag: 'arti_pecahan',
                  topicId: 'Pecahan',
                  attempts: 4,
                  correct: 1,
                  hintCount: 2,
                  masteryScore: 0.25,
                  lastPracticedAt: '2026-05-06T00:00:00.000',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Review yang disarankan'), findsOneWidget);
      expect(find.text('Mulai belajar hari ini'), findsNothing);
      expect(find.textContaining('arti pecahan'), findsOneWidget);
    });

    testWidgets('falls back to the generic start card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(
            testData: HomeScreenTestData(studentName: 'Ayu', grade: 5),
          ),
        ),
      );

      expect(find.text('Mulai belajar hari ini'), findsOneWidget);
      expect(find.text('Review yang disarankan'), findsNothing);
      expect(find.text('Lanjut Jalur Belajar'), findsNothing);
    });
  });

  group('NotesScreen', () {
    testWidgets('reloads notes when the tab refresh token changes', (
      tester,
    ) async {
      var savedNotes = <Map<String, dynamic>>[];
      Future<List<Map<String, dynamic>>> loadNotes() async => savedNotes;

      await tester.pumpWidget(
        MaterialApp(
          home: NotesScreen(
            isTab: true,
            refreshToken: 0,
            notesLoader: loadNotes,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Belum ada catatan'), findsOneWidget);

      savedNotes = [
        {
          'id': 'note_refresh_test',
          'student_id': 'student_notes',
          'topic_id': 'Tanya Budi',
          'content_text': 'Pecahan adalah bagian dari satu utuh.',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: NotesScreen(
            isTab: true,
            refreshToken: 1,
            notesLoader: loadNotes,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Belum ada catatan'), findsNothing);
      expect(
        find.textContaining('Pecahan adalah bagian dari satu utuh.'),
        findsOneWidget,
      );
    });
  });

  group('SettingsScreen diagnostics', () {
    testWidgets('shows release-safe app health diagnostics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(
            isTab: true,
            testData: SettingsScreenTestData(
              modelStatus: {
                'model_path_status': 'path tersimpan',
                'last_reminder_result': 'terjadwal',
                'last_reminder_time': '2026-05-11T19:00:00.000',
                'last_chat_flow': 'free_chat',
                'last_chat_total_time_ms': '1200',
                'last_decode_tokens_per_second': '8.50',
                'last_time_to_first_token_seconds': '0.75',
              },
              syncSummary: {'pending': 1, 'highestRetry': 2},
              showTechnicalDetails: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Kesehatan Aplikasi'), findsOneWidget);
      expect(find.text('Sinkronisasi'), findsOneWidget);
      expect(find.text('1 menunggu'), findsOneWidget);
      expect(find.textContaining('terjadwal'), findsOneWidget);
      expect(find.text('path tersimpan'), findsOneWidget);
      expect(find.text('Retry tertinggi'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Flow terakhir'), findsOneWidget);
      expect(find.text('free_chat'), findsOneWidget);
    });
  });

  group('ModelSetupScreen', () {
    testWidgets('communicates MTP-ready model requirement', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ModelSetupScreen(onModelReady: (_) async {})),
      );

      expect(find.text('Model AI Belum Tersedia'), findsOneWidget);
      expect(find.text('MTP siap dengan model Mei 2026'), findsOneWidget);
      expect(find.text('Download Sekarang'), findsOneWidget);
      expect(find.text('Cari di Download'), findsOneWidget);
    });
  });

  group('Notification deep links', () {
    testWidgets('routes quiz, guided, and tutoring reminder payloads', (
      tester,
    ) async {
      Widget routeLabel(String label) =>
          Scaffold(body: Center(child: Text(label)));

      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: routeLabel('Home')),
      );

      handleNotificationTap(
        '{"screen":"quiz","subject":"math","topic":"Pecahan","grade":5}',
        quizBuilder: (subject, topic, grade) =>
            routeLabel('Quiz $subject $topic $grade'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quiz math Pecahan 5'), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      handleNotificationTap(
        '{"screen":"guided","subject":"math","topic":"Pecahan","grade":5}',
        guidedBuilder: (subject, topic, grade) =>
            routeLabel('Guided $subject $topic $grade'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Guided math Pecahan 5'), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      handleNotificationTap(
        '{"screen":"tutoring","subject":"math","topic":"Pecahan","grade":5}',
        tutoringBuilder: (subject, topic, grade) =>
            routeLabel('Tutoring $subject $topic $grade'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tutoring math Pecahan 5'), findsOneWidget);
    });
  });
}
