import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/database_service.dart';
import '../utils/curriculum_data.dart';
import '../utils/encourise_theme.dart';
import 'free_chat_screen.dart';

/// Profile and app settings overview.
class SettingsScreen extends StatefulWidget {
  final bool isTab;
  final SettingsScreenTestData? testData;

  const SettingsScreen({super.key, this.isTab = false, this.testData});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  int _grade = 5;
  String _studentId = '';
  String _createdAt = '';
  String _teachingStyle = 'encouraging';
  Map<String, String> _modelStatus = {};
  Map<String, int> _syncSummary = const {'pending': 0, 'highestRetry': 0};
  bool _isLoading = true;
  bool _showTechnicalDetails = false;
  int _streak = 0;
  int _totalXp = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final testData = widget.testData;
    if (testData != null) {
      if (!mounted) return;
      setState(() {
        _studentId = testData.studentId;
        _createdAt = DateTime.now().toIso8601String();
        _nameController.text = testData.studentName;
        _grade = testData.grade;
        _teachingStyle = testData.teachingStyle;
        _modelStatus = testData.modelStatus;
        _syncSummary = testData.syncSummary;
        _showTechnicalDetails = testData.showTechnicalDetails;
        _streak = testData.streak;
        _totalXp = testData.totalXp;
        _isLoading = false;
      });
      return;
    }

    final db = DatabaseService.instance;
    final modelStatus = await db.getModelStatus();
    final syncSummary = await db.getSyncQueueSummary();
    final student = await db.getStudent();
    final studentId = student?['id'] as String? ?? '';
    final sessions = studentId.isEmpty
        ? <Map<String, dynamic>>[]
        : await db.getSessionHistory(studentId);

    var totalXp = 0;
    final sessionDays = <String>{};
    for (final session in sessions) {
      totalXp += session['xp_earned'] as int? ?? 0;
      final startedAt = session['started_at'] as String? ?? '';
      if (startedAt.isEmpty) continue;
      try {
        final date = DateTime.parse(startedAt).toLocal();
        sessionDays.add('${date.year}-${date.month}-${date.day}');
      } catch (_) {}
    }

    var streak = 0;
    if (sessionDays.isNotEmpty) {
      final now = DateTime.now();
      for (var i = 0; i < 365; i++) {
        final day = now.subtract(Duration(days: i));
        final key = '${day.year}-${day.month}-${day.day}';
        if (sessionDays.contains(key)) {
          streak++;
        } else if (i > 0) {
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _studentId = studentId;
      _createdAt = student?['created_at'] as String? ?? '';
      _nameController.text = student?['name'] as String? ?? '';
      _grade = student?['grade'] as int? ?? 5;
      _teachingStyle = student?['teaching_style'] as String? ?? 'encouraging';
      _modelStatus = modelStatus;
      _syncSummary = syncSummary;
      _streak = streak;
      _totalXp = totalXp;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile({
    bool showSnackBar = false,
    String message = 'Profil disimpan',
  }) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final studentId = _studentId.isNotEmpty
        ? _studentId
        : 'local_${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = _createdAt.isNotEmpty ? _createdAt : now;

    await DatabaseService.instance.saveStudent({
      'id': studentId,
      'name': name,
      'grade': _grade,
      'language': 'id',
      'teaching_style': _teachingStyle,
      'created_at': createdAt,
    });

    if (!mounted) return;
    setState(() {
      _studentId = studentId;
      _createdAt = createdAt;
    });

    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        ),
        title: Text(
          'Reset Semua Data?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ini akan menghapus semua progress belajar, XP, '
          'dan riwayat sesi. Tindakan ini tidak bisa dibatalkan.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: EncouriseColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: EncouriseColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: EncouriseColors.error),
            child: Text(
              'Reset',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.clearAllData();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: EncouriseColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: EncouriseColors.primary,
            backgroundColor: EncouriseColors.primary.withValues(alpha: 0.15),
          ),
        ),
      );
    }

