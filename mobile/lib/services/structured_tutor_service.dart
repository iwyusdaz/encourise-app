import 'dart:convert';

import '../models/learning_models.dart';
import '../utils/prompt_builder.dart';
import 'database_service.dart';
import 'session_manager.dart';

class StructuredTutorService {
  StructuredTutorService._();

  static const Duration _localJsonTimeout = Duration(seconds: 135);

  static Object? decodeLooseJson(String raw) {
    final trimmed = raw.trim();
    final candidates = <String>[
      trimmed,
      _stripCodeFence(trimmed),
      _extractJsonBlock(trimmed),
      _closeJsonShape(_stripCodeFence(trimmed)),
      _closeJsonShape(_extractJsonBlock(trimmed)),
    ].where((item) => item.trim().isNotEmpty).toList();

    for (final candidate in candidates) {
      try {
        return jsonDecode(candidate);
      } catch (_) {}
    }
    return null;
  }

  static Future<TutorTurnResult> evaluateAnswer({
    required SessionManager session,
    required String topic,
    required String studentAnswer,
    required int grade,
    required int difficulty,
    String skillTag = '',
    String keyConcepts = '',
    String teachingMode = 'jelaskan',
  }) async {
    // Keep grading stateless. Reusing the active tutoring conversation makes
    // native LiteRT-LM context grow with verbose JSON prompts, which slows down
    // every later answer.
    await session.startConversation();

    final prompt = buildTutorEvaluationPrompt(
      topic: topic,
      grade: grade,
      difficulty: difficulty,
      studentAnswer: studentAnswer,
      skillTag: skillTag,
      teachingMode: teachingMode,
    );

    final jsonResult = await session.chatJson(
      prompt,
      decode: decodeLooseJson,
      maxTokens: 150,
      flowLabel: 'tutor_evaluation',
      timeout: _localJsonTimeout,
    );
    if (jsonResult.decoded is Map<String, dynamic>) {
      await _saveMetric('last_tutor_evaluation_source', 'local_gemma');
      return TutorTurnResult.fromJson(
        jsonResult.decoded! as Map<String, dynamic>,
        rawResponse: jsonResult.raw,
      );
    }
    await _saveMetric(
      'last_tutor_evaluation_source',
      _sourceLabel(jsonResult.status),
    );
    return TutorTurnResult.retryNeeded(
      rawResponse: '[${_sourceLabel(jsonResult.status)}]',
      topic: topic,
      difficulty: difficulty,
    );
  }

  static Future<List<QuizQuestion>> generateQuiz({
    required SessionManager session,
    required String topic,
    required int grade,
    required int questionCount,
    String subject = '',
    String keyConcepts = '',
  }) async {
    final prompt = buildQuizGenerationPrompt(
      topic: topic,
      grade: grade,
      questionCount: questionCount,
      subject: subject,
      keyConcepts: keyConcepts,
    );

    final jsonResult = await session.chatJson(
      prompt,
      decode: decodeLooseJson,
      maxTokens: questionCount <= 1 ? 260 : 520,
      flowLabel: 'quiz_generation',
      timeout: _localJsonTimeout,
    );
    if (jsonResult.isSuccess) {
      final questions = QuizQuestion.listFromJson(
        jsonResult.decoded,
        topic: topic,
        desiredCount: questionCount,
        allowFallback: false,
      );
      if (questions.isNotEmpty) {
        await _saveMetric(
          'last_quiz_generation_source',
          questions.length == questionCount
              ? 'local_gemma'
              : 'local_gemma_partial',
        );
        return questions;
      }
      await _saveMetric('last_quiz_generation_source', 'invalid_json');
      return const [];
    }
    await _saveMetric(
      'last_quiz_generation_source',
      _sourceLabel(jsonResult.status),
    );
    return const [];
  }

