import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';

/// Locates or downloads the LiteRT-LM model file (.litertlm) on the device.
///
/// Model source:
///   https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
///
/// The May 2026 LiteRT-LM bundle includes speculative decoding / MTP support.
/// Older pre-MTP bundles are slightly smaller and should be rejected so users
/// get the faster model path.
class ModelLoader {
  ModelLoader._();

  static const String preferredFilename = 'gemma-4-E2B-it.litertlm';

  static const String downloadUrl =
      'https://huggingface.co/litert-community/'
      'gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static const int expectedBytes = 2588147712;
  static const int minMtpCompatibleBytes = 2586000000;
  static const String expectedSizeLabel = '2.4 GB';
  static const String _savedModelPathKey = 'active_litertlm_model_path';

  // ─── Public API ────────────────────────────────────────────────────

  /// Requests "All Files Access" permission on Android 11+.
  /// Returns true if permission is granted.
  static Future<bool> requestStoragePermission() async {
    // Check if already granted
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // Request permission — this opens the system settings page
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// Returns true if the app has permission to read external storage.
  static Future<bool> hasStoragePermission() async {
    return await Permission.manageExternalStorage.isGranted;
  }

  static bool isCompatibleSize(int bytes) => bytes >= minMtpCompatibleBytes;

  static Future<bool> isMtpCompatibleFile(String path) async {
    return _isCompatibleModel(File(path));
  }

  static Future<void> saveModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedModelPathKey, path);
    await _saveModelPathStatus('tersimpan');
  }

  /// Lets the user choose the `.litertlm` file directly from Downloads.
  ///
  /// This is more reliable on recent Android versions than scanning shared
  /// storage folders, because the picker grants access to the selected file.
  static Future<String?> pickModelFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Pilih file Gemma .litertlm',
      type: FileType.custom,
      allowedExtensions: const ['litertlm'],
      withData: false,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File model tidak bisa dibuka.');
    }
    if (!await _isCompatibleModel(file)) {
      final size = await file.length();
      throw Exception(
        'Model tidak cocok atau belum lengkap: $size bytes. '
        'Gunakan bundle Mei 2026 "${ModelLoader.preferredFilename}".',
      );
    }
    await saveModelPath(path);
    return path;
  }

  /// Checks if the model exists in any accessible directory.
  /// Searches app dirs first, then Download folder (if permission granted).
  static Future<String?> findModel() async {
    final stopwatch = Stopwatch()..start();
    Future<String?> finish(String? path, String status) async {
      stopwatch.stop();
      await _saveModelPathStatus(status);
      await _saveStatus(
        'model_discovery_time_ms',
        '${stopwatch.elapsedMilliseconds}',
      );
      return path;
    }

    // 1. Reuse the last working path so the user does not reconnect the model
    // after restarting the app.
    final savedPath = await _savedCompatiblePath();
    if (savedPath != null) return finish(savedPath, 'path tersimpan');

    // 2. Check app internal documents directory
    final docsDir = await getApplicationDocumentsDirectory();
    final found = await _findLitertlmFile(docsDir.path);
    if (found != null && await _isCompatibleModel(found)) {
      await saveModelPath(found.path);
      return finish(found.path, 'dokumen aplikasi');
    }

    // 3. Check app external directory
    try {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null) {
        for (final dir in extDirs) {
          final f = await _findLitertlmFile(dir.path);
          if (f != null && await _isCompatibleModel(f)) {
            await saveModelPath(f.path);
            return finish(f.path, 'folder aplikasi');
          }
        }
      }
    } catch (_) {}

    // 4. Check Download folder and other common locations
    //    (requires MANAGE_EXTERNAL_STORAGE permission)
    if (await Permission.manageExternalStorage.isGranted) {
      for (final dirPath in [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
        '/storage/emulated/0',
      ]) {
        try {
          final file = await _findLitertlmFile(
            dirPath,
          ).timeout(const Duration(seconds: 3));
          if (file != null && await _isCompatibleModel(file)) {
            await saveModelPath(file.path);
            return finish(file.path, 'Download');
          }
        } catch (_) {
          continue;
        }
      }
    }

    return finish(null, 'belum ditemukan');
  }

  /// Downloads the model from HuggingFace with progress reporting.
  static ModelLoadResult downloadModel() {
    final controller = StreamController<double>.broadcast();
    final completer = Completer<String>();
    _performDownload(controller, completer);
    return ModelLoadResult(
      progress: controller.stream,
      modelPath: completer.future,
    );
  }

  // ─── Download logic ─────────────────────────────────────────────────

  static Future<void> _performDownload(
    StreamController<double> controller,
    Completer<String> completer,
  ) async {
    try {
      controller.add(0.01);

      // Download to app external dir
      String destDir;
      try {
        final extDirs = await getExternalStorageDirectories();
        destDir = (extDirs != null && extDirs.isNotEmpty)
            ? extDirs.first.path
            : (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        destDir = (await getApplicationDocumentsDirectory()).path;
      }

      final destPath = '$destDir/$preferredFilename';
      final tmpPath = '$destPath.tmp';

      await _downloadFile(tmpPath, controller);
      await File(tmpPath).rename(destPath);

      controller.add(1.0);
      await controller.close();
      completer.complete(destPath);
    } catch (e, st) {
      controller.addError(e, st);
      await controller.close();
      completer.completeError(e, st);
    }
  }

  static Future<void> _downloadFile(
    String destPath,
    StreamController<double> controller,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(minutes: 2);

    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;

      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(downloadUrl),
        );
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : expectedBytes;

      final file = File(destPath);
      final sink = file.openWrite();

      int received = 0;
      int lastReportedPercent = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;

        final percent = ((received / totalBytes) * 100).floor();
        if (percent > lastReportedPercent) {
          lastReportedPercent = percent;
          final progress = 0.01 + (received / totalBytes) * 0.94;
          controller.add(progress.clamp(0.01, 0.95));
        }
      }

      await sink.flush();
      await sink.close();

      final downloadedSize = await file.length();
      if (!await _isCompatibleModel(file)) {
        await file.delete();
        throw Exception(
          'Incompatible or incomplete model: got $downloadedSize bytes, '
          'expected the May 2026 MTP bundle (~$expectedBytes bytes)',
        );
      }
    } finally {
      client.close();
    }
  }

  // ─── File scanning ──────────────────────────────────────────────────

  static Future<File?> _findLitertlmFile(String dirPath) async {
    final dir = Directory(dirPath);
    try {
      if (!await dir.exists()) return null;
    } catch (_) {
      return null;
    }

    try {
      final preferred = File('$dirPath/$preferredFilename');
      if (await preferred.exists()) return preferred;
    } catch (_) {}

    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.litertlm')) {
          return entity;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> _isCompatibleModel(File file) async {
    try {
      final size = await file.length();
      return isCompatibleSize(size);
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _savedCompatiblePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_savedModelPathKey);
      if (path == null || path.isEmpty) return null;
      final file = File(path);
      if (await file.exists() && await _isCompatibleModel(file)) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _saveModelPathStatus(String value) async {
    await _saveStatus('model_path_status', value);
  }

  static Future<void> _saveStatus(String key, String value) async {
    try {
      await DatabaseService.instance.saveModelStatus(key, value);
    } catch (_) {}
  }
}

/// Result of model operations.
class ModelLoadResult {
  final Stream<double> progress;
  final Future<String> modelPath;

  const ModelLoadResult({required this.progress, required this.modelPath});
}
