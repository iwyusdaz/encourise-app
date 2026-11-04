import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../utils/encourise_theme.dart';

/// Onboarding screen shown on first launch.
/// Captures student name and grade level (1–12).
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  int _selectedGrade = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty && _selectedGrade > 0;

  Future<void> _save() async {
    if (!_canContinue || _isSaving) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final db = DatabaseService.instance;

    await db.saveStudent({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'grade': _selectedGrade,
      'language': 'id',
      'created_at': DateTime.now().toIso8601String(),
    });

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: Column(
        children: [
          // ── Welcome hero header ─────────────────────────────────
          _buildHero(),

          // ── Form content ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Name input ─────────────────────────────────────
                  Text(
                    'Siapa namamu?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: EncouriseColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: EncouriseColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Andi',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: EncouriseColors.textMuted,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 16, right: 10),
                        child: Icon(
                          Icons.person_rounded,
                          color: EncouriseColors.primary,
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 48),
                      filled: true,
                      fillColor: EncouriseColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(EncouriseRadius.xl),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(EncouriseRadius.xl),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(EncouriseRadius.xl),
                        borderSide: const BorderSide(
                          color: EncouriseColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Grade picker ───────────────────────────────────
                  Text(
                    'Kamu kelas berapa?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: EncouriseColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildLevelSection('SD', 'Sekolah Dasar', 1, 6),
                  const SizedBox(height: 12),
                  _buildLevelSection('SMP', 'Sekolah Menengah Pertama', 7, 9),
                  const SizedBox(height: 12),
                  _buildLevelSection('SMA', 'Sekolah Menengah Atas', 10, 12),
                  const SizedBox(height: 32),

                  // ── Continue button ─────────────────────────────────
                  AnimatedOpacity(
                    opacity: _canContinue ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: EncouriseGradientButton(
                      label: 'Mulai Belajar',
                      onPressed: _canContinue ? _save : null,
                      isLoading: _isSaving,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gradient hero ──────────────────────────────────────────────

  Widget _buildHero() {
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
                  boxShadow: EncouriseShadows.elevated,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 44,
                  color: EncouriseColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Selamat Datang di\nEncourise!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: EncouriseColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'AI tutor pribadimu — belajar kapan saja,\ndi mana saja, tanpa internet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: EncouriseColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Level section with grade chips ────────────────────────────

  Widget _buildLevelSection(
    String level,
    String subtitle,
    int startGrade,
    int endGrade,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: EncouriseGradients.primary,
                  borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                ),
                child: Text(
                  level,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: EncouriseColors.textOnPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: EncouriseColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(endGrade - startGrade + 1, (i) {
              final grade = startGrade + i;
              final selected = _selectedGrade == grade;
              return GestureDetector(
                onTap: () => setState(() => _selectedGrade = grade),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: selected ? EncouriseGradients.primary : null,
                    color: selected ? null : EncouriseColors.background,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected ? EncouriseShadows.button : null,
                  ),
                  child: Center(
                    child: Text(
                      '$grade',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? EncouriseColors.textOnPrimary
                            : EncouriseColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
