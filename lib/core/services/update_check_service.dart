import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/app_update_info.dart';

final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  return UpdateCheckService();
});

final latestUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  final service = ref.watch(updateCheckServiceProvider);
  return service.checkForUpdate();
});

class UpdateCheckService {
  final http.Client _client;
  static const _channel = MethodChannel('com.fairshare.app/updater');

  UpdateCheckService({http.Client? client}) : _client = client ?? http.Client();

  /// Queries the latest GitHub Release for [repository] and determines if a newer version is available.
  Future<AppUpdateInfo?> checkForUpdate({
    String? repository,
    String currentVersion = AppConfig.appVersion,
  }) async {
    final repo = repository ?? AppConfig.githubRepo;
    if (repo.isEmpty) return null;

    try {
      final uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FairShare-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AppUpdateInfo.fromGitHubReleaseJson(
          data,
          currentVersion: currentVersion,
        );
      }

      // Non-200 (e.g. 404 when no releases exist yet, or 403 on rate-limit)
      return null;
    } catch (_) {
      // Network failure, offline, or timeout
      return null;
    }
  }

  /// Downloads the APK directly with live streamed progress reporting.
  Future<String> downloadApk({
    required String url,
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('In-app APK downloading is only supported on Android.');
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'FairShare-App';
    final response = await _client.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to download update: HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/update.apk');
    if (await file.exists()) {
      await file.delete();
    }

    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        onProgress(progress, receivedBytes, totalBytes);
      }
    }
    await sink.flush();
    await sink.close();

    return file.path;
  }

  /// Triggers Android's native package installer sheet via FileProvider.
  Future<bool> installApk(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return res ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error launching native package installer: ${e.message}');
      return false;
    }
  }
}