    final level = EducationLevel.fromGrade(_grade);
    final name = _nameController.text.trim();

    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          cacheExtent: 1800,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 112),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildTopBar(),
                  const SizedBox(height: 22),
                  _buildProfileCard(name, level),
                  const SizedBox(height: 24),
                  _buildTeachingStyleSection(),
                  const SizedBox(height: 20),
                  _buildAppSection(),
                  const SizedBox(height: 20),
                  _buildAccountDataSection(),
                  const SizedBox(height: 26),
                  Center(
                    child: Text(
                      'Encourise v2.1.1\nPowered by Gemma 4 E2B',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: EncouriseColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        if (!widget.isTab) ...[
          _buildIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
            semanticLabel: 'Kembali',
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            'Profil',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: EncouriseColors.textPrimary,
            ),
          ),
        ),
        _buildIconButton(
          icon: Icons.settings_outlined,
          onTap: _showAppDetailsSheet,
          semanticLabel: 'Pengaturan aplikasi',
        ),
      ],
    );
  }

  Widget _buildProfileCard(String name, String level) {
    final displayName = name.isNotEmpty ? name : 'Siswa';
    final levelNumber = (_totalXp ~/ 120) + 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.xl),
        border: Border.all(
          color: EncouriseColors.border.withValues(alpha: 0.7),
        ),
        boxShadow: EncouriseShadows.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildAvatar(displayName, size: 82),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: EncouriseColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$level Kelas $_grade',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: EncouriseColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTinyMetric(
                          icon: Icons.stars_rounded,
                          label: 'Level $levelNumber',
                          color: EncouriseColors.xpGold,
                        ),
                        _buildTinyMetric(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Streak $_streak hari',
                          color: EncouriseColors.streakOrange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildEditProfileButton(),
            ],
          ),
          const SizedBox(height: 18),
          _buildLearningAction(),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, {required double size}) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EncouriseColors.primarySurface,
        border: Border.all(
          color: EncouriseColors.primaryLight.withValues(alpha: 0.75),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: EncouriseColors.primary,
        ),
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return Semantics(
      button: true,
      label: 'Edit profil siswa',
      child: Material(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.md),
        child: InkWell(
          onTap: _showEditProfileSheet,
          borderRadius: BorderRadius.circular(EncouriseRadius.md),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(EncouriseRadius.md),
              border: Border.all(color: EncouriseColors.border),
            ),
            child: const Icon(
              Icons.edit_outlined,
              size: 22,
              color: EncouriseColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLearningAction() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openLearning,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EncouriseColors.primarySurface,
            borderRadius: BorderRadius.circular(EncouriseRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: EncouriseGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: EncouriseColors.textOnDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lanjut belajar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: EncouriseColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Budi siap membantu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: EncouriseColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: EncouriseColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTinyMetric({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: EncouriseColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTeachingStyleSection() {
    return _buildPlainSection(
      title: 'Gaya Budi',
      trailing: _buildSavedBadge('Tersimpan'),
      child: _buildStyleSelector(),
    );
  }

  Widget _buildStyleSelector() {
    const styles = [
      _TeachingStyleOption(
        keyName: 'encouraging',
        icon: Icons.favorite_rounded,
        label: 'Penyemangat',
        desc: 'Hangat',
        color: EncouriseColors.primary,
      ),
      _TeachingStyleOption(
        keyName: 'socratic',
        icon: Icons.lightbulb_rounded,
        label: 'Sokratik',
        desc: 'Bertanya',
        color: EncouriseColors.warning,
      ),
      _TeachingStyleOption(
        keyName: 'structured',
        icon: Icons.format_list_bulleted_rounded,
        label: 'Terstruktur',
        desc: 'Runtut',
        color: EncouriseColors.subjectBlue,
      ),
    ];

    return Row(
      children: styles.map((style) {
        final selected = _teachingStyle == style.keyName;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: style != styles.last ? 10 : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (_teachingStyle == style.keyName) return;
                  setState(() => _teachingStyle = style.keyName);
                  await _saveProfile();
                },
                borderRadius: BorderRadius.circular(EncouriseRadius.lg),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 122,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? EncouriseColors.primarySurface
                        : EncouriseColors.surface,
                    borderRadius: BorderRadius.circular(EncouriseRadius.lg),
                    border: Border.all(
                      color: selected
                          ? EncouriseColors.primary
                          : EncouriseColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected ? EncouriseShadows.soft : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (selected)
                        const Positioned(
                          right: 0,
                          top: 0,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: EncouriseColors.primary,
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                style.icon,
                                size: 30,
                                color: style.color,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 20,
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  style.label,
                                  maxLines: 1,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? EncouriseColors.primary
                                        : EncouriseColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 16,
                              child: Text(
                                style.desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: EncouriseColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAppSection() {
    final pending = _syncSummary['pending'] ?? 0;
    final retry = _syncSummary['highestRetry'] ?? 0;
    final reminderTime = _formatDateTime(_modelStatus['last_reminder_time']);
    final reminderResult = _modelStatus['last_reminder_result'] ?? 'belum ada';
    final pathStatus = _modelStatus['model_path_status'] ?? 'belum terbaca';
    final compatible = _modelStatus['mtp_model_compatible'] == 'true';
    final startupMs = _formatMs(_modelStatus['app_start_to_home_ms']);
    final discoveryMs = _formatMs(_modelStatus['model_discovery_time_ms']);
    final firstToken = _formatSeconds(
      _modelStatus['last_time_to_first_token_seconds'],
    );
    final tokenSpeed = _modelStatus['last_decode_tokens_per_second'];
    final chatMs = _formatMs(_modelStatus['last_chat_total_time_ms']);
    final timedOut = _modelStatus['last_chat_timed_out'] == 'true';
    final syncResult = _modelStatus['last_sync_result'] ?? 'belum ada';

    return _buildPlainSection(
      title: 'Aplikasi',
      child: Container(
        decoration: BoxDecoration(
          color: EncouriseColors.surface,
          borderRadius: BorderRadius.circular(EncouriseRadius.xl),
          border: Border.all(
            color: EncouriseColors.border.withValues(alpha: 0.7),
          ),
          boxShadow: EncouriseShadows.soft,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
              child: Row(
                children: [
                  _buildStatusTile(
                    icon: Icons.memory_rounded,
                    title: 'Gemma 4 E2B',
                    value: compatible ? 'MTP siap' : 'Periksa model',
                  ),
                  _buildVerticalDivider(),
                  _buildStatusTile(
                    icon: Icons.sync_rounded,
                    title: 'Sinkronisasi',
                    value: '$pending menunggu',
                  ),
                  _buildVerticalDivider(),
                  _buildStatusTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Pengingat',
                    value: reminderTime == 'belum ada' ? '-' : reminderTime,
                  ),
                  _buildVerticalDivider(),
                  _buildStatusTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Status',
                    value: timedOut ? 'Cepat' : 'Siap',
                    valueColor: timedOut
                        ? EncouriseColors.warning
                        : EncouriseColors.primary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: EncouriseColors.divider),
            _buildExpandableDetailsHeader(
              title: 'Kesehatan Aplikasi',
              subtitle: timedOut
                  ? 'Ada jawaban yang memakai bantuan cepat'
                  : 'Siap dipakai untuk belajar',
            ),
            if (_showTechnicalDetails) ...[
              const Divider(height: 1, color: EncouriseColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(
                  children: [
                    _buildInfoRow('Antrian sync', '$pending item'),
                    _buildInfoRow(
                      'Pengingat',
                      '$reminderResult • $reminderTime',
                    ),
                    _buildInfoRow('Model', pathStatus),
                    _buildInfoRow('Buka aplikasi', startupMs),
                    _buildInfoRow('Retry tertinggi', '$retry'),
                    _buildInfoRow('Sync terakhir', syncResult),
                    _buildInfoRow('Cari model', discoveryMs),
                    _buildInfoRow(
                      'Flow terakhir',
                      _modelStatus['last_chat_flow'] ?? '-',
                    ),
                    _buildInfoRow('Total flow', chatMs),
                    _buildInfoRow('Token pertama', firstToken),
                    _buildInfoRow(
                      'Kecepatan token',
                      tokenSpeed == null ? '-' : '$tokenSpeed tok/dtk',
                    ),
                    _buildInfoRow(
                      'Sumber kuis',
                      _modelStatus['last_quiz_generation_source'] ?? '-',
                    ),
                    _buildInfoRow(
                      'Sumber evaluasi',
                      _modelStatus['last_tutor_evaluation_source'] ?? '-',
                    ),
                    _buildInfoRow(
                      'Reminder target',
                      _payloadTarget(_modelStatus['last_reminder_payload']),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: EncouriseColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: EncouriseColors.primary),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: EncouriseColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: valueColor ?? EncouriseColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 64,
      color: EncouriseColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _buildExpandableDetailsHeader({
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            setState(() => _showTechnicalDetails = !_showTechnicalDetails),
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: EncouriseColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: EncouriseColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _showTechnicalDetails
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: EncouriseColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDataSection() {
    return _buildPlainSection(
      title: 'Akun & data',
      child: Container(
        decoration: BoxDecoration(
          color: EncouriseColors.surface,
          borderRadius: BorderRadius.circular(EncouriseRadius.lg),
          border: Border.all(
            color: EncouriseColors.error.withValues(alpha: 0.18),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _confirmReset,
            borderRadius: BorderRadius.circular(EncouriseRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: EncouriseColors.errorLight,
                      borderRadius: BorderRadius.circular(EncouriseRadius.md),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: EncouriseColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reset data belajar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: EncouriseColors.error,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: EncouriseColors.error,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlainSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: EncouriseColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildSavedBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: EncouriseColors.primarySurface,
        borderRadius: BorderRadius.circular(EncouriseRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_rounded,
            size: 14,
            color: EncouriseColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: EncouriseColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EncouriseRadius.md),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: EncouriseColors.textPrimary, size: 27),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileSheet() async {
    final localNameController = TextEditingController(
      text: _nameController.text.trim(),
    );
    var localGrade = _grade;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                decoration: const BoxDecoration(
                  color: EncouriseColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: EncouriseColors.border,
                              borderRadius: BorderRadius.circular(
                                EncouriseRadius.pill,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Edit profil',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: EncouriseColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                              color: EncouriseColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Nama',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: EncouriseColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: localNameController,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: EncouriseColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.person_rounded,
                              color: EncouriseColors.primary,
                            ),
                            hintText: 'Nama siswa',
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Kelas',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: EncouriseColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSheetGradeSelector(
                          selectedGrade: localGrade,
                          onChanged: (grade) =>
                              setSheetState(() => localGrade = grade),
                        ),
                        const SizedBox(height: 24),
                        EncouriseGradientButton(
                          label: 'Simpan Profil',
                          icon: Icons.check_rounded,
                          onPressed: () async {
                            final nextName = localNameController.text.trim();
                            if (nextName.isEmpty) return;
                            setState(() {
                              _nameController.text = nextName;
                              _grade = localGrade;
                            });
                            await _saveProfile(
                              showSnackBar: true,
                              message: 'Profil disimpan',
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    localNameController.dispose();
  }

  Widget _buildSheetGradeSelector({
    required int selectedGrade,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        _buildSheetGradeRow('SD', 1, 6, selectedGrade, onChanged),
        const SizedBox(height: 10),
        _buildSheetGradeRow('SMP', 7, 9, selectedGrade, onChanged),
        const SizedBox(height: 10),
        _buildSheetGradeRow('SMA', 10, 12, selectedGrade, onChanged),
      ],
    );
  }

  Widget _buildSheetGradeRow(
    String label,
    int start,
    int end,
    int selectedGrade,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EncouriseColors.primarySurface,
            borderRadius: BorderRadius.circular(EncouriseRadius.md),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: EncouriseColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(end - start + 1, (i) {
              final grade = start + i;
              final selected = selectedGrade == grade;
              return GestureDetector(
                onTap: () => onChanged(grade),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected ? EncouriseGradients.primary : null,
                    color: selected ? null : EncouriseColors.surface,
                    borderRadius: BorderRadius.circular(EncouriseRadius.md),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : EncouriseColors.border,
                    ),
                    boxShadow: selected ? EncouriseShadows.soft : null,
                  ),
                  child: Text(
                    '$grade',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? EncouriseColors.textOnPrimary
                          : EncouriseColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Future<void> _showAppDetailsSheet() async {
    final wasOpen = _showTechnicalDetails;
    setState(() => _showTechnicalDetails = true);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: EncouriseColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: EncouriseColors.border,
                      borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Detail aplikasi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: EncouriseColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Kesehatan Aplikasi terbuka di halaman Profil.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: EncouriseColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                EncouriseGradientButton(
                  label: 'Lihat Detail',
                  icon: Icons.keyboard_arrow_down_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!wasOpen && mounted) setState(() {});
  }

  void _openLearning() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FreeChatScreen(grade: _grade)));
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: EncouriseColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: EncouriseColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMs(String? value) {
    final ms = int.tryParse(value ?? '');
    if (ms == null) return '-';
    if (ms < 1000) return '$ms ms';
    return '${(ms / 1000).toStringAsFixed(1)} dtk';
  }

  String _formatSeconds(String? value) {
    final seconds = double.tryParse(value ?? '');
    if (seconds == null) return '-';
    return '${seconds.toStringAsFixed(2)} dtk';
  }

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return 'belum ada';
    try {
      final dt = DateTime.parse(value).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  String _payloadTarget(String? payload) {
    if (payload == null || payload.isEmpty || payload == '{}') return 'beranda';
    if (payload.contains('"guided"')) return 'jalur belajar';
    if (payload.contains('"quiz"')) return 'tes diri';
    if (payload.contains('"tutoring"')) return 'belajar';
    return 'beranda';
  }
}

class _TeachingStyleOption {
  final String keyName;
  final IconData icon;
  final String label;
  final String desc;
  final Color color;

  const _TeachingStyleOption({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
  });
}

class SettingsScreenTestData {
  final String studentId;
  final String studentName;
  final int grade;
  final String teachingStyle;
  final Map<String, String> modelStatus;
  final Map<String, int> syncSummary;
  final bool showTechnicalDetails;
  final int streak;
  final int totalXp;

  const SettingsScreenTestData({
    this.studentId = 'test_student',
    this.studentName = 'Ayu',
    this.grade = 5,
    this.teachingStyle = 'encouraging',
    this.modelStatus = const {},
    this.syncSummary = const {'pending': 0, 'highestRetry': 0},
    this.showTechnicalDetails = false,
    this.streak = 0,
    this.totalXp = 0,
  });
}
