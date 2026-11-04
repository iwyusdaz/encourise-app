import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../models/learning_models.dart';
import '../utils/encourise_theme.dart';

/// Full-screen session summary shown after a tutoring session ends.
class SessionSummaryScreen extends StatefulWidget {
  final String subject;
  final String topic;
  final int grade;
  final int correctAnswers;
  final int totalQuestions;
  final int xpEarned;
  final int finalLevel;
  final bool isFlagged;

  const SessionSummaryScreen({
    super.key,
    required this.subject,
    required this.topic,
    required this.grade,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.xpEarned,
    required this.finalLevel,
    required this.isFlagged,
  });

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  String _memorySummary = '';
  bool _memoryLoading = true;

  double get accuracy => widget.totalQuestions > 0
      ? widget.correctAnswers / widget.totalQuestions
      : 0.0;

  String get _grade {
    if (widget.grade <= 6) return 'SD Kelas ${widget.grade}';
    if (widget.grade <= 9) return 'SMP Kelas ${widget.grade}';
    return 'SMA Kelas ${widget.grade}';
  }

  String get _emoji {
    if (accuracy >= 0.9) return 'A+';
    if (accuracy >= 0.7) return 'A';
    if (accuracy >= 0.5) return 'B';
    return 'R';
  }

  String get _message {
    if (accuracy >= 0.9) return 'Kamu sudah kuat di topik ini.';
    if (accuracy >= 0.7) return 'Pemahamanmu sudah baik; lanjutkan latihan.';
    if (accuracy >= 0.5) {
      return 'Ulangi bagian yang salah, lalu coba soal sejenis.';
    }
    return 'Mulai ulang dari konsep inti, lalu kerjakan satu contoh sederhana.';
  }

  Color get _scoreColor {
    if (accuracy >= 0.7) return EncouriseColors.success;
    if (accuracy >= 0.5) return EncouriseColors.primary;
    return EncouriseColors.error;
  }

  @override
  void initState() {
    super.initState();
    _generateMemoryUpdate();
  }

  Future<void> _generateMemoryUpdate() async {
    try {
      final db = DatabaseService.instance;
      final student = await db.getStudent();
      final studentId = student?['id'] as String? ?? 'unknown';

      // Load existing memory
      final existing = await db.getLearnerMemory(studentId);
      final existingProfile = LearnerProfile.fromJsonString(
        existing?['profile_json'] as String? ?? '{}',
      );

      final percent = (accuracy * 100).round();
      final summary = accuracy >= 0.8
          ? '${widget.topic}: kuat dengan akurasi $percent%. Pertahankan dengan 2-3 soal latihan baru.'
          : '${widget.topic}: perlu review dengan akurasi $percent%. Ulangi konsep inti lalu kerjakan contoh sederhana.';
      final profile = LearnerProfile(
        strengths: _mergeUnique(
          existingProfile.strengths,
          accuracy >= 0.8 ? [widget.topic] : const [],
        ),
        weaknesses: _mergeUnique(
          existingProfile.weaknesses,
          accuracy < 0.7 ? [widget.topic] : const [],
        ),
        preferredExamples: existingProfile.preferredExamples,
        tone: existingProfile.tone,
        reviewTopics: _mergeUnique(
          existingProfile.reviewTopics,
          (widget.isFlagged || accuracy < 0.8) ? [widget.topic] : const [],
        ),
      );

      // Persist
      await db.saveLearnerMemory({
        'student_id': studentId,
        'summary_text': summary,
        'profile_json': jsonEncode(profile.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _memorySummary = summary;
          _memoryLoading = false;
        });
      }
    } catch (e) {
      // Don't crash — memory is best-effort
      // ignore: avoid_print
      print('[SessionSummary] Memory generation failed: $e');
      if (mounted) setState(() => _memoryLoading = false);
    }
  }

  List<String> _mergeUnique(List<String> oldItems, List<String> newItems) {
    final seen = <String>{};
    return [...oldItems, ...newItems]
        .where((item) => item.trim().isNotEmpty)
        .where((item) => seen.add(item.toLowerCase()))
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final subjectNames = {
      'matematika': 'Matematika',
      'bahasa_indonesia': 'Bahasa Indonesia',
      'ipa': 'IPA',
      'ips': 'IPS',
      'pkn': 'PKn',
      'sbdp': 'SBdP',
      'bahasa_inggris': 'Bahasa Inggris',
      'fisika': 'Fisika',
      'kimia': 'Kimia',
      'biologi': 'Biologi',
      'ekonomi': 'Ekonomi',
      'sejarah': 'Sejarah',
      'geografi': 'Geografi',
      'sosiologi': 'Sosiologi',
    };
    final subjectName = subjectNames[widget.subject] ?? widget.subject;

    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: Column(
        children: [
          // ── Gradient hero ─────────────────────────────────────────
          _buildHero(subjectName),

          // ── Scrollable content ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                children: [
                  // ── Stats grid ─────────────────────────────────────
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Benar',
                        value:
                            '${widget.correctAnswers}/${widget.totalQuestions}',
                        color: _scoreColor,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.percent_rounded,
                        label: 'Akurasi',
                        value: '${(accuracy * 100).toStringAsFixed(0)}%',
                        color: _scoreColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.star_rounded,
                        label: 'XP Didapat',
                        value: '+${widget.xpEarned}',
                        color: EncouriseColors.xpGold,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Level Akhir',
                        value: '${widget.finalLevel}',
                        color: EncouriseColors.levelPurple,
                      ),
                    ],
                  ),

                  // ── Learner memory card ─────────────────────────────
                  if (_memorySummary.isNotEmpty || _memoryLoading) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: EncouriseColors.primarySurface,
                        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
                      ),
                      child: _memoryLoading
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: EncouriseColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Budi sedang meringkas progress belajarmu…',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: EncouriseColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        gradient: EncouriseGradients.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.psychology_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Catatan Budi',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: EncouriseColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _memorySummary,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: EncouriseColors.textPrimary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],

                  if (widget.isFlagged) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: EncouriseColors.errorLight,
                        borderRadius: BorderRadius.circular(EncouriseRadius.md),
                        border: Border.all(
                          color: EncouriseColors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_rounded,
                            color: EncouriseColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Topik ini ditandai untuk review nanti',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: EncouriseColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Button ────────────────────────────────────────
                  EncouriseGradientButton(
                    label: 'Kembali ke Beranda',
                    icon: Icons.home_rounded,
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero header ─────────────────────────────────────────────────

  Widget _buildHero(String subjectName) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: EncouriseColors.primarySurface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
          child: Column(
            children: [
              // Emoji badge
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: EncouriseColors.primaryLight,
                    width: 2,
                  ),
                  boxShadow: EncouriseShadows.soft,
                ),
                child: Center(
                  child: Text(_emoji, style: const TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sesi Selesai!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: EncouriseColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: EncouriseColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              // Topic pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                  border: Border.all(color: EncouriseColors.border),
                ),
                child: Text(
                  '${widget.topic} • $subjectName • $_grade',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: EncouriseColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stat card ───────────────────────────────────────────────────

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: EncouriseColors.surface,
          borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: EncouriseColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