  static Future<List<QuizQuestion>> generateQuizBatch({
    required SessionManager session,
    required String topic,
    required int grade,
    required int questionCount,
    String subject = '',
    String keyConcepts = '',
    int batchNumber = 1,
    double previousAccuracy = 0,
    List<String> missedSkillTags = const [],
  }) async {
    final prompt = buildQuizGenerationPrompt(
      topic: topic,
      grade: grade,
      questionCount: questionCount,
      subject: subject,
      keyConcepts: keyConcepts,
      batchNumber: batchNumber,
      previousAccuracy: previousAccuracy,
      missedSkillTags: missedSkillTags,
    );
    final jsonResult = await session.chatJson(
      prompt,
      decode: decodeLooseJson,
      maxTokens: questionCount <= 1 ? 260 : 520,
      flowLabel: 'quiz_generation',
      timeout: _localJsonTimeout,
    );
    if (!jsonResult.isSuccess) {
      await _saveMetric(
        'last_quiz_generation_source',
        _sourceLabel(jsonResult.status),
      );
      return const [];
    }
    final questions = QuizQuestion.listFromJson(
      jsonResult.decoded,
      topic: topic,
      desiredCount: questionCount,
      allowFallback: false,
    );
    if (questions.isEmpty) {
      await _saveMetric('last_quiz_generation_source', 'invalid_json');
      return const [];
    }
    await _saveMetric(
      'last_quiz_generation_source',
      questions.length == questionCount ? 'local_gemma' : 'local_gemma_partial',
    );
    return questions;
  }

  static Future<List<Map<String, dynamic>>> generateGuidedPlan({
    required SessionManager session,
    required String topic,
    required int grade,
    String subject = '',
    String keyConcepts = '',
  }) async {
    final jsonResult = await session.chatJson(
      buildGuidedPlanPrompt(
        topic: topic,
        grade: grade,
        subject: subject,
        keyConcepts: keyConcepts,
      ),
      decode: decodeLooseJson,
      maxTokens: 420,
      flowLabel: 'guided_plan',
      timeout: _localJsonTimeout,
    );
    if (!jsonResult.isSuccess) {
      await _saveMetric(
        'last_guided_plan_source',
        _sourceLabel(jsonResult.status),
      );
      return const [];
    }
    final decoded = jsonResult.decoded;
    final rawSteps = decoded is Map<String, dynamic>
        ? decoded['steps']
        : decoded;
    if (rawSteps is! List) {
      await _saveMetric('last_guided_plan_source', 'invalid_json');
      return const [];
    }
    final steps = <Map<String, dynamic>>[];
    for (var i = 0; i < rawSteps.length && i < 3; i++) {
      final item = rawSteps[i];
      if (item is Map<String, dynamic>) {
        steps.add({
          'step': _intValue(item['step'], i + 1),
          'title': item['title']?.toString() ?? 'Langkah ${i + 1}',
          'description': item['description']?.toString() ?? topic,
        });
      }
    }
    await _saveMetric(
      'last_guided_plan_source',
      steps.length == 3 ? 'local_gemma' : 'invalid_json',
    );
    return steps.length == 3 ? steps : const [];
  }

  static Future<String?> generateGuidedStepContent({
    required SessionManager session,
    required String topic,
    required int grade,
    required int stepNumber,
    required String stepTitle,
    required String stepDescription,
    String keyConcepts = '',
  }) async {
    final jsonResult = await session.chatJson(
      buildGuidedStepPrompt(
        topic: topic,
        grade: grade,
        stepNumber: stepNumber,
        stepTitle: stepTitle,
        stepDescription: stepDescription,
        keyConcepts: keyConcepts,
      ),
      decode: decodeLooseJson,
      maxTokens: 240,
      flowLabel: 'guided_step',
      timeout: _localJsonTimeout,
    );
    if (!jsonResult.isSuccess || jsonResult.decoded is! Map<String, dynamic>) {
      await _saveMetric(
        'last_guided_step_source',
        _sourceLabel(jsonResult.status),
      );
      return null;
    }
    final decoded = jsonResult.decoded! as Map<String, dynamic>;
    final concept = decoded['concept']?.toString().trim() ?? '';
    final example = decoded['example']?.toString().trim() ?? '';
    final task = decoded['task']?.toString().trim() ?? '';
    if (concept.isEmpty || example.isEmpty || task.isEmpty) {
      await _saveMetric('last_guided_step_source', 'invalid_json');
      return null;
    }
    await _saveMetric('last_guided_step_source', 'local_gemma');
    return 'Konsep: $concept\n\nContoh: $example\n\nTugas: $task';
  }

