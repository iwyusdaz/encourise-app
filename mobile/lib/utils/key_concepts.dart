// Key concepts per topic for prompt injection.
//
// Each entry provides a short curriculum-aligned context string (~100-200 chars)
// that is injected into Budi's system prompt to ground responses.
// Key format: `${subjectKey}_${grade}_${topicName}`

/// Returns a short key-concepts string for prompt injection.
String getKeyConcepts(String subjectKey, int grade, String topic) {
  final key = '${subjectKey}_${grade}_$topic';
  return _keyConceptsMap[key] ?? '';
}

const Map<String, String> _keyConceptsMap = {
  // SD — MATEMATIKA
  'matematika_1_Bilangan 1-20':
      'Mengenal angka 1-20, membilang maju-mundur, membandingkan besar-kecil, mengurutkan bilangan.',
  'matematika_1_Penjumlahan Sederhana':
      'Penjumlahan bilangan 1-20, konsep menggabungkan, simbol +, hasil penjumlahan.',
  'matematika_1_Pengurangan Sederhana':
      'Pengurangan bilangan 1-20, konsep mengambil, simbol -, sisa pengurangan.',
  'matematika_1_Mengenal Bentuk':
      'Bentuk dasar: lingkaran, segitiga, persegi, persegi panjang. Mengenali bentuk di sekitar.',
  'matematika_1_Pola Bilangan':
      'Pola sederhana: berulang, bertambah 1 atau 2. Melanjutkan pola bilangan.',
  'matematika_2_Bilangan sampai 100':
      'Bilangan 1-100, nilai tempat puluhan-satuan, membandingkan dan mengurutkan.',
  'matematika_2_Penjumlahan Bersusun':
      'Penjumlahan bersusun pendek dan panjang, tanpa dan dengan menyimpan.',
  'matematika_2_Pengurangan Bersusun':
      'Pengurangan bersusun pendek dan panjang, tanpa dan dengan meminjam.',
  'matematika_2_Pengukuran Waktu':
      'Membaca jam analog, jam-menit, konversi jam ke menit, durasi waktu.',
  'matematika_2_Pengenalan Perkalian':
      'Perkalian sebagai penjumlahan berulang. 3×4 = 4+4+4. Tabel perkalian 1-5.',
  'matematika_3_Perkalian':
      'Tabel perkalian 1-10, sifat komutatif (3×4=4×3), perkalian bersusun.',
  'matematika_3_Pembagian':
      'Pembagian sebagai kebalikan perkalian, pembagian bersusun, sisa pembagian.',
  'matematika_3_Pengukuran (cm, m, kg)':
      'Satuan panjang cm dan m, satuan berat gram dan kg, konversi sederhana.',
  'matematika_3_Pecahan Sederhana':
      'Pecahan ½, ⅓, ¼. Pecahan sebagai bagian dari keseluruhan. Membandingkan pecahan.',
  'matematika_3_Bangun Datar':
      'Persegi, persegi panjang, segitiga, lingkaran. Sisi, sudut, keliling sederhana.',
  'matematika_4_Pecahan':
      'Pecahan senilai, menyederhanakan pecahan, membandingkan pecahan beda penyebut.',
  'matematika_4_FPB dan KPK':
      'Faktor, kelipatan, FPB (faktor persekutuan terbesar), KPK (kelipatan persekutuan terkecil).',
  'matematika_4_Pembulatan':
      'Pembulatan ke puluhan, ratusan, ribuan terdekat. Aturan pembulatan ≥5.',
  'matematika_4_Bangun Ruang':
      'Kubus, balok, tabung, kerucut, bola. Sisi, rusuk, titik sudut.',
  'matematika_4_Pengukuran Sudut':
      'Jenis sudut: lancip, siku-siku, tumpul. Mengukur dengan busur derajat.',
  'matematika_5_Operasi Pecahan':
      'Penjumlahan dan pengurangan pecahan beda penyebut menggunakan KPK. Pecahan campuran.',
  'matematika_5_Desimal':
      'Pecahan desimal, konversi pecahan biasa ke desimal, operasi desimal.',
  'matematika_5_Perbandingan':
      'Perbandingan dua besaran, penyederhanaan, perbandingan senilai.',
  'matematika_5_Skala dan Denah':
      'Skala peta, menghitung jarak sebenarnya dari peta, membaca denah.',
  'matematika_5_Volume Bangun Ruang':
      'Volume kubus = s³, volume balok = p×l×t, satuan cm³ dan liter.',
  'matematika_6_Bilangan Bulat':
      'Bilangan bulat positif dan negatif, garis bilangan, operasi bilangan bulat.',
  'matematika_6_Operasi Campuran':
      'Urutan operasi (KaBaTaKu), tanda kurung, operasi campuran +−×÷.',
  'matematika_6_Lingkaran':
      'Jari-jari, diameter, keliling = π×d, luas = π×r², π ≈ 3,14 atau 22/7.',
  'matematika_6_Diagram dan Data':
      'Diagram batang, diagram lingkaran, rata-rata (mean), modus, median.',
  'matematika_6_Persiapan UN':
      'Review soal UN: pecahan, geometri, pengukuran, statistika dasar.',

  // SD — BAHASA INDONESIA (representative)
  'bahasa_indonesia_1_Mengenal Huruf':
      'Huruf vokal (a,i,u,e,o) dan konsonan. Mengenal huruf besar dan kecil.',
  'bahasa_indonesia_1_Membaca Suku Kata':
      'Suku kata terbuka (ba, bi, bu) dan tertutup (ban, bin). Membaca kata 2 suku kata.',
  'bahasa_indonesia_1_Menulis Kata':
      'Menulis huruf dengan benar, menulis kata sederhana, spasi antar kata.',
  'bahasa_indonesia_1_Bercerita Sederhana':
      'Menceritakan pengalaman dengan kalimat pendek, urutan kejadian.',
  'bahasa_indonesia_1_Kosakata Dasar':
      'Kata benda, kata kerja, kata sifat sederhana dalam kehidupan sehari-hari.',
  'bahasa_indonesia_4_Teks Narasi':
      'Struktur narasi: orientasi, komplikasi, resolusi. Tokoh, latar, alur.',
  'bahasa_indonesia_4_Teks Laporan':
      'Struktur laporan observasi: deskripsi umum, deskripsi bagian, simpulan.',
  'bahasa_indonesia_4_Kalimat Efektif':
      'Kalimat memiliki subjek dan predikat, tidak bertele-tele, bermakna jelas.',
  'bahasa_indonesia_4_Gagasan Pokok':
      'Gagasan pokok = ide utama paragraf. Biasanya di kalimat pertama atau terakhir.',
  'bahasa_indonesia_4_Surat Pribadi':
      'Bagian surat: tanggal, salam pembuka, isi, salam penutup, tanda tangan.',

  // SD — IPA (representative)
  'ipa_4_Ekosistem':
      'Komponen biotik (makhluk hidup) dan abiotik (benda mati). Hubungan antar makhluk hidup.',
  'ipa_4_Rantai Makanan':
      'Produsen → konsumen I → konsumen II → pengurai. Jaring-jaring makanan.',
  'ipa_4_Sifat Cahaya':
      'Cahaya merambat lurus, dapat dipantulkan, dibiaskan, dan diuraikan.',
  'ipa_4_Gaya dan Gerak':
      'Gaya = dorongan/tarikan. Gaya gravitasi, gesek, pegas. Pengaruh gaya terhadap gerak.',
  'ipa_4_Siklus Air':
      'Evaporasi, kondensasi, presipitasi, infiltrasi. Siklus air di alam.',
  'ipa_5_Sistem Organ Manusia':
      'Sistem pencernaan, pernapasan, peredaran darah. Organ utama dan fungsinya.',
  'ipa_5_Adaptasi':
      'Adaptasi morfologi, fisiologi, tingkah laku. Contoh: kaktus, bunglon, beruang.',
  'ipa_5_Sifat Bahan':
      'Konduktor dan isolator panas/listrik. Sifat bahan: keras, lunak, elastis.',
  'ipa_5_Pesawat Sederhana':
      'Tuas, bidang miring, katrol, roda berporos. Keuntungan mekanis.',
  'ipa_5_Listrik':
      'Rangkaian seri dan paralel, sumber listrik, penghantar dan penyekat.',
  'ipa_6_Tata Surya':
      'Matahari sebagai pusat, 8 planet, revolusi dan rotasi bumi, fase bulan.',
  'ipa_6_Reproduksi':
      'Perkembangbiakan generatif (kawin) dan vegetatif (tak kawin) pada tumbuhan dan hewan.',
  'ipa_6_Campuran dan Larutan':
      'Larutan homogen vs heterogen, pelarut dan terlarut, penyaringan, penguapan.',
  'ipa_6_Magnet':
      'Kutub utara-selatan, gaya tarik-tolak, bahan magnetik dan non-magnetik.',
  'ipa_6_Perubahan Lingkungan':
      'Pencemaran air, udara, tanah. Dampak aktivitas manusia. Pelestarian.',

  // SMP — MATEMATIKA
  'matematika_7_Bilangan Bulat dan Pecahan':
      'Operasi bilangan bulat, sifat operasi, pecahan biasa/campuran/desimal, operasi pecahan.',
  'matematika_7_Himpunan':
      'Notasi himpunan, anggota, himpunan bagian, irisan (∩), gabungan (∪), komplemen.',
  'matematika_7_Bentuk Aljabar':
      'Variabel, koefisien, konstanta, suku. Penjumlahan, pengurangan, perkalian aljabar.',
  'matematika_7_PLSV dan PtLSV':
      'Persamaan linear satu variabel (ax+b=c). Pertidaksamaan linear (<, >, ≤, ≥).',
  'matematika_7_Perbandingan':
      'Perbandingan senilai dan berbalik nilai. Rumus perbandingan. Skala.',
  'matematika_7_Aritmetika Sosial':
      'Harga jual, harga beli, untung, rugi, diskon, pajak, bunga tunggal.',
  'matematika_7_Garis dan Sudut':
      'Garis sejajar, berpotongan, berhimpit. Sudut sehadap, berseberangan, sepihak.',
  'matematika_7_Segitiga dan Segiempat':
      'Jenis segitiga, jenis segiempat, keliling dan luas, Teorema sudut.',
  'matematika_8_SPLDV':
      'Sistem persamaan linear dua variabel. Metode substitusi, eliminasi, grafik.',
  'matematika_8_Teorema Pythagoras':
      'a²+b²=c² untuk segitiga siku-siku. Triple Pythagoras. Aplikasi jarak.',
  'matematika_8_Lingkaran':
      'Unsur lingkaran, keliling=2πr, luas=πr², busur, juring, tembereng.',
  'matematika_8_Bangun Ruang Sisi Datar':
      'Kubus, balok, prisma, limas. Jaring-jaring, luas permukaan, volume.',
  'matematika_8_Relasi dan Fungsi':
      'Relasi, fungsi, domain, kodomain, range. Notasi f(x). Grafik fungsi linear.',
  'matematika_8_Statistika Dasar':
      'Mean, median, modus. Penyajian data: tabel, diagram batang, lingkaran.',
  'matematika_8_Peluang':
      'Ruang sampel, kejadian, peluang = kejadian/total. Frekuensi relatif.',
  'matematika_9_Perpangkatan dan Akar':
      'Sifat pangkat: aᵐ×aⁿ=aᵐ⁺ⁿ, pangkat negatif, akar kuadrat dan pangkat tiga.',
  'matematika_9_Persamaan Kuadrat':
      'ax²+bx+c=0. Faktorisasi, melengkapkan kuadrat, rumus abc. Diskriminan.',
  'matematika_9_Fungsi Kuadrat':
      'Grafik parabola, titik puncak, sumbu simetri, titik potong sumbu.',
  'matematika_9_Transformasi Geometri':
      'Translasi (geser), refleksi (cermin), rotasi (putar), dilatasi (skala).',
  'matematika_9_Kesebangunan':
      'Syarat kesebangunan segitiga (sisi-sisi, sudut-sudut). Perbandingan sisi.',
  'matematika_9_Bangun Ruang Sisi Lengkung':
      'Tabung, kerucut, bola. Luas permukaan dan volume masing-masing.',
  'matematika_9_Statistika dan Peluang':
      'Kuartil, jangkauan, simpangan. Peluang kejadian majemuk.',

  // SMP — IPA
  'ipa_7_Objek IPA dan Pengamatan':
      'Metode ilmiah, pengamatan, pengukuran, besaran pokok dan turunan.',
  'ipa_7_Klasifikasi Makhluk Hidup':
      'Kingdom: Monera, Protista, Fungi, Plantae, Animalia. Kunci dikotomi.',
  'ipa_7_Zat dan Karakteristiknya':
      'Unsur, senyawa, campuran. Sifat fisika dan kimia. Perubahan fisika dan kimia.',
  'ipa_7_Suhu dan Pemuaian':
      'Termometer, skala Celsius/Fahrenheit/Kelvin. Pemuaian panjang, luas, volume.',
  'ipa_7_Kalor':
      'Kalor = m×c×ΔT. Kalor jenis, kapasitas kalor. Perpindahan: konduksi, konveksi, radiasi.',
  'ipa_7_Energi':
      'Energi kinetik, potensial. Hukum kekekalan energi. Konversi energi.',
  'ipa_7_Sistem Organisasi Kehidupan':
      'Sel→jaringan→organ→sistem organ→organisme. Organel sel.',
  'ipa_7_Ekosistem':
      'Komponen biotik-abiotik, rantai makanan, jaring makanan, piramida ekologi.',
  'ipa_8_Gerak pada Makhluk Hidup':
      'Gerak pada tumbuhan (tropisme, nasti) dan hewan (otot, rangka).',
  'ipa_8_Sistem Gerak Manusia':
      'Tulang, sendi, otot. Kelainan: osteoporosis, skoliosis, fraktur.',
  'ipa_8_Struktur dan Fungsi Tumbuhan':
      'Akar, batang, daun, bunga. Fotosintesis. Transportasi pada tumbuhan.',
  'ipa_8_Sistem Pencernaan':
      'Mulut→kerongkongan→lambung→usus halus→usus besar. Enzim pencernaan.',
  'ipa_8_Zat Aditif':
      'Pewarna, pengawet, penyedap, pemanis. Zat aditif alami vs buatan. Bahaya.',
  'ipa_8_Tekanan':
      'Tekanan zat padat (F/A), tekanan hidrostatis (ρgh), tekanan udara, hukum Pascal.',
  'ipa_8_Sistem Pernapasan':
      'Hidung→faring→laring→trakea→bronkus→paru-paru. Pertukaran gas O₂ dan CO₂.',
  'ipa_8_Sistem Peredaran Darah':
      'Jantung 4 ruang, arteri, vena, kapiler. Peredaran besar dan kecil.',

  // SMA — MATEMATIKA
  'matematika_10_Persamaan dan Pertidaksamaan Linear':
      'Persamaan linear satu variabel, pertidaksamaan, nilai mutlak, penyelesaian grafik.',
  'matematika_10_Sistem Persamaan Linear':
      'SPLTV: 3 variabel. Metode eliminasi-substitusi. Matriks augmented.',
  'matematika_10_Fungsi':
      'Domain, kodomain, range. Fungsi linear, kuadrat. Komposisi fungsi, fungsi invers.',
  'matematika_10_Trigonometri Dasar':
      'Sin, cos, tan. Sudut istimewa 30°, 45°, 60°. Identitas trigonometri dasar.',
  'matematika_10_Logika Matematika':
      'Pernyataan, negasi, konjungsi, disjungsi, implikasi, biimplikasi. Tabel kebenaran.',
  'matematika_10_Statistika':
      'Ukuran pemusatan dan penyebaran data tunggal dan kelompok. Simpangan baku.',
  'matematika_11_Program Linear':
      'Fungsi objektif, kendala, daerah fisibel, titik pojok, nilai optimum.',
  'matematika_11_Matriks':
      'Operasi matriks, determinan, invers matriks 2×2 dan 3×3.',
  'matematika_11_Transformasi':
      'Translasi, refleksi, rotasi, dilatasi dalam koordinat. Matriks transformasi.',
  'matematika_11_Barisan dan Deret':
      'Barisan aritmetika (Un=a+(n-1)b), geometri (Un=arⁿ⁻¹). Jumlah n suku.',
  'matematika_11_Limit Fungsi':
      'Konsep limit, limit tak hingga, limit fungsi aljabar, teorema limit.',
  'matematika_11_Turunan':
      'f\'(x) = lim Δx→0 [f(x+Δx)-f(x)]/Δx. Aturan turunan. Aplikasi: gradien, optimasi.',
  'matematika_12_Integral':
      'Integral tak tentu ∫f(x)dx, integral tentu, teorema fundamental kalkulus. Luas daerah.',
  'matematika_12_Statistika Inferensial':
      'Populasi, sampel, distribusi sampling, interval kepercayaan.',
  'matematika_12_Distribusi Peluang':
      'Distribusi binomial, distribusi normal, nilai harapan, simpangan baku.',
  'matematika_12_Geometri Ruang':
      'Jarak titik-garis-bidang, sudut antara garis dan bidang, bidang dalam ruang.',
  'matematika_12_Persamaan Lingkaran':
      '(x-a)²+(y-b)²=r². Persamaan garis singgung. Posisi titik terhadap lingkaran.',

  // SMA — FISIKA
  'fisika_10_Pengukuran':
      'Besaran pokok dan turunan, satuan SI, angka penting, ketidakpastian pengukuran.',
  'fisika_10_Vektor':
      'Penjumlahan vektor, penguraian komponen x-y, resultan, perkalian dot dan cross.',
  'fisika_10_Gerak Lurus (GLB-GLBB)':
      'GLB: v konstan. GLBB: a konstan. v=v₀+at, s=v₀t+½at², v²=v₀²+2as.',
  'fisika_10_Hukum Newton':
      'Newton I (inersia), II (F=ma), III (aksi-reaksi). Gaya normal, gesek, berat.',
  'fisika_10_Gerak Melingkar':
      'Kecepatan sudut ω, percepatan sentripetal a=v²/r, frekuensi, periode.',
  'fisika_10_Elastisitas':
      'Hukum Hooke F=kx, tegangan, regangan, modulus Young, energi pegas.',
  'fisika_11_Kinematika':
      'Gerak parabola, gerak melingkar berubah beraturan, analisis vektor kecepatan.',
  'fisika_11_Dinamika Rotasi':
      'Momen gaya τ=F×r, momen inersia, momentum sudut, kesetimbangan rotasi.',
  'fisika_11_Kesetimbangan':
      'Syarat setimbang: ΣF=0, Στ=0. Titik berat, tuas, kesetimbangan benda tegar.',
  'fisika_11_Fluida':
      'Tekanan hidrostatis, hukum Pascal, Archimedes, Bernoulli. Viskositas.',
  'fisika_11_Suhu dan Kalor':
      'Pemuaian, kalor jenis, perubahan wujud, kalor laten, Asas Black.',
  'fisika_11_Gelombang':
      'Gelombang transversal dan longitudinal, amplitudo, frekuensi, panjang gelombang.',
  'fisika_11_Bunyi':
      'Cepat rambat bunyi, resonansi, efek Doppler, intensitas bunyi.',
  'fisika_11_Optik':
      'Pemantulan, pembiasan, lensa, cermin. Hukum Snellius. Alat optik.',
  'fisika_12_Listrik Statis':
      'Hukum Coulomb F=kq₁q₂/r², medan listrik, potensial listrik, kapasitor.',
  'fisika_12_Listrik Dinamis':
      'Hukum Ohm V=IR, rangkaian seri-paralel, hukum Kirchhoff, daya listrik P=VI.',
  'fisika_12_Medan Magnet':
      'Gaya Lorentz, medan magnet kawat, solenoida, aplikasi motor listrik.',
  'fisika_12_Induksi Elektromagnetik':
      'Hukum Faraday, hukum Lenz, GGL induksi, generator, transformator.',
  'fisika_12_Fisika Inti dan Radioaktivitas':
      'Struktur inti, peluruhan α/β/γ, waktu paruh, reaksi fisi dan fusi.',
  'fisika_12_Fisika Modern':
      'Efek fotolistrik, dualisme gelombang-partikel, teori relativitas khusus.',

  // SMA — KIMIA
  'kimia_10_Struktur Atom':
      'Model atom Dalton→Thomson→Rutherford→Bohr→mekanika kuantum. Nomor atom, massa atom.',
  'kimia_10_Sistem Periodik Unsur':
      'Golongan, periode, sifat periodik: jari-jari, keelektronegatifan, energi ionisasi.',
  'kimia_10_Ikatan Kimia':
      'Ikatan ion, kovalen, logam. Struktur Lewis, bentuk molekul VSEPR.',
  'kimia_10_Stoikiometri':
      'Mol, massa molar, hukum Avogadro, pereaksi pembatas, rendemen.',
  'kimia_10_Larutan Elektrolit':
      'Elektrolit kuat/lemah, non-elektrolit. Uji daya hantar listrik.',
  'kimia_10_Reaksi Redoks':
      'Oksidasi (lepas elektron), reduksi (terima elektron), bilangan oksidasi.',
  'kimia_11_Termokimia':
      'Reaksi eksoterm dan endoterm, entalpi, hukum Hess, kalor reaksi.',
  'kimia_11_Laju Reaksi':
      'Faktor: konsentrasi, suhu, katalis, luas permukaan. Orde reaksi.',
  'kimia_11_Kesetimbangan Kimia':
      'Kc, Kp, prinsip Le Chatelier, pergeseran kesetimbangan.',
  'kimia_11_Asam-Basa':
      'Teori Arrhenius, Brønsted-Lowry, Lewis. pH = -log[H⁺]. Indikator.',
  'kimia_11_Hidrolisis':
      'Hidrolisis garam dari asam/basa kuat/lemah. Sifat larutan garam.',
  'kimia_11_Larutan Penyangga':
      'Buffer asam (asam lemah + garamnya), buffer basa. pH buffer.',
  'kimia_11_Kelarutan':
      'Ksp (hasil kali kelarutan), pengaruh ion senama, pengendapan.',
  'kimia_12_Sifat Koligatif':
      'Penurunan tekanan uap, kenaikan titik didih, penurunan titik beku, tekanan osmotik.',
  'kimia_12_Elektrokimia':
      'Sel volta (menghasilkan listrik), sel elektrolisis, hukum Faraday.',
  'kimia_12_Kimia Unsur':
      'Unsur golongan utama dan transisi, sifat, pembuatan, kegunaan.',
  'kimia_12_Senyawa Karbon':
      'Alkana, alkena, alkuna. Isomer, reaksi substitusi, adisi, eliminasi.',
  'kimia_12_Benzena':
      'Struktur benzena, sifat aromatik, reaksi substitusi elektrofilik.',
  'kimia_12_Polimer':
      'Polimer adisi dan kondensasi. Contoh: plastik, karet, nilon.',
  'kimia_12_Makromolekul':
      'Karbohidrat, protein, lemak, asam nukleat. Struktur dan fungsi biologis.',

  // SMA — BIOLOGI
  'biologi_10_Keanekaragaman Hayati':
      'Keanekaragaman gen, jenis, ekosistem. Klasifikasi 5 kingdom. Binomial nomenklatur.',
  'biologi_10_Virus':
      'Struktur virus, reproduksi litik dan lisogenik. Contoh: HIV, influenza, COVID.',
  'biologi_10_Bakteri':
      'Prokariotik, struktur sel bakteri, reproduksi, peran menguntungkan dan merugikan.',
  'biologi_10_Protista':
      'Protista mirip hewan (protozoa), mirip tumbuhan (alga), mirip jamur.',
  'biologi_10_Jamur':
      'Struktur hifa dan miselium, reproduksi spora, klasifikasi, simbiosis.',
  'biologi_10_Plantae':
      'Lumut, paku, biji (gymnospermae, angiospermae). Siklus hidup tumbuhan.',
  'biologi_10_Animalia':
      'Invertebrata dan vertebrata. Filum utama. Ciri dan klasifikasi.',
  'biologi_10_Ekologi':
      'Populasi, komunitas, ekosistem, biosfer. Siklus biogeokimia.',
  'biologi_11_Sel':
      'Organel sel: nukleus, mitokondria, ribosom, RE, Golgi. Sel prokariotik vs eukariotik.',
  'biologi_11_Jaringan':
      'Jaringan tumbuhan (meristem, parenkim, kolenkim) dan hewan (epitel, otot, saraf).',
  'biologi_11_Sistem Gerak':
      'Tulang, sendi, otot rangka. Mekanisme kontraksi otot. Kelainan.',
  'biologi_11_Sistem Peredaran Darah':
      'Jantung, pembuluh darah, darah. Golongan darah ABO, Rhesus.',
  'biologi_11_Sistem Pencernaan':
      'Saluran pencernaan, kelenjar pencernaan, enzim, penyerapan nutrisi.',
  'biologi_11_Sistem Pernapasan':
      'Mekanisme inspirasi-ekspirasi, pertukaran gas, volume paru-paru.',
  'biologi_11_Sistem Ekskresi':
      'Ginjal (nefron), hati, paru-paru, kulit. Pembentukan urine.',
  'biologi_11_Sistem Saraf':
      'Neuron, sinapsis, SSP (otak dan sumsum), saraf tepi, gerak refleks.',
  'biologi_12_Pertumbuhan dan Perkembangan':
      'Fase pertumbuhan, hormon pertumbuhan, faktor internal dan eksternal.',
  'biologi_12_Metabolisme':
      'Katabolisme (respirasi sel, glikolisis, Krebs, rantai elektron) dan anabolisme (fotosintesis).',
  'biologi_12_Genetika':
      'Hukum Mendel I dan II, genotip, fenotip, persilangan monohibrid dan dihibrid.',
  'biologi_12_Evolusi':
      'Teori Darwin, seleksi alam, bukti evolusi, mekanisme evolusi.',
  'biologi_12_Bioteknologi':
      'Bioteknologi konvensional (fermentasi) dan modern (rekayasa genetika, PCR, kloning).',
};
