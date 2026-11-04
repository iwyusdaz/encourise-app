class AnswerQualityIssue {
  final String code;
  final String message;

  const AnswerQualityIssue(this.code, this.message);
}

class AnswerQualityValidator {
  AnswerQualityValidator._();

  static const _fillerOpenings = [
    'hai',
    'halo',
    'oke',
    'ok',
    'baik',
    'tentu',
    'siap',
    'wah',
    'keren',
  ];

  static List<AnswerQualityIssue> validateLearningAnswer(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _looksLikeJson(trimmed)) return const [];

    final lower = trimmed.toLowerCase();
    final issues = <AnswerQualityIssue>[];

    if (_fillerOpenings.any(
      (word) => RegExp('^$word[,.!\\s]', caseSensitive: false).hasMatch(lower),
    )) {
      issues.add(
        const AnswerQualityIssue(
          'filler_opening',
          'Jawaban dimulai dengan sapaan atau pembuka kosong.',
        ),
      );
    }

    if (RegExp(r'\\\(|\\\[|\\frac|\\times|\\div').hasMatch(trimmed)) {
      issues.add(
        const AnswerQualityIssue('latex', 'Jawaban memakai format LaTeX.'),
      );
    }

    if (RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true).hasMatch(trimmed)) {
      issues.add(const AnswerQualityIssue('emoji', 'Jawaban memakai emoji.'));
    }

    if (trimmed.length > 360) {
      issues.add(
        const AnswerQualityIssue('too_long', 'Jawaban terlalu panjang.'),
      );
    }

    final hasExample =
        lower.contains('contoh') ||
        RegExp(r'\b\d+\s*/\s*\d+\b').hasMatch(lower) ||
        RegExp(r'\bmisalnya\b').hasMatch(lower);
    if (!hasExample) {
      issues.add(
        const AnswerQualityIssue(
          'missing_example',
          'Jawaban belum memberi contoh konkret.',
        ),
      );
    }

    final hasNextTask =
        lower.contains('coba') ||
        lower.contains('tugas') ||
        lower.contains('pertanyaan') ||
        trimmed.endsWith('?');
    if (!hasNextTask) {
      issues.add(
        const AnswerQualityIssue(
          'missing_next_task',
          'Jawaban belum memberi langkah berikutnya.',
        ),
      );
    }

    final vagueOnly = [
      'semangat',
      'bagus',
      'kamu pasti bisa',
      'jangan menyerah',
      'terus belajar',
    ].any(lower.contains);
    final hasConceptSignal =
        lower.contains('berarti') ||
        lower.contains('adalah') ||
        lower.contains('karena') ||
        lower.contains('menunjukkan') ||
        lower.contains('digunakan');
    if (vagueOnly && !hasConceptSignal) {
      issues.add(
        const AnswerQualityIssue(
          'vague_praise',
          'Jawaban berisi motivasi tanpa isi belajar yang jelas.',
        ),
      );
    }

    return issues;
  }

  static String enforceLearningAnswer(String text, {required String topic}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _looksLikeJson(trimmed)) return text;
    final issues = validateLearningAnswer(trimmed);
    final severe = issues.any(
      (issue) =>
          issue.code == 'filler_opening' ||
          issue.code == 'latex' ||
          issue.code == 'emoji' ||
          issue.code == 'vague_praise',
    );
    if (!severe) return trimmed;

    final cleaned = trimmed
        .replaceFirst(
          RegExp(
            r'^\s*(?:hai|halo|oke|ok|baik|tentu|siap|wah|keren)[,!\.\s]+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return cleaned.length >= 24 ? cleaned : fallbackLearningAnswer(topic);
  }

  static String fallbackLearningAnswer(String topic) {
    final lower = topic.toLowerCase();
    if (lower.contains('pecahan')) {
      return 'Pecahan berarti bagian dari satu utuh; contoh 3/8 berarti 3 dari 8 bagian yang sama besar. Coba tulis satu contoh pecahan lain.';
    }
    if (lower.contains('bilangan')) {
      return 'Bilangan membantu menunjukkan nilai atau urutan; contoh -2 berada di kiri 0 pada garis bilangan. Coba jelaskan arti satu bilangan negatif.';
    }
    if (lower.contains('gaya') || lower.contains('gerak')) {
      return 'Gaya adalah dorongan atau tarikan; contoh mendorong meja membuat meja bergerak. Coba sebutkan satu gaya di sekitarmu.';
    }
    if (lower.contains('rantai makanan')) {
      return 'Rantai makanan menunjukkan aliran energi; contoh rumput dimakan belalang, lalu belalang dimakan katak. Coba lanjutkan satu rantai makanan.';
    }
    if (lower.contains('gagasan') || lower.contains('paragraf')) {
      return 'Gagasan pokok adalah ide utama paragraf; contoh paragraf tentang banjir biasanya memiliki ide utama penyebab atau akibat banjir. Coba cari kalimat utamanya.';
    }
    if (lower.contains('sejarah') || lower.contains('ips')) {
      return 'Topik ini dipahami lewat sebab, peristiwa, dan akibat; contoh perubahan ekonomi bisa memengaruhi pekerjaan warga. Coba sebutkan satu sebab dan akibatnya.';
    }
    if (lower.contains('english') || lower.contains('inggris')) {
      return 'Bahasa Inggris dipahami lewat arti dan contoh kalimat; contoh “I read a book” berarti “Saya membaca buku.” Coba buat satu kalimat sederhana.';
    }
    if (lower.contains('pkn') || lower.contains('kewarganegaraan')) {
      return 'PKn membahas aturan dan sikap warga negara; contoh musyawarah dipakai untuk mengambil keputusan bersama. Coba beri satu contoh musyawarah di sekolah.';
    }
    return '$topic berarti konsep yang perlu dipahami lewat arti, contoh, dan latihan. Coba jelaskan satu contoh $topic dengan kalimatmu sendiri.';
  }

  static bool _looksLikeJson(String text) {
    final trimmed = text.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }
}