  static TutorTurnResult? fastEvaluateAnswer({
    required String topic,
    required String studentAnswer,
    required int difficulty,
    String skillTag = '',
    String keyConcepts = '',
  }) {
    final answer = studentAnswer.trim();
    if (answer.isEmpty) return null;
    if (answer.length > 180) return null;

    final topicTerms = _importantTerms(topic);
    final conceptTerms = _importantTerms(keyConcepts);
    final terms = {...topicTerms, ...conceptTerms}.toList();
    if (terms.isEmpty) return null;

    final lower = _normalize(answer);
    final doesNotKnow =
        lower.contains('tidak tahu') ||
        lower.contains('gak tahu') ||
        lower.contains('nggak tahu') ||
        lower.contains('belum tahu') ||
        lower == 'tidak';

    final matched = terms.where((term) => lower.contains(term)).toList();
    final topicMatched = topicTerms
        .where((term) => lower.contains(term))
        .length;
    final conceptMatched = conceptTerms
        .where((term) => lower.contains(term))
        .length;
    final hasMeaningPhrase = _hasMeaningPhrase(lower, topic);
    final isCorrect =
        !doesNotKnow &&
        (hasMeaningPhrase ||
            matched.length >= 2 ||
            (topicMatched >= 1 && conceptMatched >= 1));

    final normalizedSkill = normalizeSkillTag(
      skillTag.isEmpty ? (matched.firstOrNull ?? topic) : skillTag,
    );
    final anchorTerms = (matched.isNotEmpty ? matched : terms).take(3).toList();

    if (isCorrect) {
      final anchor = anchorTerms.take(2).join(' dan ');
      final feedback = _feedbackForCorrectAnswer(
        topic: topic,
        answer: lower,
        anchor: anchor,
        hasMeaningPhrase: hasMeaningPhrase,
      );
      return TutorTurnResult(
        isCorrect: true,
        confidence: hasMeaningPhrase ? 0.86 : 0.78,
        feedback: feedback,
        hint: '',
        nextQuestion: _nextQuestionFor(topic, anchorTerms),
        skillTag: normalizedSkill,
        difficulty: difficulty.clamp(1, 3),
        shouldAdvance: true,
        rawResponse: '[local_fast_evaluation]',
      );
    }

    return TutorTurnResult(
      isCorrect: false,
      confidence: doesNotKnow ? 0.82 : 0.68,
      feedback: 'Belum tepat, jawabanmu belum menunjukkan inti $topic.',
      hint:
          'Gunakan kata kunci seperti ${anchorTerms.join(", ")} lalu beri satu contoh.',
      nextQuestion: 'Coba tulis ulang dalam 1 kalimat dengan contoh sederhana.',
      skillTag: normalizedSkill,
      difficulty: difficulty.clamp(1, 3),
      shouldAdvance: false,
      rawResponse: '[local_fast_evaluation]',
    );
  }

  static String _feedbackForCorrectAnswer({
    required String topic,
    required String answer,
    required String anchor,
    required bool hasMeaningPhrase,
  }) {
    final normalizedTopic = _normalize(topic);
    if (hasMeaningPhrase && normalizedTopic.contains('pecahan')) {
      final fraction = RegExp(r'\b\d+\s*/\s*\d+\b').firstMatch(answer);
      final example = fraction?.group(0);
      if (example != null) {
        return 'Benar, contoh $example menunjukkan pecahan sebagai bagian dari satu utuh.';
      }
      return 'Benar, jawabanmu menunjukkan pecahan sebagai bagian dari satu utuh.';
    }
    if (anchor.isEmpty) {
      return 'Benar, jawabanmu sudah menangkap inti $topic.';
    }
    return 'Benar, jawabanmu sudah menyebut inti $topic: $anchor.';
  }

