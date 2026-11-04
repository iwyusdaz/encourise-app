/// Defines the tutoring mode for a session.
enum TutoringMode {
  /// Socratic method — Budi guides the student through questions.
  socratic,

  /// Quiz mode — Budi generates a set of questions for self-testing.
  quiz,

  /// Guided learning — multi-step structured learning journey.
  guided,
}

/// Configures how a tutoring session behaves.
///
/// Different modes change the system prompt, greeting, adapter usage,
/// and session labelling without duplicating screen logic.
class TutoringCapability {
  /// Which mode this capability represents.
  final TutoringMode mode;

  /// Human-readable label for the mode (shown in UI).
  final String modeLabel;

  /// Whether the [DifficultyAdapter] is active during this session.
  final bool useAdapter;

  /// Database value for the `mode` column in the sessions table.
  final String sessionType;

  const TutoringCapability._({
    required this.mode,
    required this.modeLabel,
    required this.useAdapter,
    required this.sessionType,
  });

  // -----------------------------------------------------------------------
  // Factory presets
  // -----------------------------------------------------------------------

  /// Standard Socratic tutoring — the default mode.
  static const socratic = TutoringCapability._(
    mode: TutoringMode.socratic,
    modeLabel: 'Pahami',
    useAdapter: true,
    sessionType: 'tutoring',
  );

  /// Self-test quiz with a fixed number of questions.
  static const quiz = TutoringCapability._(
    mode: TutoringMode.quiz,
    modeLabel: 'Tes Diri',
    useAdapter: true,
    sessionType: 'quiz',
  );

  /// Structured multi-step guided learning journey.
  static const guided = TutoringCapability._(
    mode: TutoringMode.guided,
    modeLabel: 'Jalur Belajar',
    useAdapter: false,
    sessionType: 'guided',
  );

  // -----------------------------------------------------------------------
  // Greeting prompt (first user message sent to Gemma)
  // -----------------------------------------------------------------------

  /// Returns the first user-role message to kick off the session.
  String buildGreeting({
    required String topic,
    required String studentName,
    int questionCount = 5,
    int currentStep = 0,
    String stepTitle = '',
  }) {
    switch (mode) {
      case TutoringMode.socratic:
        return 'Mulai pelajaran $topic. '
            'Jangan pakai sapaan. Mulai dengan arti konsep dalam 1 kalimat, '
            'beri satu contoh sederhana, lalu ajukan satu pertanyaan konkret.';

      case TutoringMode.quiz:
        return 'Buat kuis tentang topik $topic. '
            'Tampilkan 1 soal pilihan ganda yang jelas dan tidak ambigu. '
            'Setiap pilihan harus berbeda makna dan hanya satu yang benar. '
            'Tunggu jawaban siswa, beri alasan singkat yang menjelaskan konsep, lalu lanjut ke soal berikutnya. '
            'Total $questionCount soal. Jangan pakai sapaan atau emoji.';

      case TutoringMode.guided:
        if (currentStep == 0) {
          return 'Kita akan belajar topik $topic secara terstruktur. '
              'Rancang 3 langkah belajar untuk topik ini. '
              'Balas dalam format JSON array: '
              '[{"step":1,"title":"...","description":"..."},{"step":2,"title":"...","description":"..."},{"step":3,"title":"...","description":"..."}]. '
              'Hanya JSON, tidak ada teks lain.';
        }
        return 'Kita lanjut ke langkah $currentStep: "$stepTitle". '
            'Balas dengan format: Konsep, Contoh, Tugas. '
            'Tugas harus kecil dan bisa dijawab "$studentName" dalam 1-2 kalimat. '
            'Jangan pakai sapaan, emoji, atau penjelasan panjang.';
    }
  }
}
