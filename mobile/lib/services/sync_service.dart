import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'database_service.dart';

/// Background service that syncs on-device data to Supabase whenever a
/// WiFi connection becomes available.
///
/// Runs silently — no UI blocking, no user-visible loading state.
class SyncService {
  SyncService._();

  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();

  /// True once Supabase has been initialized with build-time credentials.
  /// When false, sync is skipped and data stays queued locally.
  static bool cloudConfigured = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  /// Local notifications plugin — initialized in [initNotifications].
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initializes local notifications. Call once at app startup.
  ///
  /// [onTap] is invoked when the user taps a notification. The payload
  /// string is passed through so the caller can deep-link.
  Future<void> initNotifications({
    void Function(String? payload)? onTap,
  }) async {
    tz_data.initializeTimeZones();
    // Encourise is currently built for Indonesian learners; using a fixed
    // GMT+7 zone prevents daily reminders from drifting to UTC-based times.
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );
  }

  /// Starts listening for connectivity changes.
  ///
  /// Call once at app startup (e.g. from `main.dart`).
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Also try an immediate sync in case we already have WiFi
    _trySyncNow();
  }

  /// Stops the connectivity listener.
  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // -----------------------------------------------------------------------
  // Smart Reminders
  // -----------------------------------------------------------------------

  /// Schedules a daily study reminder based on recent session patterns.
  ///
  /// Logic:
  /// - If last session > 2 days ago → "urgent" reminder.
  /// - If there's an open guided session → remind to continue.
  /// - Otherwise → gentle daily encouragement.
  Future<bool> scheduleSmartReminders({bool requestPermission = false}) async {
    try {
      final canNotify = await _canSendNotifications(
        requestPermission: requestPermission,
      );
      if (!canNotify) return false;

      final db = DatabaseService.instance;
      final student = await db.getStudent();
      if (student == null) return false;

      final studentId = student['id'] as String? ?? '';
      final studentName = student['name'] as String? ?? 'Siswa';
      if (studentId.isEmpty) return false;

      // Determine reminder content
      String title;
      String body;

      // Check for open guided session
      final openGuided = await db.getOpenGuidedSession(studentId, '');
      if (openGuided != null) {
        final topic = openGuided['topic_id'] as String? ?? 'topikmu';
        final step = (openGuided['current_step'] as int? ?? 0) + 1;
        title = 'Lanjutkan Jalur Belajar \ud83d\udcda';
        body = '$studentName, langkah $step tentang $topic menunggumu!';
      } else {
        final reviewSkills = await db.getReviewSkills(studentId, limit: 1);
        if (reviewSkills.isNotEmpty) {
          final skill = reviewSkills.first;
          title = 'Review singkat hari ini';
          body =
              '$studentName, latih lagi ${skill.skillTag.replaceAll("_", " ")} pada ${skill.topicId}.';
        } else {
          // Check last session date
          final sessions = await db.getSessionHistory(studentId);
          if (sessions.isNotEmpty) {
            final lastDateStr = sessions.first['started_at'] as String? ?? '';
            try {
              final lastDate = DateTime.parse(lastDateStr);
              final daysSince = DateTime.now().difference(lastDate).inDays;
              if (daysSince >= 3) {
                title = 'Lanjut belajar hari ini';
                body =
                    '$studentName, sudah $daysSince hari belum belajar. Mulai dari satu topik ringan.';
              } else if (daysSince >= 1) {
                title = 'Waktunya belajar';
                body =
                    '$studentName, pilih satu topik dan latihan sebentar hari ini.';
              } else {
                title = 'Belajar hari ini selesai';
                body =
                    'Istirahat yang cukup ya, $studentName. Sampai jumpa besok!';
              }
            } catch (_) {
              title = 'Budi siap membantu';
              body = 'Budi siap menemani belajar kapan saja.';
            }
          } else {
            title = 'Mulai perjalanan belajarmu!';
            body = '$studentName, Budi siap menemani belajar kapan saja.';
          }
        }
      }

      const androidDetails = AndroidNotificationDetails(
        'smart_reminder',
        'Pengingat Belajar',
        channelDescription: 'Pengingat belajar harian dari Budi',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const details = NotificationDetails(android: androidDetails);

      // Build payload for deep-link on tap
      String payload = '{}';
      if (openGuided != null) {
        final guidedTopic = openGuided['topic_id'] as String? ?? '';
        payload =
            '{"screen":"guided","subject":"","topic":"$guidedTopic","grade":0}';
      }

      final scheduledTime = _nextReminderTime();
      await _notifications.cancel(1001);
      await _notifications.zonedSchedule(
        1001,
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      await _saveStatus('last_reminder_time', scheduledTime.toIso8601String());
      await _saveStatus('last_reminder_title', title);
      await _saveStatus('last_reminder_payload', payload);
      await _saveStatus('last_reminder_result', 'terjadwal');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[SyncService] Smart reminder scheduling failed: $e');
      await _saveStatus('last_reminder_result', 'gagal');
      return false;
    }
  }

  Future<bool> _canSendNotifications({required bool requestPermission}) async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;

    var enabled = await androidPlugin.areNotificationsEnabled() ?? true;
    if (!enabled && requestPermission) {
      final granted = await androidPlugin.requestNotificationsPermission();
      enabled = granted ?? false;
    }
    return enabled;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasWifi = results.contains(ConnectivityResult.wifi);
    if (hasWifi) {
      _trySyncNow();
    }
  }

  /// Attempts to process the sync queue. Safe to call multiple times —
  /// concurrent runs are prevented by the [_isSyncing] guard.
  Future<void> _trySyncNow() async {
    if (!cloudConfigured || _isSyncing) return;
    _isSyncing = true;

    try {
      final db = DatabaseService.instance;
      await _saveStatus(
        'last_sync_attempt_at',
        DateTime.now().toIso8601String(),
      );
      final queue = await db.getSyncQueue();
      var synced = 0;
      var failed = 0;
      var dropped = 0;

      final supabase = Supabase.instance.client;

      for (final item in queue) {
        try {
          final id = item['id'] as String;
          final payloadRaw = item['payload_json'] as String;
          final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;

          final table = payload['table'] as String?;
          final data = payload['data'] as Map<String, dynamic>?;

          if (table == null || data == null) {
            // Malformed entry — remove it
            await db.markSynced(id);
            continue;
          }

          // Upsert to the correct Supabase table
          await supabase.from(table).upsert(data);

          // Remove from local queue on success
          await db.markSynced(id);
          synced++;
        } catch (_) {
          // Increment retry count; skip this item for now
          final retryCount = (item['retry_count'] as int? ?? 0) + 1;
          if (retryCount > 5) {
            // Too many retries — drop it
            await db.markSynced(item['id'] as String);
            dropped++;
          } else {
            await db.incrementSyncRetry(item['id'] as String);
            failed++;
          }
          // Otherwise leave it in the queue for next attempt
        }
      }

      // Sync learner memory and notes (best-effort, outside queue)
      await _syncLearnerMemory(db, supabase);
      await _syncNotes(db, supabase);
      final summary = await db.getSyncQueueSummary();
      await _saveStatus('sync_pending_count', '${summary['pending'] ?? 0}');
      await _saveStatus(
        'sync_highest_retry',
        '${summary['highestRetry'] ?? 0}',
      );
      await _saveStatus(
        'last_sync_result',
        'berhasil $synced, gagal $failed, dibuang $dropped',
      );
    } catch (e) {
      await _saveStatus('last_sync_result', 'gagal: ${e.runtimeType}');
    } finally {
      _isSyncing = false;
    }
  }

  /// Push learner memory to Supabase.
  Future<void> _syncLearnerMemory(
    DatabaseService db,
    SupabaseClient supabase,
  ) async {
    try {
      final student = await db.getStudent();
      if (student == null) return;
      final studentId = student['id'] as String? ?? '';
      if (studentId.isEmpty) return;

      final memory = await db.getLearnerMemory(studentId);
      if (memory == null) return;

      await supabase.from('learner_memory_cloud').upsert({
        'device_uuid': studentId,
        'summary_text': memory['summary_text'],
        'profile_json': memory['profile_json'],
        'updated_at': memory['updated_at'],
      });
    } catch (_) {
      // Best-effort — silently ignore
    }
  }

  /// Push notes to Supabase.
  Future<void> _syncNotes(DatabaseService db, SupabaseClient supabase) async {
    try {
      final student = await db.getStudent();
      if (student == null) return;
      final studentId = student['id'] as String? ?? '';
      if (studentId.isEmpty) return;

      final notes = await db.getNotes(studentId);
      if (notes.isEmpty) return;

      final rows = notes.map((n) {
        return <String, dynamic>{
          'id': n['id'],
          'device_uuid': studentId,
          'topic_id': n['topic_id'],
          'content_text': n['content_text'],
          'created_at': n['created_at'],
        };
      }).toList();

      await supabase.from('notes_cloud').upsert(rows);
    } catch (_) {
      // Best-effort — silently ignore
    }
  }

  tz.TZDateTime _nextReminderTime() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _saveStatus(String key, String value) async {
    try {
      await DatabaseService.instance.saveModelStatus(key, value);
    } catch (_) {}
  }
}
