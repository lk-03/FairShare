import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  UpdateCheckService({http.Client? client}) : _client = client ?? http.Client();

  /// Queries the latest GitHub Release for [repository] and determines if a newer version is available.
  Future<AppUpdateInfo?> checkForUpdate({
    String? repository,
    String currentVersion = AppConfig.appVersion,
  }) async {
    // Web users receive instant updates via Vercel deployments
    if (kIsWeb) return null;

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
}