  static List<QuizQuestion> buildLocalQuiz({
    required String topic,
    required int grade,
    required int questionCount,
    String keyConcepts = '',
  }) {
    final phrases = _conceptPhrases(keyConcepts);
    final terms = _importantTerms('$topic $keyConcepts');
    if (phrases.isEmpty && terms.isEmpty) return const [];

    final topicSpecific = _topicSpecificQuizSpecs(topic, grade);
    if (topicSpecific.isNotEmpty) {
      return topicSpecific
          .take(questionCount)
          .toList()
          .asMap()
          .entries
          .map((entry) => entry.value.toQuestion(entry.key))
          .toList();
    }

    final firstPhrase = phrases.firstOrNull ?? topic;
    final firstTerm = terms.firstOrNull ?? topic;
    final specs = <_LocalQuizSpec>[
      _LocalQuizSpec(
        id: 'local_q1',
        prompt: 'Manakah pernyataan yang benar tentang $topic?',
        correctOption: '$topic berkaitan dengan $firstPhrase.',
        distractors: [
          '$topic tidak memiliki aturan atau contoh.',
          '$topic hanya bisa dijawab dengan menebak.',
          '$topic tidak berhubungan dengan pelajaran kelas $grade.',
        ],
        explanation: '$topic memang dipahami lewat $firstPhrase.',
        skillTag: normalizeSkillTag(firstTerm),
        difficulty: 1,
      ),
      _LocalQuizSpec(
        id: 'local_q2',
        prompt: 'Apa langkah pertama yang paling tepat saat belajar $topic?',
        correctOption: 'Pahami arti konsepnya, lalu lihat satu contoh.',
        distractors: [
          'Langsung menghafal jawaban tanpa contoh.',
          'Mengabaikan informasi yang diketahui.',
          'Memilih jawaban yang paling panjang.',
        ],
        explanation:
            'Memahami arti konsep dan contoh membuat latihan $topic lebih jelas.',
        skillTag: normalizeSkillTag(topic),
        difficulty: 1,
      ),
      _LocalQuizSpec(
        id: 'local_q3',
        prompt: 'Contoh mana yang paling membantu untuk memahami $topic?',
        correctOption: _exampleFor(topic),
        distractors: [
          'Kalimat tanpa angka, data, atau hubungan yang jelas.',
          'Jawaban yang tidak menyebut konsep utama.',
          'Contoh dari topik yang tidak dipelajari.',
        ],
        explanation: 'Contoh konkret membantu melihat cara kerja $topic.',
        skillTag: normalizeSkillTag(firstTerm),
        difficulty: 1,
      ),
      _LocalQuizSpec(
        id: 'local_q4',
        prompt:
            'Jika jawabanmu salah pada soal $topic, apa yang sebaiknya dicek?',
        correctOption: 'Cek kembali konsep, data soal, dan langkah hitungnya.',
        distractors: [
          'Ganti jawaban tanpa melihat soal.',
          'Hapus semua langkah penyelesaian.',
          'Pilih jawaban yang sama seperti sebelumnya.',
        ],
        explanation:
            'Kesalahan biasanya terlihat saat konsep, data, dan langkah dicek ulang.',
        skillTag: normalizeSkillTag(topic),
        difficulty: 2,
      ),
      _LocalQuizSpec(
        id: 'local_q5',
        prompt: 'Pernyataan mana yang menunjukkan pemahaman $topic?',
        correctOption:
            'Saya bisa menjelaskan arti, memberi contoh, dan mencoba soal sejenis.',
        distractors: [
          'Saya hanya mengingat satu kata dari topik.',
          'Saya tidak perlu contoh untuk memahami materi.',
          'Saya memilih jawaban tanpa alasan.',
        ],
        explanation:
            'Pemahaman terlihat dari arti konsep, contoh, dan latihan sejenis.',
        skillTag: normalizeSkillTag(topic),
        difficulty: 2,
      ),
    ];

    return specs
        .take(questionCount)
        .toList()
        .asMap()
        .entries
        .map((entry) => entry.value.toQuestion(entry.key))
        .toList();
  }

  static LearnerProfile parseLearnerProfile(String raw) {
    final decoded = decodeLooseJson(raw);
    if (decoded is Map<String, dynamic>) {
      return LearnerProfile.fromJson(decoded);
    }
    return const LearnerProfile();
  }

