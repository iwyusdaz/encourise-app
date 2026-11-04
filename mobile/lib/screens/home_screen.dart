import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/learning_models.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/curriculum_data.dart';
import '../utils/encourise_theme.dart';
import 'free_chat_screen.dart';
import 'guided_learning_screen.dart';
import 'topic_list_screen.dart';

/// Main dashboard for the Kelas Tenang redesign.
class HomeScreen extends StatefulWidget {
  final bool isTab;
  final HomeScreenTestData? testData;
  final Future<bool> Function()? reminderScheduler;

  const HomeScreen({
    super.key,
    this.isTab = false,
    this.testData,
    this.reminderScheduler,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class HomeScreenTestData {
  final String studentName;
  final int grade;
  final int streak;
  final int totalXp;
  final int weeklyXp;
  final int totalSessions;
  final String memorySummary;
  final Map<String, dynamic>? openGuidedSession;
  final List<LearnerSkillMastery> reviewSkills;
  final Map<String, Map<String, dynamic>> progressMap;

  const HomeScreenTestData({
    this.studentName = 'Siswa',
    this.grade = 5,
    this.streak = 0,
    this.totalXp = 0,
    this.weeklyXp = 0,
    this.totalSessions = 0,
    this.memorySummary = '',
    this.openGuidedSession,
    this.reviewSkills = const [],
    this.progressMap = const {},
  });
}

class _HomeScreenState extends State<HomeScreen> {
  String _studentName = '';
  int _grade = 5;
  int _streak = 0;
  int _totalXp = 0;
  int _weeklyXp = 0;
  int _totalSessions = 0;
  String _memorySummary = '';
  Map<String, dynamic>? _openGuidedSession;
  List<LearnerSkillMastery> _reviewSkills = [];
  Map<String, Map<String, dynamic>> _progressMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.testData != null) {
      _applyTestData(widget.testData!);
      return;
    }
    _loadData();
  }

  void _applyTestData(HomeScreenTestData data) {
    _studentName = data.studentName;
    _grade = data.grade;
    _streak = data.streak;
    _totalXp = data.totalXp;
    _weeklyXp = data.weeklyXp;
    _totalSessions = data.totalSessions;
    _memorySummary = data.memorySummary;
    _openGuidedSession = data.openGuidedSession;
    _reviewSkills = data.reviewSkills;
    _progressMap = data.progressMap;
    _isLoading = false;
  }

  Future<void> _handleReminderTap() async {
    try {
      final scheduler =
          widget.reminderScheduler ??
          () => SyncService.instance.scheduleSmartReminders(
            requestPermission: true,
          );
      final scheduled = await scheduler();
      if (!scheduled) {
        throw StateError('Notifications are not available');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pengingat belajar sudah dijadwalkan.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: EncouriseColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EncouriseRadius.md),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aktifkan notifikasi untuk memakai pengingat.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: EncouriseColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EncouriseRadius.md),
          ),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    if (widget.testData != null) {
      setState(() => _applyTestData(widget.testData!));
      return;
    }

    final db = DatabaseService.instance;
    final student = await db.getStudent();
    final studentId = student?['id'] as String? ?? '';

    if (student != null) {
      _studentName = student['name'] as String? ?? 'Siswa';
      _grade = student['grade'] as int? ?? 5;
    }

    final sessions = await db.getSessionHistory(studentId);
    final progress = studentId.isEmpty
        ? <Map<String, dynamic>>[]
        : await db.getTopicProgress(studentId);
    final progressMap = <String, Map<String, dynamic>>{};
    for (final item in progress) {
      progressMap[item['topic_id'] as String? ?? ''] = item;
    }

    var totalXp = 0;
    var weeklyXp = 0;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final sessionDays = <String>{};
    for (final session in sessions) {
      totalXp += session['xp_earned'] as int? ?? 0;
      final dateStr = session['started_at'] as String? ?? '';
      if (dateStr.isEmpty) continue;
      try {
        final date = DateTime.parse(dateStr);
        sessionDays.add('${date.year}-${date.month}-${date.day}');
        if (date.isAfter(weekAgo)) {
          weeklyXp += session['xp_earned'] as int? ?? 0;
        }
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

    final memory = studentId.isEmpty
        ? null
        : await db.getLearnerMemory(studentId);
    final openGuided = studentId.isEmpty
        ? null
        : await db.getOpenGuidedSession(studentId, '');
    final reviewSkills = studentId.isEmpty
        ? <LearnerSkillMastery>[]
        : await db.getReviewSkills(studentId, limit: 3);

    if (!mounted) return;
    setState(() {
      _streak = streak;
      _totalXp = totalXp;
      _weeklyXp = weeklyXp;
      _totalSessions = sessions.length;
      _memorySummary = memory?['summary_text'] as String? ?? '';
      _openGuidedSession = openGuided;
      _reviewSkills = reviewSkills;
      _progressMap = progressMap;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: EncouriseColors.background,
        body: Center(
          child: CircularProgressIndicator(color: EncouriseColors.primary),
        ),
      );
    }

    final subjects = getSubjectsForGrade(_grade);
    final firstSubject = subjects.isNotEmpty ? subjects.first : null;

    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: EncouriseColors.primary,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 108),
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              if (_openGuidedSession != null)
                _buildResumeGuidedCard()
              else if (_reviewSkills.isNotEmpty)
                _buildReviewSkillsCard()
              else if (firstSubject != null)
                _buildStartLearningCard(firstSubject),
              const SizedBox(height: 20),
              _buildTodayRow(),
              const SizedBox(height: 14),
              _buildAskBudiCard(),
              if (_memorySummary.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildMemoryCard(),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader('Mata Pelajaran', trailing: 'Lihat semua'),
              const SizedBox(height: 12),
              _buildSubjectGrid(subjects),
              const SizedBox(height: 24),
              _buildSectionHeader('Akses Cepat'),
              const SizedBox(height: 12),
              _buildFeatureRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _studentName.isNotEmpty ? _studentName : 'Siswa';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halo $name', style: EncouriseTextStyles.h1),
              const SizedBox(height: 10),
              const EncouriseStatusPill(),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Jadwalkan pengingat belajar',
          child: InkWell(
            onTap: _handleReminderTap,
            borderRadius: BorderRadius.circular(EncouriseRadius.lg),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: EncouriseColors.surface,
                borderRadius: BorderRadius.circular(EncouriseRadius.lg),
                border: Border.all(color: EncouriseColors.border),
                boxShadow: EncouriseShadows.soft,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: EncouriseColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumeGuidedCard() {
    final topic = _openGuidedSession?['topic_id'] as String? ?? 'Jalur Belajar';
    final currentStep = (_openGuidedSession?['current_step'] as int? ?? 0) + 1;
    final progress = (currentStep / 3).clamp(0.0, 1.0);

    return _LearningHeroCard(
      eyebrow: 'Lanjut Jalur Belajar',
      title: topic,
      subtitle: 'Langkah $currentStep dari 3',
      progress: progress,
      actionLabel: 'Lanjutkan',
      onTap: () async {
        final subject = _subjectForTopic(topic);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GuidedLearningScreen(
              subject: subject.key,
              topic: topic,
              grade: _grade,
            ),
          ),
        );
        _loadData();
      },
    );
  }

  Widget _buildStartLearningCard(SubjectData subject) {
    return _LearningHeroCard(
      eyebrow: 'Mulai belajar hari ini',
      title: subject.name,
      subtitle: EducationLevel.label(_grade),
      progress: _subjectProgress(subject),
      actionLabel: 'Mulai',
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TopicListScreen(subject: subject, grade: _grade),
          ),
        );
        _loadData();
      },
    );
  }

  Widget _buildReviewSkillsCard() {
    final first = _reviewSkills.first;
    return _LearningHeroCard(
      eyebrow: 'Review yang disarankan',
      title: first.topicId,
      subtitle:
          '${_reviewSkills.length} skill perlu latihan • ${first.skillTag.replaceAll("_", " ")}',
      progress: first.masteryScore,
      actionLabel: 'Review',
      onTap: () async {
        final subject = _subjectForTopic(first.topicId);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TopicListScreen(subject: subject, grade: _grade),
          ),
        );
        _loadData();
      },
    );
  }

  SubjectData _subjectForTopic(String topicId) {
    final subjects = getSubjectsForGrade(_grade);
    for (final subject in subjects) {
      final topics = getTopicsForSubjectAndGrade(subject.key, _grade);
      if (topics.contains(topicId)) return subject;
    }
    return subjects.first;
  }

  Widget _buildTodayRow() {
    final goalDone = _totalSessions.clamp(0, 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hari ini', style: EncouriseTextStyles.h3),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.track_changes_rounded,
                color: EncouriseColors.subjectBlue,
                label: 'Tujuan',
                value: '$goalDone/3',
                suffix: 'topik',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: EncouriseColors.streakOrange,
                label: 'Streak',
                value: '$_streak',
                suffix: 'hari',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.star_rounded,
                color: EncouriseColors.xpGold,
                label: 'XP',
                value: '$_totalXp',
                suffix: 'poin',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAskBudiCard() {
    return EncouriseCard(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF0F5FF),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FreeChatScreen(grade: _grade)),
        );
      },
      child: Row(
        children: [
          const BudiAvatar(size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanya Budi apa saja', style: EncouriseTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  'Budi siap membantu kamu belajar.',
                  style: EncouriseTextStyles.bodySm,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: EncouriseColors.primary,
                    borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tanya Budi',
                        style: EncouriseTextStyles.labelSm.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chat_bubble_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EncouriseColors.warningLight,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        border: Border.all(
          color: EncouriseColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: EncouriseColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _memorySummary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: EncouriseTextStyles.bodySm.copyWith(
                color: EncouriseColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Row(
      children: [
        Text(title, style: EncouriseTextStyles.h3),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing,
            style: EncouriseTextStyles.labelSm.copyWith(
              color: EncouriseColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubjectGrid(List<SubjectData> subjects) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subjects.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final color = EncouriseColors
            .subjectColors[index % EncouriseColors.subjectColors.length];
        final progress = _subjectProgress(subject);
        return _SubjectTile(
          subject: subject,
          color: color,
          progress: progress,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TopicListScreen(subject: subject, grade: _grade),
              ),
            );
            _loadData();
          },
        );
      },
    );
  }

  Widget _buildFeatureRow() {
    return Row(
      children: [
        Expanded(
          child: _FeatureTile(
            icon: Icons.bolt_rounded,
            color: EncouriseColors.xpGold,
            title: 'XP Minggu',
            subtitle: '$_weeklyXp poin',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FeatureTile(
            icon: Icons.school_rounded,
            color: EncouriseColors.primary,
            title: 'Sesi',
            subtitle: '$_totalSessions selesai',
          ),
        ),
      ],
    );
  }

  double _subjectProgress(SubjectData subject) {
    final topics = getTopicsForSubjectAndGrade(subject.key, _grade);
    if (topics.isEmpty) return 0;
    var score = 0.0;
    for (final topic in topics) {
      final progress = _progressMap[topic];
      final accuracy = progress?['accuracy'];
      if (accuracy is num) {
        score += accuracy.toDouble().clamp(0.0, 1.0);
      } else if (progress?['status'] == 'mastered') {
        score += 1;
      }
    }
    return (score / topics.length).clamp(0.0, 1.0);
  }
}

class _LearningHeroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final double progress;
  final String actionLabel;
  final VoidCallback onTap;

  const _LearningHeroCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: EncouriseGradients.primary,
          borderRadius: BorderRadius.circular(EncouriseRadius.xl),
          boxShadow: EncouriseShadows.elevated,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow, style: EncouriseTextStyles.bodyOnDark),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.28),
                      color: EncouriseColors.warning,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$subtitle • ${(progress * 100).round()}%',
                    style: EncouriseTextStyles.labelOnDark,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 9,
                        backgroundColor: Colors.white.withValues(alpha: 0.35),
                        color: EncouriseColors.warning,
                      ),
                      const Icon(
                        Icons.route_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(EncouriseRadius.md),
                  ),
                  child: Text(
                    actionLabel,
                    style: EncouriseTextStyles.labelSm.copyWith(
                      color: EncouriseColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String suffix;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        border: Border.all(color: EncouriseColors.border),
        boxShadow: EncouriseShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: EncouriseTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: EncouriseTextStyles.h3),
          Text(suffix, style: EncouriseTextStyles.caption),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final SubjectData subject;
  final Color color;
  final double progress;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.subject,
    required this.color,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EncouriseCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(EncouriseRadius.sm),
            ),
            child: Icon(subject.icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EncouriseTextStyles.labelSm.copyWith(
                    color: EncouriseColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: color,
                          backgroundColor: EncouriseColors.divider,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: EncouriseTextStyles.caption.copyWith(
                        color: EncouriseColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return EncouriseCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(EncouriseRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: EncouriseTextStyles.labelSm.copyWith(
                    color: EncouriseColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: EncouriseTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
