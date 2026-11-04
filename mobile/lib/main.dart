import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/tutoring_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/guided_learning_screen.dart';
import 'services/model_loader.dart';
import 'services/gemma_runtime.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'utils/encourise_theme.dart';

/// Global key so notification deep-links can push screens.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
DateTime? appStartedAt;

void main() async {
  appStartedAt = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase credentials are supplied at build time, e.g.
  // flutter run --dart-define-from-file=env.json
  // Without them the app runs fully offline and skips cloud sync.
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    SyncService.cloudConfigured = true;
  }

  final sync = SyncService.instance;
  await sync.initNotifications(onTap: handleNotificationTap);
  sync.startListening();
  sync.scheduleSmartReminders();

  runApp(const EncouriseApp());
}

typedef LearningRouteBuilder =
    Widget Function(String subject, String topic, int grade);

void handleNotificationTap(
  String? payload, {
  LearningRouteBuilder? quizBuilder,
  LearningRouteBuilder? guidedBuilder,
  LearningRouteBuilder? tutoringBuilder,
}) {
  if (payload == null || payload.isEmpty) return;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final screen = data['screen'] as String? ?? '';
    final subject = data['subject'] as String? ?? '';
    final topic = data['topic'] as String? ?? '';
    final grade = data['grade'] as int? ?? 5;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (screen == 'quiz') {
      nav.push(
        MaterialPageRoute(
          builder: (_) =>
              quizBuilder?.call(subject, topic, grade) ??
              QuizScreen(subject: subject, topic: topic, grade: grade),
        ),
      );
    } else if (screen == 'guided' && topic.isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          builder: (_) =>
              guidedBuilder?.call(subject, topic, grade) ??
              GuidedLearningScreen(
                subject: subject,
                topic: topic,
                grade: grade,
              ),
        ),
      );
    } else if (screen == 'tutoring' && topic.isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          builder: (_) =>
              tutoringBuilder?.call(subject, topic, grade) ??
              TutoringScreen(subject: subject, topic: topic, grade: grade),
        ),
      );
    }
  } catch (_) {
    // Malformed payload — ignore
  }
}

class EncouriseApp extends StatelessWidget {
  const EncouriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Encourise',
      debugShowCheckedModeBanner: false,
      theme: buildEncouriseTheme(),
      home: const AppEntry(),
    );
  }
}

// ─── App entry — decides which screen to show ───────────────────────────

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _isChecking = true;
  bool _needsOnboarding = false;
  bool _needsModel = false;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    // 1. Check if student exists
    final student = await DatabaseService.instance.getStudent();
    if (student == null) {
      setState(() {
        _needsOnboarding = true;
        _isChecking = false;
      });
      return;
    }

    // 2. Check if model is available
    final modelPath = await ModelLoader.findModel();
    if (modelPath == null) {
      setState(() {
        _needsModel = true;
        _isChecking = false;
      });
      return;
    }

    // 3. Init engine and go home
    try {
      final size = await File(modelPath).length();
      unawaited(
        Future(() async {
          await DatabaseService.instance.saveModelStatus(
            'model_bytes',
            '$size',
          );
          await DatabaseService.instance.saveModelStatus(
            'mtp_model_compatible',
            '${ModelLoader.isCompatibleSize(size)}',
          );
        }),
      );
    } catch (_) {}
    await _initEngineAndGoHome(modelPath);
  }

  Future<void> _initEngineAndGoHome(String modelPath) async {
    unawaited(ModelLoader.saveModelPath(modelPath));
    if (!GemmaRuntime.instance.isInitialized) {
      setState(() {
        _isChecking = true;
        _needsOnboarding = false;
        _needsModel = false;
      });

      final success = await GemmaRuntime.instance.init(modelPath);
      if (!success && mounted) {
        setState(() {
          _isChecking = false;
          _needsModel = true;
        });
        return;
      }
    }

    if (mounted) {
      unawaited(
        DatabaseService.instance.saveModelStatus(
          'app_start_to_home_ms',
          '${DateTime.now().difference(appStartedAt ?? DateTime.now()).inMilliseconds}',
        ),
      );
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const _LoadingView(text: 'Mempersiapkan Encourise…');
    }

    if (_needsOnboarding) {
      return OnboardingScreen(
        onComplete: () {
          setState(() {
            _needsOnboarding = false;
            _isChecking = true;
          });
          _checkState();
        },
      );
    }

    if (_needsModel) {
      return ModelSetupScreen(
        onModelReady: (path) => _initEngineAndGoHome(path),
      );
    }

    return const _LoadingView(text: 'Memuat…');
  }
}