  static List<_LocalQuizSpec> _topicSpecificQuizSpecs(String topic, int grade) {
    final normalizedTopic = _normalize(topic);
    if (normalizedTopic.contains('pecahan')) {
      return [
        const _LocalQuizSpec(
          id: 'fraction_q1',
          prompt: 'Apa arti 3/8?',
          correctOption: '3 dari 8 bagian yang sama besar.',
          distractors: [
            '8 dari 3 bagian yang sama besar.',
            '3 ditambah 8 bagian.',
            'Semua bagian tanpa sisa.',
          ],
          explanation:
              '3/8 berarti mengambil 3 bagian dari total 8 bagian yang sama besar.',
          skillTag: 'arti_pecahan',
          difficulty: 1,
        ),
        const _LocalQuizSpec(
          id: 'fraction_q2',
          prompt: 'Mengapa 1/2 sama nilainya dengan 2/4?',
          correctOption: 'Keduanya menunjukkan setengah dari satu utuh.',
          distractors: [
            'Karena angka atasnya selalu harus sama.',
            'Karena 2/4 lebih besar dari 1/2.',
            'Karena semua pecahan bernilai sama.',
          ],
          explanation:
              '1/2 dan 2/4 sama-sama membagi satu utuh menjadi bagian setara setengah.',
          skillTag: 'pecahan_senilai',
          difficulty: 1,
        ),
        const _LocalQuizSpec(
          id: 'fraction_q3',
          prompt: 'Langkah pertama menjumlahkan 1/3 + 1/6 adalah...',
          correctOption: 'Samakan penyebutnya dulu.',
          distractors: [
            'Jumlahkan pembilang dan penyebut langsung.',
            'Ubah semua angka menjadi bilangan bulat.',
            'Pilih penyebut yang paling kecil tanpa menghitung.',
          ],
          explanation:
              'Penyebut perlu disamakan agar bagian yang dijumlahkan berukuran sama.',
          skillTag: 'operasi_pecahan',
          difficulty: 2,
        ),
      ];
    }

    if (normalizedTopic.contains('bilangan')) {
      return [
        const _LocalQuizSpec(
          id: 'integer_q1',
          prompt: 'Pada garis bilangan, -2 berada di mana?',
          correctOption: 'Di kiri 0.',
          distractors: [
            'Di kanan 0.',
            'Tepat di 0.',
            'Tidak bisa ditaruh di garis bilangan.',
          ],
          explanation: 'Bilangan negatif berada di kiri 0 pada garis bilangan.',
          skillTag: 'bilangan_bulat',
          difficulty: 1,
        ),
        const _LocalQuizSpec(
          id: 'integer_q2',
          prompt: 'Hasil -3 + 5 adalah...',
          correctOption: '2',
          distractors: ['-8', '-2', '8'],
          explanation: 'Dari -3 maju 5 langkah ke kanan menghasilkan 2.',
          skillTag: 'operasi_bilangan_bulat',
          difficulty: 1,
        ),
        const _LocalQuizSpec(
          id: 'integer_q3',
          prompt: 'Contoh situasi yang cocok untuk bilangan negatif adalah...',
          correctOption: 'Suhu 2 derajat di bawah 0.',
          distractors: [
            'Jumlah buku di meja.',
            'Nomor halaman buku.',
            'Banyak siswa di kelas.',
          ],
          explanation:
              'Bilangan negatif cocok untuk nilai di bawah nol, seperti suhu -2 derajat.',
          skillTag: 'makna_bilangan_negatif',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('himpunan')) {
      return [
        const _LocalQuizSpec(
          id: 'set_q1',
          prompt: 'Manakah contoh himpunan yang jelas?',
          correctOption: 'A = {2, 4, 6}.',
          distractors: [
            'A = angka yang bagus.',
            'A = sesuatu yang menarik.',
            'A = semua hal.',
          ],
          explanation:
              'A = {2, 4, 6} jelas karena anggotanya disebutkan dengan pasti.',
          skillTag: 'himpunan',
          difficulty: 1,
        ),
        const _LocalQuizSpec(
          id: 'set_q2',
          prompt: 'Jika B = {apel, jeruk, mangga}, maka apel adalah...',
          correctOption: 'Anggota himpunan B.',
          distractors: [
            'Nama himpunan B.',
            'Bukan bagian dari B.',
            'Jumlah anggota B.',
          ],
          explanation:
              'Apel adalah anggota karena tercantum di dalam himpunan B.',
          skillTag: 'anggota_himpunan',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('aljabar')) {
      return [
        const _LocalQuizSpec(
          id: 'algebra_q1',
          prompt: 'Pada bentuk 3x + 2, x disebut...',
          correctOption: 'Variabel.',
          distractors: ['Koefisien.', 'Konstanta.', 'Hasil akhir.'],
          explanation: 'x disebut variabel karena nilainya bisa berubah.',
          skillTag: 'variabel_aljabar',
          difficulty: 1,
        ),
        const _LocalQuizSpec(
          id: 'algebra_q2',
          prompt: 'Pada bentuk 3x + 2, angka 3 disebut...',
          correctOption: 'Koefisien.',
          distractors: ['Variabel.', 'Konstanta.', 'Penyebut.'],
          explanation: '3 disebut koefisien karena mengalikan variabel x.',
          skillTag: 'koefisien_aljabar',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('rantai makanan')) {
      return [
        const _LocalQuizSpec(
          id: 'food_chain_q1',
          prompt: 'Apa yang ditunjukkan oleh rantai makanan?',
          correctOption:
              'Aliran energi dari satu makhluk hidup ke makhluk hidup lain.',
          distractors: [
            'Daftar hewan yang hidup di tempat yang sama.',
            'Urutan ukuran tubuh hewan dari kecil ke besar.',
            'Cara tumbuhan menyimpan air.',
          ],
          explanation:
              'Rantai makanan menunjukkan perpindahan energi, misalnya rumput dimakan belalang.',
          skillTag: 'rantai_makanan',
          difficulty: 1,
        ),
        const _LocalQuizSpec(
          id: 'food_chain_q2',
          prompt:
              'Pada rantai rumput -> belalang -> katak, rumput berperan sebagai...',
          correctOption: 'Produsen.',
          distractors: ['Konsumen I.', 'Konsumen II.', 'Pengurai.'],
          explanation:
              'Rumput disebut produsen karena membuat makanan sendiri.',
          skillTag: 'produsen',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('gaya') || normalizedTopic.contains('gerak')) {
      return [
        const _LocalQuizSpec(
          id: 'force_q1',
          prompt: 'Gaya adalah...',
          correctOption:
              'Dorongan atau tarikan yang dapat mengubah gerak benda.',
          distractors: [
            'Ukuran warna suatu benda.',
            'Nama alat untuk mengukur waktu.',
            'Jumlah benda dalam satu tempat.',
          ],
          explanation:
              'Gaya berupa dorongan atau tarikan, misalnya mendorong meja.',
          skillTag: 'gaya_dan_gerak',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('gagasan') ||
        normalizedTopic.contains('paragraf')) {
      return [
        const _LocalQuizSpec(
          id: 'main_idea_q1',
          prompt: 'Gagasan pokok dalam paragraf berarti...',
          correctOption: 'Ide utama yang dibahas dalam paragraf.',
          distractors: [
            'Kata paling panjang dalam paragraf.',
            'Kalimat yang selalu ada di akhir teks.',
            'Nama tokoh dalam cerita saja.',
          ],
          explanation:
              'Gagasan pokok adalah ide utama yang dijelaskan oleh kalimat lain.',
          skillTag: 'gagasan_pokok',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('sejarah') ||
        normalizedTopic.contains('ekonomi') ||
        normalizedTopic.contains('geografi')) {
      return [
        const _LocalQuizSpec(
          id: 'social_q1',
          prompt: 'Cara memahami topik IPS yang baik adalah...',
          correctOption: 'Melihat sebab, peristiwa, dan akibatnya.',
          distractors: [
            'Menghafal satu kata tanpa contoh.',
            'Memilih jawaban paling pendek.',
            'Mengabaikan waktu dan tempat kejadian.',
          ],
          explanation:
              'IPS lebih jelas jika sebab, peristiwa, dan akibatnya dihubungkan.',
          skillTag: 'sebab_akibat_ips',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('inggris') ||
        normalizedTopic.contains('english')) {
      return [
        const _LocalQuizSpec(
          id: 'english_q1',
          prompt: 'Kalimat "I read a book" berarti...',
          correctOption: 'Saya membaca buku.',
          distractors: [
            'Saya menulis buku.',
            'Saya membeli buku.',
            'Saya melihat meja.',
          ],
          explanation: '"I read a book" berarti seseorang sedang membaca buku.',
          skillTag: 'simple_sentence',
          difficulty: 1,
        ),
      ];
    }

    if (normalizedTopic.contains('pkn') ||
        normalizedTopic.contains('kewarganegaraan') ||
        normalizedTopic.contains('musyawarah')) {
      return [
        const _LocalQuizSpec(
          id: 'civics_q1',
          prompt: 'Musyawarah digunakan untuk...',
          correctOption: 'Mengambil keputusan bersama.',
          distractors: [
            'Menentukan pemenang tanpa diskusi.',
            'Menghindari pendapat orang lain.',
            'Membuat aturan hanya untuk satu orang.',
          ],
          explanation:
              'Musyawarah membantu kelompok memilih keputusan secara bersama.',
          skillTag: 'musyawarah',
          difficulty: 1,
        ),
      ];
    }

    return const [];
  }

  static String _stripCodeFence(String raw) {
    return raw
        .replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '')
        .replaceAll(RegExp(r'```$', multiLine: true), '')
        .trim();
  }

  static String _extractJsonBlock(String raw) {
    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(raw);
    if (objectMatch == null) return arrayMatch?.group(0) ?? '';
    if (arrayMatch == null) return objectMatch.group(0) ?? '';
    return objectMatch.start <= arrayMatch.start
        ? objectMatch.group(0) ?? ''
        : arrayMatch.group(0) ?? '';
  }

  static String _closeJsonShape(String raw) {
    final source = raw.trim();
    if (source.isEmpty) return '';
    final start = source.indexOf(RegExp(r'[\{\[]'));
    if (start < 0) return '';

    final buffer = StringBuffer();
    final closers = <String>[];
    var inString = false;
    var escaping = false;

    for (var i = start; i < source.length; i++) {
      final char = source[i];
      buffer.write(char);

      if (escaping) {
        escaping = false;
        continue;
      }
      if (char == '\\' && inString) {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (char == '{') {
        closers.add('}');
      } else if (char == '[') {
        closers.add(']');
      } else if ((char == '}' || char == ']') && closers.isNotEmpty) {
        closers.removeLast();
      }
    }

    if (inString) buffer.write('"');
    for (final closer in closers.reversed) {
      buffer.write(closer);
    }
    return buffer.toString();
  }

  static List<String> _importantTerms(String text) {
    const stopWords = {
      'yang',
      'dan',
      'atau',
      'dengan',
      'untuk',
      'dari',
      'pada',
      'dalam',
      'sebagai',
      'kelas',
      'topik',
      'materi',
      'contoh',
      'operasi',
    };

    return _normalize(text)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 4 && !stopWords.contains(word))
        .toSet()
        .take(8)
        .toList();
  }

  static List<String> _conceptPhrases(String text) {
    return text
        .split(RegExp(r'[,.]'))
        .map((part) => part.trim())
        .where((part) => part.length >= 6)
        .take(4)
        .toList();
  }

  static bool _hasMeaningPhrase(String normalizedAnswer, String topic) {
    final normalizedTopic = _normalize(topic);
    if (normalizedTopic.contains('pecahan')) {
      final hasFractionNotation = RegExp(
        r'\b\d+\s*/\s*\d+\b',
      ).hasMatch(normalizedAnswer);
      return normalizedAnswer.contains('bagian') &&
          (hasFractionNotation ||
              normalizedAnswer.contains('keseluruhan') ||
              normalizedAnswer.contains('utuh'));
    }
    if (normalizedTopic.contains('himpunan')) {
      return normalizedAnswer.contains('anggota') ||
          normalizedAnswer.contains('kumpulan');
    }
    if (normalizedTopic.contains('aljabar')) {
      return normalizedAnswer.contains('variabel') ||
          normalizedAnswer.contains('koefisien');
    }
    if (normalizedTopic.contains('rantai makanan')) {
      return normalizedAnswer.contains('energi') ||
          normalizedAnswer.contains('dimakan') ||
          normalizedAnswer.contains('produsen');
    }
    if (normalizedTopic.contains('gaya') || normalizedTopic.contains('gerak')) {
      return normalizedAnswer.contains('dorongan') ||
          normalizedAnswer.contains('tarikan') ||
          normalizedAnswer.contains('bergerak');
    }
    if (normalizedTopic.contains('gagasan') ||
        normalizedTopic.contains('paragraf')) {
      return normalizedAnswer.contains('ide utama') ||
          normalizedAnswer.contains('inti') ||
          normalizedAnswer.contains('kalimat utama');
    }
    if (normalizedTopic.contains('sejarah') ||
        normalizedTopic.contains('ekonomi') ||
        normalizedTopic.contains('geografi')) {
      return normalizedAnswer.contains('sebab') ||
          normalizedAnswer.contains('akibat') ||
          normalizedAnswer.contains('peristiwa');
    }
    if (normalizedTopic.contains('inggris') ||
        normalizedTopic.contains('english')) {
      return normalizedAnswer.contains('arti') ||
          normalizedAnswer.contains('kalimat') ||
          normalizedAnswer.contains('berarti');
    }
    if (normalizedTopic.contains('pkn') ||
        normalizedTopic.contains('kewarganegaraan') ||
        normalizedTopic.contains('musyawarah')) {
      return normalizedAnswer.contains('aturan') ||
          normalizedAnswer.contains('bersama') ||
          normalizedAnswer.contains('keputusan');
    }
    return false;
  }

  static String _nextQuestionFor(String topic, List<String> terms) {
    final normalizedTopic = _normalize(topic);
    if (normalizedTopic.contains('pecahan')) {
      return 'Jika pizza dibagi 8 potong dan kamu ambil 3, pecahannya ditulis bagaimana?';
    }
    if (normalizedTopic.contains('bilangan')) {
      return 'Beri satu contoh bilangan dari topik ini dan jelaskan alasannya.';
    }
    if (normalizedTopic.contains('himpunan')) {
      return 'Beri contoh 3 anggota dari satu himpunan sederhana.';
    }
    if (normalizedTopic.contains('rantai makanan')) {
      return 'Buat satu rantai makanan dengan 3 makhluk hidup.';
    }
    if (normalizedTopic.contains('gaya') || normalizedTopic.contains('gerak')) {
      return 'Sebutkan satu contoh dorongan atau tarikan di rumah.';
    }
    if (normalizedTopic.contains('gagasan') ||
        normalizedTopic.contains('paragraf')) {
      return 'Coba tulis satu kalimat utama dari paragraf pendek.';
    }
    if (normalizedTopic.contains('sejarah') ||
        normalizedTopic.contains('ekonomi') ||
        normalizedTopic.contains('geografi')) {
      return 'Sebutkan satu sebab dan satu akibat dari contoh topik ini.';
    }
    if (normalizedTopic.contains('inggris') ||
        normalizedTopic.contains('english')) {
      return 'Buat satu kalimat sederhana dalam Bahasa Inggris.';
    }
    if (normalizedTopic.contains('pkn') ||
        normalizedTopic.contains('kewarganegaraan') ||
        normalizedTopic.contains('musyawarah')) {
      return 'Beri satu contoh keputusan bersama di sekolah.';
    }
    final term = terms.firstOrNull ?? topic;
    return 'Beri satu contoh tentang $term dalam kehidupan sehari-hari.';
  }

  static String _exampleFor(String topic) {
    final normalizedTopic = _normalize(topic);
    if (normalizedTopic.contains('pecahan')) {
      return '3/8 berarti 3 dari 8 bagian yang sama besar.';
    }
    if (normalizedTopic.contains('bilangan')) {
      return '-2 berada di kiri 0 pada garis bilangan.';
    }
    if (normalizedTopic.contains('himpunan')) {
      return 'A = {2, 4, 6} adalah himpunan bilangan genap kecil.';
    }
    if (normalizedTopic.contains('aljabar')) {
      return 'Pada 3x + 2, x adalah variabel dan 3 adalah koefisien.';
    }
    if (normalizedTopic.contains('rantai makanan')) {
      return 'Rumput dimakan belalang, lalu belalang dimakan katak.';
    }
    if (normalizedTopic.contains('gaya') || normalizedTopic.contains('gerak')) {
      return 'Mendorong meja adalah gaya yang dapat membuat meja bergerak.';
    }
    if (normalizedTopic.contains('gagasan') ||
        normalizedTopic.contains('paragraf')) {
      return 'Dalam paragraf tentang banjir, ide utamanya bisa berupa penyebab banjir.';
    }
    if (normalizedTopic.contains('sejarah') ||
        normalizedTopic.contains('ekonomi') ||
        normalizedTopic.contains('geografi')) {
      return 'Jika harga beras naik, pengeluaran keluarga bisa ikut naik.';
    }
    if (normalizedTopic.contains('inggris') ||
        normalizedTopic.contains('english')) {
      return 'I read a book berarti saya membaca buku.';
    }
    if (normalizedTopic.contains('pkn') ||
        normalizedTopic.contains('kewarganegaraan') ||
        normalizedTopic.contains('musyawarah')) {
      return 'Musyawarah kelas dipakai untuk memilih jadwal piket bersama.';
    }
    return 'Satu contoh jelas yang menunjukkan arti $topic.';
  }

  static String _normalize(String text) => text.toLowerCase();

  static Future<void> _saveMetric(String key, String value) async {
    try {
      await DatabaseService.instance.saveModelStatus(key, value);
    } catch (_) {}
  }

  static String _sourceLabel(JsonModelStatus status) {
    return switch (status) {
      JsonModelStatus.timeout => 'timeout',
      JsonModelStatus.invalidJson => 'invalid_json',
      JsonModelStatus.modelError => 'model_error',
      JsonModelStatus.success => 'local_gemma',
    };
  }

  static int _intValue(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class _LocalQuizSpec {
  final String id;
  final String prompt;
  final String correctOption;
  final List<String> distractors;
  final String explanation;
  final String skillTag;
  final int difficulty;

  const _LocalQuizSpec({
    required this.id,
    required this.prompt,
    required this.correctOption,
    required this.distractors,
    required this.explanation,
    required this.skillTag,
    required this.difficulty,
  });

  QuizQuestion toQuestion(int index) {
    final options = [correctOption, ...distractors.take(3)];
    final correctIndex = index % options.length;
    final splitAt = options.length - correctIndex;
    final rotated = [...options.skip(splitAt), ...options.take(splitAt)];

    return QuizQuestion(
      id: id,
      prompt: prompt,
      options: rotated,
      correctIndex: correctIndex,
      explanation: explanation,
      skillTag: skillTag,
      difficulty: difficulty,
    );
  }
}
