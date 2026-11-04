import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Education levels
// ─────────────────────────────────────────────────────────────────────────────

class EducationLevel {
  static const sd = 'SD';
  static const smp = 'SMP';
  static const sma = 'SMA';

  static String fromGrade(int grade) {
    if (grade <= 6) return sd;
    if (grade <= 9) return smp;
    return sma;
  }

  static String label(int grade) {
    final level = fromGrade(grade);
    return '$level Kelas $grade';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject definition
// ─────────────────────────────────────────────────────────────────────────────

class SubjectData {
  final String key;
  final String name;
  final IconData icon;

  const SubjectData({
    required this.key,
    required this.name,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject lists per education level
// ─────────────────────────────────────────────────────────────────────────────

const List<SubjectData> _sdSubjects = [
  SubjectData(
    key: 'matematika',
    name: 'Matematika',
    icon: Icons.calculate_rounded,
  ),
  SubjectData(
    key: 'bahasa_indonesia',
    name: 'Bahasa Indonesia',
    icon: Icons.menu_book_rounded,
  ),
  SubjectData(key: 'ipa', name: 'IPA', icon: Icons.science_rounded),
  SubjectData(key: 'ips', name: 'IPS', icon: Icons.public_rounded),
  SubjectData(key: 'pkn', name: 'PKn', icon: Icons.account_balance_rounded),
  SubjectData(key: 'sbdp', name: 'SBdP', icon: Icons.palette_rounded),
];

const List<SubjectData> _smpSubjects = [
  SubjectData(
    key: 'matematika',
    name: 'Matematika',
    icon: Icons.calculate_rounded,
  ),
  SubjectData(
    key: 'bahasa_indonesia',
    name: 'Bahasa Indonesia',
    icon: Icons.menu_book_rounded,
  ),
  SubjectData(key: 'ipa', name: 'IPA', icon: Icons.science_rounded),
  SubjectData(key: 'ips', name: 'IPS', icon: Icons.public_rounded),
  SubjectData(
    key: 'bahasa_inggris',
    name: 'Bahasa Inggris',
    icon: Icons.translate_rounded,
  ),
  SubjectData(key: 'pkn', name: 'PKn', icon: Icons.account_balance_rounded),
];

const List<SubjectData> _smaSubjects = [
  SubjectData(
    key: 'matematika',
    name: 'Matematika',
    icon: Icons.calculate_rounded,
  ),
  SubjectData(
    key: 'bahasa_indonesia',
    name: 'Bahasa Indonesia',
    icon: Icons.menu_book_rounded,
  ),
  SubjectData(
    key: 'bahasa_inggris',
    name: 'Bahasa Inggris',
    icon: Icons.translate_rounded,
  ),
  SubjectData(key: 'fisika', name: 'Fisika', icon: Icons.bolt_rounded),
  SubjectData(key: 'kimia', name: 'Kimia', icon: Icons.biotech_rounded),
  SubjectData(key: 'biologi', name: 'Biologi', icon: Icons.eco_rounded),
  SubjectData(key: 'ekonomi', name: 'Ekonomi', icon: Icons.trending_up_rounded),
  SubjectData(key: 'sejarah', name: 'Sejarah', icon: Icons.history_edu_rounded),
  SubjectData(key: 'geografi', name: 'Geografi', icon: Icons.terrain_rounded),
  SubjectData(key: 'sosiologi', name: 'Sosiologi', icon: Icons.groups_rounded),
];

/// Returns the list of subjects for the given grade.
List<SubjectData> getSubjectsForGrade(int grade) {
  final level = EducationLevel.fromGrade(grade);
  switch (level) {
    case EducationLevel.sd:
      return _sdSubjects;
    case EducationLevel.smp:
      return _smpSubjects;
    case EducationLevel.sma:
      return _smaSubjects;
    default:
      return _sdSubjects;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic data — maps (subjectKey, grade) → list of topic names
// ─────────────────────────────────────────────────────────────────────────────

/// Returns topics for the given subject and grade.
List<String> getTopicsForSubjectAndGrade(String subjectKey, int grade) {
  final key = '${subjectKey}_$grade';
  return _topicMap[key] ?? ['Topik Umum'];
}

const Map<String, List<String>> _topicMap = {
  // ═══════════════════════════════════════════════════════════════════════════
  // SD — MATEMATIKA
  // ═══════════════════════════════════════════════════════════════════════════
  'matematika_1': [
    'Bilangan 1-20',
    'Penjumlahan Sederhana',
    'Pengurangan Sederhana',
    'Mengenal Bentuk',
    'Pola Bilangan',
  ],
  'matematika_2': [
    'Bilangan sampai 100',
    'Penjumlahan Bersusun',
    'Pengurangan Bersusun',
    'Pengukuran Waktu',
    'Pengenalan Perkalian',
  ],
  'matematika_3': [
    'Perkalian',
    'Pembagian',
    'Pengukuran (cm, m, kg)',
    'Pecahan Sederhana',
    'Bangun Datar',
  ],
  'matematika_4': [
    'Pecahan',
    'FPB dan KPK',
    'Pembulatan',
    'Bangun Ruang',
    'Pengukuran Sudut',
  ],
  'matematika_5': [
    'Operasi Pecahan',
    'Desimal',
    'Perbandingan',
    'Skala dan Denah',
    'Volume Bangun Ruang',
  ],
  'matematika_6': [
    'Bilangan Bulat',
    'Operasi Campuran',
    'Lingkaran',
    'Diagram dan Data',
    'Persiapan UN',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SD — BAHASA INDONESIA
  // ═══════════════════════════════════════════════════════════════════════════
  'bahasa_indonesia_1': [
    'Mengenal Huruf',
    'Membaca Suku Kata',
    'Menulis Kata',
    'Bercerita Sederhana',
    'Kosakata Dasar',
  ],
  'bahasa_indonesia_2': [
    'Membaca Cerita Pendek',
    'Menulis Kalimat',
    'Bercerita Pengalaman',
    'Puisi Anak',
    'Dongeng',
  ],
  'bahasa_indonesia_3': [
    'Paragraf',
    'Menulis Cerita',
    'Teks Deskripsi',
    'Petunjuk dan Instruksi',
    'Kalimat Tanya',
  ],
  'bahasa_indonesia_4': [
    'Teks Narasi',
    'Teks Laporan',
    'Kalimat Efektif',
    'Gagasan Pokok',
    'Surat Pribadi',
  ],
  'bahasa_indonesia_5': [
    'Teks Eksplanasi',
    'Pantun',
    'Iklan dan Poster',
    'Ringkasan',
    'Pidato',
  ],
  'bahasa_indonesia_6': [
    'Teks Persuasi',
    'Drama Pendek',
    'Puisi',
    'Teks Argumentasi',
    'Resensi Buku',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SD — IPA
  // ═══════════════════════════════════════════════════════════════════════════
  'ipa_1': [
    'Bagian Tubuh',
    'Hewan dan Tumbuhan',
    'Benda di Sekitar',
    'Cuaca',
    'Kebersihan',
  ],
  'ipa_2': [
    'Pertumbuhan Makhluk Hidup',
    'Sumber Energi',
    'Air dan Udara',
    'Siang dan Malam',
    'Lingkungan Sehat',
  ],
  'ipa_3': [
    'Ciri Makhluk Hidup',
    'Perubahan Wujud Benda',
    'Gerak dan Gaya',
    'Sumber Daya Alam',
    'Cuaca dan Iklim',
  ],
  'ipa_4': [
    'Ekosistem',
    'Rantai Makanan',
    'Sifat Cahaya',
    'Gaya dan Gerak',
    'Siklus Air',
  ],
  'ipa_5': [
    'Sistem Organ Manusia',
    'Adaptasi',
    'Sifat Bahan',
    'Pesawat Sederhana',
    'Listrik',
  ],
  'ipa_6': [
    'Tata Surya',
    'Reproduksi',
    'Campuran dan Larutan',
    'Magnet',
    'Perubahan Lingkungan',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SD — IPS
  // ═══════════════════════════════════════════════════════════════════════════
  'ips_1': [
    'Keluarga',
    'Lingkungan Rumah',
    'Lingkungan Sekolah',
    'Aturan di Rumah',
    'Kegiatan Sehari-hari',
  ],
  'ips_2': [
    'Peran Keluarga',
    'Lingkungan Tetangga',
    'Denah',
    'Pekerjaan',
    'Peristiwa Penting',
  ],
  'ips_3': [
    'Lingkungan Alam',
    'Denah dan Peta',
    'Jenis Pekerjaan',
    'Uang dan Menabung',
    'Keragaman Budaya',
  ],
  'ips_4': [
    'Sumber Daya Alam',
    'Kegiatan Ekonomi',
    'Kerajaan Hindu-Buddha',
    'Keragaman Indonesia',
    'Teknologi',
  ],
  'ips_5': [
    'Kerajaan Islam',
    'Tokoh Pahlawan',
    'Kegiatan Ekspor-Impor',
    'Interaksi Manusia',
    'Koperasi',
  ],
  'ips_6': [
    'ASEAN',
    'Globalisasi',
    'Proklamasi',
    'Persatuan dan Kesatuan',
    'Wirausaha',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SD — PKn
  // ═══════════════════════════════════════════════════════════════════════════
  'pkn_1': [
    'Aturan di Rumah dan Sekolah',
    'Sila Pancasila',
    'Tertib',
    'Hak dan Kewajiban',
    'Hidup Rukun',
  ],
  'pkn_2': [
    'Musyawarah',
    'Gotong Royong',
    'Menghargai Perbedaan',
    'Lingkungan Bersih',
    'Sikap Jujur',
  ],
  'pkn_3': [
    'Norma dalam Masyarakat',
    'Hak dan Kewajiban Warga',
    'Simbol Negara',
    'Keberagaman',
    'Tolong-Menolong',
  ],
  'pkn_4': [
    'Nilai Pancasila',
    'Sistem Pemerintahan Desa',
    'Hak Anak',
    'Patriotisme',
    'Gotong Royong',
  ],
  'pkn_5': [
    'Organisasi di Sekolah',
    'UUD 1945',
    'Persatuan',
    'Kebebasan Berpendapat',
    'NKRI',
  ],
  'pkn_6': [
    'Pemilu Sederhana',
    'Lembaga Negara',
    'Peran Warga Negara',
    'Globalisasi dan Identitas',
    'Bhinneka Tunggal Ika',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SD — SBdP
  // ═══════════════════════════════════════════════════════════════════════════
  'sbdp_1': [
    'Menggambar Bebas',
    'Bernyanyi',
    'Tepuk Tangan Berirama',
    'Prakarya Sederhana',
    'Warna Dasar',
  ],
  'sbdp_2': [
    'Kolase',
    'Lagu Daerah',
    'Gerakan Tari',
    'Prakarya dari Alam',
    'Pola dan Motif',
  ],
  'sbdp_3': [
    'Menggambar Dekoratif',
    'Alat Musik Ritmis',
    'Tarian Daerah',
    'Prakarya Kertas',
    'Seni Rupa',
  ],
  'sbdp_4': [
    'Gambar Ilustrasi',
    'Lagu Nasional',
    'Tari Nusantara',
    'Prakarya Tekstil',
    'Pameran Mini',
  ],
  'sbdp_5': [
    'Seni Rupa 2D dan 3D',
    'Musik Ansambel',
    'Tari Kreasi',
    'Drama Pendek',
    'Seni Grafis',
  ],
  'sbdp_6': [
    'Poster',
    'Paduan Suara',
    'Pentas Seni',
    'Prakarya Kreatif',
    'Apresiasi Seni',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMP — MATEMATIKA
  // ═══════════════════════════════════════════════════════════════════════════
  'matematika_7': [
    'Bilangan Bulat dan Pecahan',
    'Himpunan',
    'Bentuk Aljabar',
    'PLSV dan PtLSV',
    'Perbandingan',
    'Aritmetika Sosial',
    'Garis dan Sudut',
    'Segitiga dan Segiempat',
  ],
  'matematika_8': [
    'SPLDV',
    'Teorema Pythagoras',
    'Lingkaran',
    'Bangun Ruang Sisi Datar',
    'Relasi dan Fungsi',
    'Statistika Dasar',
    'Peluang',
  ],
  'matematika_9': [
    'Perpangkatan dan Akar',
    'Persamaan Kuadrat',
    'Fungsi Kuadrat',
    'Transformasi Geometri',
    'Kesebangunan',
    'Bangun Ruang Sisi Lengkung',
    'Statistika dan Peluang',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMP — BAHASA INDONESIA
  // ═══════════════════════════════════════════════════════════════════════════
  'bahasa_indonesia_7': [
    'Teks Deskripsi',
    'Teks Narasi',
    'Puisi Rakyat',
    'Fabel',
    'Surat Pribadi dan Dinas',
    'Laporan Observasi',
  ],
  'bahasa_indonesia_8': [
    'Teks Berita',
    'Teks Iklan',
    'Teks Eksposisi',
    'Teks Puisi',
    'Teks Eksplanasi',
    'Teks Ulasan',
    'Drama',
  ],
  'bahasa_indonesia_9': [
    'Teks Laporan Percobaan',
    'Pidato Persuasif',
    'Teks Cerpen',
    'Teks Diskusi',
    'Teks Tanggapan Kritis',
    'Sastra',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMP — IPA
  // ═══════════════════════════════════════════════════════════════════════════
  'ipa_7': [
    'Objek IPA dan Pengamatan',
    'Klasifikasi Makhluk Hidup',
    'Zat dan Karakteristiknya',
    'Suhu dan Pemuaian',
    'Kalor',
    'Energi',
    'Sistem Organisasi Kehidupan',
    'Ekosistem',
  ],
  'ipa_8': [
    'Gerak pada Makhluk Hidup',
    'Sistem Gerak Manusia',
    'Struktur dan Fungsi Tumbuhan',
    'Sistem Pencernaan',
    'Zat Aditif',
    'Tekanan',
    'Sistem Pernapasan',
    'Sistem Peredaran Darah',
  ],
  'ipa_9': [
    'Reproduksi',
    'Pewarisan Sifat',
    'Listrik Statis dan Dinamis',
    'Magnet dan Elektromagnet',
    'Bioteknologi',
    'Tata Surya',
    'Tanah',
    'Teknologi Ramah Lingkungan',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMP — IPS
  // ═══════════════════════════════════════════════════════════════════════════
  'ips_7': [
    'Manusia dan Lingkungan',
    'Interaksi Sosial',
    'Aktivitas Ekonomi',
    'Kerajaan Hindu-Buddha-Islam',
    'Kehidupan Masyarakat Praaksara',
  ],
  'ips_8': [
    'Pengaruh Interaksi Sosial',
    'Mobilitas Sosial',
    'Pluralitas Indonesia',
    'Perubahan Masyarakat',
    'Konflik dan Integrasi',
  ],
  'ips_9': [
    'Interaksi Antarnegara',
    'Perubahan Sosial Budaya',
    'Pembangunan Ekonomi',
    'Perdagangan Internasional',
    'Globalisasi',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMP — BAHASA INGGRIS
  // ═══════════════════════════════════════════════════════════════════════════
  'bahasa_inggris_7': [
    'Greetings and Introduction',
    'Describing People and Things',
    'Daily Routines',
    'Time and Numbers',
    'Short Messages',
    'Descriptive Text',
  ],
  'bahasa_inggris_8': [
    'Asking and Giving Information',
    'Invitation',
    'Personal Recount',
    'Narrative Text',
    'Song Lyrics',
    'Comparison',
  ],
  'bahasa_inggris_9': [
    'Congratulating and Complimenting',
    'Procedure Text',
    'Report Text',
    'Narrative Legends',
    'Advertisement',
    'Job Application',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMP — PKn
  // ═══════════════════════════════════════════════════════════════════════════
  'pkn_7': [
    'Norma dan Keadilan',
    'UUD 1945',
    'Keberagaman Suku dan Budaya',
    'Kerja Sama NKRI',
    'Daerah Tempat Tinggal',
  ],
  'pkn_8': [
    'Pancasila dan Kehidupan',
    'Konstitusi',
    'Tata Urutan Peraturan',
    'Semangat Kebangkitan Nasional',
    'Sumpah Pemuda',
  ],
  'pkn_9': [
    'Dinamika Perwujudan Pancasila',
    'Pokok Pikiran Pembukaan UUD',
    'Harmoni Keberagaman',
    'Bela Negara',
    'Ancaman Terhadap NKRI',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — MATEMATIKA
  // ═══════════════════════════════════════════════════════════════════════════
  'matematika_10': [
    'Persamaan dan Pertidaksamaan Linear',
    'Sistem Persamaan Linear',
    'Fungsi',
    'Trigonometri Dasar',
    'Logika Matematika',
    'Statistika',
  ],
  'matematika_11': [
    'Program Linear',
    'Matriks',
    'Transformasi',
    'Barisan dan Deret',
    'Limit Fungsi',
    'Turunan',
  ],
  'matematika_12': [
    'Integral',
    'Statistika Inferensial',
    'Distribusi Peluang',
    'Geometri Ruang',
    'Persamaan Lingkaran',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — BAHASA INDONESIA
  // ═══════════════════════════════════════════════════════════════════════════
  'bahasa_indonesia_10': [
    'Teks Laporan Observasi',
    'Teks Eksposisi',
    'Anekdot',
    'Hikayat',
    'Negosiasi',
    'Debat',
  ],
  'bahasa_indonesia_11': [
    'Teks Prosedur',
    'Teks Eksplanasi',
    'Ceramah',
    'Cerpen',
    'Proposal',
    'Karya Ilmiah',
  ],
  'bahasa_indonesia_12': [
    'Surat Lamaran',
    'Teks Editorial',
    'Artikel',
    'Novel',
    'Kritik Sastra',
    'Esai',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — BAHASA INGGRIS
  // ═══════════════════════════════════════════════════════════════════════════
  'bahasa_inggris_10': [
    'Self Introduction',
    'Congratulating',
    'Intention',
    'Descriptive Text',
    'Announcement',
    'Narrative Text',
  ],
  'bahasa_inggris_11': [
    'Offering Help',
    'Opinion and Thought',
    'Invitation',
    'Analytical Exposition',
    'Explanation Text',
    'Song',
  ],
  'bahasa_inggris_12': [
    'Application Letter',
    'Causality',
    'Hortatory Exposition',
    'News Item',
    'Review Text',
    'Caption',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — FISIKA
  // ═══════════════════════════════════════════════════════════════════════════
  'fisika_10': [
    'Pengukuran',
    'Vektor',
    'Gerak Lurus (GLB-GLBB)',
    'Hukum Newton',
    'Gerak Melingkar',
    'Elastisitas',
  ],
  'fisika_11': [
    'Kinematika',
    'Dinamika Rotasi',
    'Kesetimbangan',
    'Fluida',
    'Suhu dan Kalor',
    'Gelombang',
    'Bunyi',
    'Optik',
  ],
  'fisika_12': [
    'Listrik Statis',
    'Listrik Dinamis',
    'Medan Magnet',
    'Induksi Elektromagnetik',
    'Fisika Inti dan Radioaktivitas',
    'Fisika Modern',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — KIMIA
  // ═══════════════════════════════════════════════════════════════════════════
  'kimia_10': [
    'Struktur Atom',
    'Sistem Periodik Unsur',
    'Ikatan Kimia',
    'Stoikiometri',
    'Larutan Elektrolit',
    'Reaksi Redoks',
  ],
  'kimia_11': [
    'Termokimia',
    'Laju Reaksi',
    'Kesetimbangan Kimia',
    'Asam-Basa',
    'Hidrolisis',
    'Larutan Penyangga',
    'Kelarutan',
  ],
  'kimia_12': [
    'Sifat Koligatif',
    'Elektrokimia',
    'Kimia Unsur',
    'Senyawa Karbon',
    'Benzena',
    'Polimer',
    'Makromolekul',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — BIOLOGI
  // ═══════════════════════════════════════════════════════════════════════════
  'biologi_10': [
    'Keanekaragaman Hayati',
    'Virus',
    'Bakteri',
    'Protista',
    'Jamur',
    'Plantae',
    'Animalia',
    'Ekologi',
  ],
  'biologi_11': [
    'Sel',
    'Jaringan',
    'Sistem Gerak',
    'Sistem Peredaran Darah',
    'Sistem Pencernaan',
    'Sistem Pernapasan',
    'Sistem Ekskresi',
    'Sistem Saraf',
  ],
  'biologi_12': [
    'Pertumbuhan dan Perkembangan',
    'Metabolisme',
    'Genetika',
    'Evolusi',
    'Bioteknologi',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — EKONOMI
  // ═══════════════════════════════════════════════════════════════════════════
  'ekonomi_10': [
    'Konsep Dasar Ekonomi',
    'Masalah Ekonomi',
    'Peran Pelaku Ekonomi',
    'Permintaan dan Penawaran',
    'Pasar',
    'Bank dan Lembaga Keuangan',
  ],
  'ekonomi_11': [
    'Pendapatan Nasional',
    'APBN dan APBD',
    'Perpajakan',
    'Indeks Harga dan Inflasi',
    'Kebijakan Moneter dan Fiskal',
    'Ketenagakerjaan',
  ],
  'ekonomi_12': [
    'Akuntansi Dasar',
    'Siklus Akuntansi',
    'Jurnal',
    'Buku Besar',
    'Neraca',
    'Laporan Keuangan',
    'Manajemen',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — SEJARAH
  // ═══════════════════════════════════════════════════════════════════════════
  'sejarah_10': [
    'Konsep Sejarah',
    'Kehidupan Praaksara',
    'Kerajaan Hindu-Buddha',
    'Kerajaan Islam',
    'Penjelajahan Eropa',
  ],
  'sejarah_11': [
    'Kolonialisme',
    'Pergerakan Nasional',
    'Pendudukan Jepang',
    'Proklamasi',
    'Revolusi',
    'Demokrasi Liberal',
    'Orde Lama',
  ],
  'sejarah_12': [
    'Orde Baru',
    'Reformasi',
    'Indonesia Kontemporer',
    'Perkembangan IPTEK',
    'Indonesia di Dunia Internasional',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — GEOGRAFI
  // ═══════════════════════════════════════════════════════════════════════════
  'geografi_10': [
    'Pengetahuan Dasar Geografi',
    'Langkah Penelitian',
    'Bumi sebagai Planet',
    'Litosfer',
    'Atmosfer',
    'Hidrosfer',
  ],
  'geografi_11': [
    'Biosfer',
    'Antroposfer',
    'Sumber Daya Alam',
    'Lingkungan Hidup',
    'Mitigasi Bencana',
    'Penginderaan Jauh',
    'SIG',
  ],
  'geografi_12': [
    'Pola Keruangan Desa-Kota',
    'Interaksi Desa-Kota',
    'Wilayah dan Pewilayahan',
    'Negara Maju dan Berkembang',
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SMA — SOSIOLOGI
  // ═══════════════════════════════════════════════════════════════════════════
  'sosiologi_10': [
    'Sosiologi sebagai Ilmu',
    'Interaksi Sosial',
    'Nilai dan Norma',
    'Sosialisasi',
    'Lembaga Sosial',
  ],
  'sosiologi_11': [
    'Kelompok Sosial',
    'Konflik Sosial',
    'Struktur Sosial',
    'Diferensiasi dan Stratifikasi',
    'Mobilitas Sosial',
  ],
  'sosiologi_12': [
    'Perubahan Sosial',
    'Globalisasi',
    'Pemberdayaan Komunitas',
    'Ketimpangan Sosial',
    'Penelitian Sosial',
  ],
};