// ─── Loading view ────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String text;
  const _LoadingView({required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient logo circle (BrainBox-style)
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: EncouriseGradients.primary,
              ),
              child: const Icon(
                Icons.school_rounded,
                color: EncouriseColors.textOnPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Encourise',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: EncouriseColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI Tutor untuk Semua',
              style: TextStyle(
                fontSize: 14,
                color: EncouriseColors.textSecondary,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: EncouriseColors.primary,
                backgroundColor: EncouriseColors.primary.withValues(
                  alpha: 0.15,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: EncouriseColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Model setup screen ──────────────────────────────────────────────────

enum _ModelState { choice, downloading, error }

class ModelSetupScreen extends StatefulWidget {
  final Future<void> Function(String path) onModelReady;

  const ModelSetupScreen({super.key, required this.onModelReady});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  _ModelState _state = _ModelState.choice;
  double _progress = 0.0;
  String _statusText = '';
  String _errorText = '';

  // ── Download ─────────────────────────────────────────────────────────

  Future<void> _startDownload() async {
    setState(() {
      _state = _ModelState.downloading;
      _progress = 0.0;
      _statusText = 'Memulai download…';
    });

    try {
      final result = ModelLoader.downloadModel();

      result.progress.listen(
        (p) {
          if (mounted) {
            setState(() {
              _progress = p;
              if (p < 0.02) {
                _statusText = 'Menghubungkan ke server…';
              } else if (p < 0.95) {
                final gb =
                    (p * ModelLoader.expectedBytes / (1024 * 1024 * 1024))
                        .toStringAsFixed(1);
                _statusText =
                    'Mengunduh model AI… ${(p * 100).toStringAsFixed(0)}%\n$gb / 2.4 GB';
              } else {
                _statusText = 'Memfinalisasi…';
              }
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _state = _ModelState.error;
              _errorText = 'Download gagal.\nPeriksa koneksi WiFi.\n\n$e';
            });
          }
        },
      );

      final modelPath = await result.modelPath;
      await widget.onModelReady(modelPath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ModelState.error;
          _errorText = 'Download gagal.\n$e';
        });
      }
    }
  }

  // ── Import from storage ──────────────────────────────────────────────

  Future<void> _importFromStorage() async {
    setState(() {
      _state = _ModelState.downloading;
      _statusText = 'Mencari file model di perangkat…';
      _progress = 0.0;
    });

    try {
      final foundPath = await ModelLoader.findModel();
      if (foundPath != null) {
        await widget.onModelReady(foundPath);
        return;
      }

      final granted = await ModelLoader.requestStoragePermission();
      if (granted) {
        setState(() => _statusText = 'Mencari file model di Download…');
        final scannedPath = await ModelLoader.findModel();
        if (scannedPath != null) {
          await widget.onModelReady(scannedPath);
          return;
        }
      }

      if (!mounted) return;
      setState(() => _statusText = 'Pilih file model di folder Download…');
      final pickedPath = await ModelLoader.pickModelFile();
      if (pickedPath != null) {
        await widget.onModelReady(pickedPath);
        return;
      }

      if (!mounted) return;
      setState(() {
        _state = _ModelState.choice;
        _statusText = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ModelState.error;
          _errorText =
              'File model tidak bisa digunakan.\n\n'
              'Pilih "${ModelLoader.preferredFilename}" dari folder Download.\n\n'
              '$e';
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient logo circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: EncouriseGradients.primary,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: EncouriseColors.textOnPrimary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Encourise',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: EncouriseColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'AI Tutor untuk Semua',
                  style: TextStyle(
                    fontSize: 14,
                    color: EncouriseColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _ModelState.choice:
        return _buildChoiceScreen();
      case _ModelState.downloading:
        return _buildProgressView();
      case _ModelState.error:
        return _buildErrorView();
    }
  }

  Widget _buildChoiceScreen() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: EncouriseColors.primarySurface,
            borderRadius: BorderRadius.circular(EncouriseRadius.md),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: EncouriseColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  size: 28,
                  color: EncouriseColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Model AI Belum Tersedia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EncouriseColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Encourise membutuhkan model Gemma (2.4 GB) '
                'untuk fitur AI tutor. Gunakan bundle terbaru agar MTP aktif.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: EncouriseColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const EncouriseStatusPill(
                label: 'MTP siap dengan model Mei 2026',
                icon: Icons.flash_on_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildOptionCard(
          icon: Icons.cloud_download_outlined,
          title: 'Download Model',
          subtitle: 'Unduh dari server (2.4 GB).\nMembutuhkan WiFi.',
          buttonText: 'Download Sekarang',
          onPressed: _startDownload,
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          icon: Icons.folder_outlined,
          title: 'Sudah Punya File Model',
          subtitle:
              'File dari guru/teman ada di\nfolder Download? Tap di sini.',
          buttonText: 'Cari di Download',
          onPressed: _importFromStorage,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: BorderRadius.circular(EncouriseRadius.md),
        boxShadow: EncouriseShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isSecondary ? null : EncouriseGradients.primary,
              color: isSecondary ? EncouriseColors.cardFill : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isSecondary
                  ? EncouriseColors.textSecondary
                  : EncouriseColors.textOnPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isSecondary
                  ? EncouriseColors.textSecondary
                  : EncouriseColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: EncouriseColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          isSecondary
              ? SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EncouriseColors.textPrimary,
                      side: const BorderSide(color: EncouriseColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(EncouriseRadius.sm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : EncouriseGradientButton(
                  label: buttonText,
                  onPressed: onPressed,
                ),
        ],
      ),
    );
  }

  Widget _buildProgressView() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress > 0.01 ? _progress : null,
            minHeight: 6,
            backgroundColor: EncouriseColors.primary.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(
              EncouriseColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: EncouriseColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _state = _ModelState.choice),
          child: const Text(
            'Batalkan',
            style: TextStyle(color: EncouriseColors.error, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: EncouriseColors.errorLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 28,
            color: EncouriseColors.error,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _errorText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: EncouriseColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        EncouriseGradientButton(
          label: 'Kembali',
          onPressed: () => setState(() => _state = _ModelState.choice),
        ),
      ],
    );
  }
}
