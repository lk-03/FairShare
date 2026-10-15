import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

@immutable
class AppUpdateInfo {
  final String tagName;
  final String version;
  final String releaseNotes;
  final String? apkDownloadUrl;
  final DateTime? publishedAt;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    this.apkDownloadUrl,
    this.publishedAt,
    required this.hasUpdate,
  });

  /// Evaluates whether [remoteTag] is strictly newer than [localVersion].
  /// Handles formats like 'v1.1.0', '1.1.0+2', '1.0.0'.
  static bool isRemoteNewer(String remoteTag, String localVersion) {
    try {
      final (remoteMajor, remoteMinor, remotePatch, remoteBuild) =
          _parseVersion(remoteTag);
      final (localMajor, localMinor, localPatch, localBuild) =
          _parseVersion(localVersion);

      if (remoteMajor != localMajor) {
        return remoteMajor > localMajor;
      }
      if (remoteMinor != localMinor) {
        return remoteMinor > localMinor;
      }
      if (remotePatch != localPatch) {
        return remotePatch > localPatch;
      }
      return remoteBuild > localBuild;
    } catch (_) {
      return false;
    }
  }

  static (int, int, int, int) _parseVersion(String raw) {
    // Strip leading 'v' or 'V' and trim whitespace
    var cleaned = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');

    int build = 0;
    if (cleaned.contains('+')) {
      final parts = cleaned.split('+');
      cleaned = parts[0];
      build = int.tryParse(parts[1]) ?? 0;
    }

    final segments = cleaned.split('.');
    final major = segments.isNotEmpty ? int.tryParse(segments[0]) ?? 0 : 0;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
    final patch = segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0;

    return (major, minor, patch, build);
  }

  /// Parses a GitHub Release JSON object into an [AppUpdateInfo].
  factory AppUpdateInfo.fromGitHubReleaseJson(
    Map<String, dynamic> json, {
    String currentVersion = AppConfig.appVersion,
  }) {
    final tagName = json['tag_name'] as String? ?? '';
    final cleanVersion = tagName.replaceFirst(RegExp(r'^[vV]'), '');
    final body = json['body'] as String? ?? 'No release notes provided.';

    String? apkUrl;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    DateTime? publishedDate;
    final publishedStr = json['published_at'] as String?;
    if (publishedStr != null) {
      publishedDate = DateTime.tryParse(publishedStr);
    }

    final hasUpdate = isRemoteNewer(tagName, currentVersion);

    return AppUpdateInfo(
      tagName: tagName,
      version: cleanVersion,
      releaseNotes: body,
      apkDownloadUrl: apkUrl,
      publishedAt: publishedDate,
      hasUpdate: hasUpdate,
    );
  }
}
