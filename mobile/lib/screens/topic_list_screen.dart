import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/tutor_capability.dart';
import '../utils/curriculum_data.dart';
import '../utils/encourise_theme.dart';
import 'guided_learning_screen.dart';
import 'quiz_screen.dart';
import 'tutoring_screen.dart';

/// Topic browser and learning mode picker.
class TopicListScreen extends StatefulWidget {
  final SubjectData subject;
  final int grade;

  const TopicListScreen({
    super.key,
    required this.subject,
    required this.grade,
  });

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  Map<String, Map<String, dynamic>> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final db = DatabaseService.instance;
    final student = await db.getStudent();
    if (student == null) return;

    final progress = await db.getTopicProgress(student['id'] as String);
    final map = <String, Map<String, dynamic>>{};
    for (final item in progress) {
      map[item['topic_id'] as String? ?? ''] = item;
    }

    if (mounted) setState(() => _progressMap = map);
  }

  void _showModePicker(String topic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: EncouriseColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Pilih cara belajar', style: EncouriseTextStyles.h2),
                  const SizedBox(height: 4),
                  Text(topic, style: EncouriseTextStyles.bodySm),
                  const SizedBox(height: 14),
                  const _ModeGuide(),
                  const SizedBox(height: 18),
                  _ModeOption(
                    icon: Icons.menu_book_rounded,
                    iconColor: EncouriseColors.primary,
                    label: 'Pahami',
                    description:
                        'Pilih ini untuk memahami konsep lewat penjelasan atau pertanyaan Budi.',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showPahamiStylePicker(topic);
                    },
                  ),
                  const SizedBox(height: 10),
                  _ModeOption(
                    icon: Icons.assignment_turned_in_rounded,
                    iconColor: EncouriseColors.warning,
                    label: 'Tes Diri',
                    description:
                        'Pilih ini untuk mengecek pemahaman dengan soal pilihan ganda.',
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToMode(topic, 'quiz');
                    },
                  ),
                  const SizedBox(height: 10),
                  _ModeOption(
                    icon: Icons.route_rounded,
                    iconColor: EncouriseColors.levelPurple,
                    label: 'Jalur Belajar',
                    description:
                        'Pilih ini untuk belajar dari awal lewat langkah terarah sampai selesai.',
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToMode(topic, 'guided');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPahamiStylePicker(String topic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: EncouriseColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Pilih gaya Budi', style: EncouriseTextStyles.h2),
                const SizedBox(height: 4),
                Text(topic, style: EncouriseTextStyles.bodySm),
                const SizedBox(height: 18),
                _ModeOption(
                  icon: Icons.lightbulb_rounded,
                  iconColor: EncouriseColors.primary,
                  label: 'Jelaskan',
                  description:
                      'Budi menjelaskan konsep singkat, memberi contoh, lalu memberi tugas kecil.',
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToMode(topic, 'socratic', teachingMode: 'jelaskan');
                  },
                ),
                const SizedBox(height: 10),
                _ModeOption(
                  icon: Icons.question_answer_rounded,
                  iconColor: EncouriseColors.levelPurple,
                  label: 'Tanya',
                  description:
                      'Budi mulai dengan pertanyaan pemandu, lalu membantu dari jawabanmu.',
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToMode(topic, 'socratic', teachingMode: 'tanya');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToMode(
    String topic,
    String mode, {
    String teachingMode = 'jelaskan',
  }) async {
    Widget screen;
    switch (mode) {
      case 'quiz':
        screen = QuizScreen(
          subject: widget.subject.key,
          topic: topic,
          grade: widget.grade,
        );
        break;
      case 'guided':
        screen = GuidedLearningScreen(
          subject: widget.subject.key,
          topic: topic,
          grade: widget.grade,
        );
        break;
      default:
        screen = TutoringScreen(
          subject: widget.subject.key,
          topic: topic,
          grade: widget.grade,
          teachingMode: teachingMode,
          capability: TutoringCapability.socratic,
        );
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final topics = getTopicsForSubjectAndGrade(
      widget.subject.key,
      widget.grade,
    );
    final level = EducationLevel.label(widget.grade);
    final mastered = _progressMap.values
        .where((p) => p['status'] == 'mastered')
        .length;

    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(level, mastered, topics.length),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: topics.length,
                separatorBuilder: (context, separatorIndex) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final progress = _progressMap[topic];
                  return _TopicCard(
                    topic: topic,
                    icon: _topicIcon(index),
                    status: progress?['status'] as String? ?? 'not_started',
                    accuracy: (progress?['accuracy'] as num?)?.toDouble() ?? 0,
                    onTap: () => _showModePicker(topic),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String level, int mastered, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: EncouriseColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${widget.subject.name} Kelas ${widget.grade}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EncouriseTextStyles.h3,
                ),
              ),
              const EncouriseStatusPill(),
            ],
          ),
          const SizedBox(height: 18),
          EncouriseCard(
            padding: const EdgeInsets.all(16),
            color: EncouriseColors.primarySurface,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: EncouriseColors.primary,
                    borderRadius: BorderRadius.circular(EncouriseRadius.lg),
                  ),
                  child: Icon(widget.subject.icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level, style: EncouriseTextStyles.labelSm),
                      const SizedBox(height: 4),
                      Text(
                        '$mastered dari $total topik tuntas',
                        style: EncouriseTextStyles.h3,
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

  IconData _topicIcon(int index) {
    const icons = [
      Icons.pie_chart_rounded,
      Icons.grid_view_rounded,
      Icons.view_in_ar_rounded,
      Icons.functions_rounded,
      Icons.show_chart_rounded,
      Icons.school_rounded,
    ];
    return icons[index % icons.length];
  }
}

class _ModeGuide extends StatelessWidget {
  const _ModeGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EncouriseColors.primarySurface,
        borderRadius: BorderRadius.circular(EncouriseRadius.md),
      ),
      child: Text(
        'Pahami untuk memahami konsep. Tes Diri untuk mengecek pemahaman. Jalur Belajar untuk panduan langkah demi langkah.',
        style: EncouriseTextStyles.bodySm.copyWith(
          color: EncouriseColors.textPrimary,
          height: 1.45,
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final String topic;
  final IconData icon;
  final String status;
  final double accuracy;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.icon,
    required this.status,
    required this.accuracy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = _statusState();

    return EncouriseCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(EncouriseRadius.lg),
            ),
            child: Icon(icon, color: state.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic, style: EncouriseTextStyles.h3),
                const SizedBox(height: 6),
                Text(state.label, style: EncouriseTextStyles.bodySm),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state.progress,
                          minHeight: 6,
                          color: state.color,
                          backgroundColor: EncouriseColors.divider,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(state.progress * 100).round()}%',
                      style: EncouriseTextStyles.labelSm.copyWith(
                        color: EncouriseColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: EncouriseColors.textSecondary,
          ),
        ],
      ),
    );
  }

  _TopicStatus _statusState() {
    switch (status) {
      case 'mastered':
        return const _TopicStatus(
          label: 'Tuntas, siap diulang',
          color: EncouriseColors.primary,
          progress: 1,
        );
      case 'in_progress':
        return _TopicStatus(
          label: 'Sedang berjalan',
          color: EncouriseColors.primary,
          progress: accuracy.clamp(0.0, 1.0),
        );
      case 'flagged':
        return _TopicStatus(
          label: 'Perlu review',
          color: EncouriseColors.error,
          progress: accuracy.clamp(0.0, 1.0),
        );
      default:
        return const _TopicStatus(
          label: 'Belum mulai',
          color: EncouriseColors.textMuted,
          progress: 0,
        );
    }
  }
}

class _TopicStatus {
  final String label;
  final Color color;
  final double progress;

  const _TopicStatus({
    required this.label,
    required this.color,
    required this.progress,
  });
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EncouriseCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: EncouriseTextStyles.h3),
                const SizedBox(height: 3),
                Text(description, style: EncouriseTextStyles.bodySm),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: EncouriseColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
