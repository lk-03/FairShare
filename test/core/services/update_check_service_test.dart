import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fairshare/core/models/app_update_info.dart';
import 'package:fairshare/core/services/update_check_service.dart';

void main() {
  group('AppUpdateInfo Version Comparison', () {
    test('identifies newer major, minor, and patch versions', () {
      expect(AppUpdateInfo.isRemoteNewer('v1.1.0', '1.0.0'), isTrue);
      expect(AppUpdateInfo.isRemoteNewer('2.0.0', '1.9.9'), isTrue);
      expect(AppUpdateInfo.isRemoteNewer('v1.0.1', '1.0.0'), isTrue);
      expect(AppUpdateInfo.isRemoteNewer('v1.0.0+2', '1.0.0+1'), isTrue);
    });

    test('identifies newer CalVer date versions and sequential build numbers', () {
      // Future date vs past date
      expect(AppUpdateInfo.isRemoteNewer('v2026.10.16.1', '2026.10.15.1'), isTrue);
      expect(AppUpdateInfo.isRemoteNewer('v2026.11.01.1', '2026.10.31.5'), isTrue);
      expect(AppUpdateInfo.isRemoteNewer('v2027.01.01.1', '2026.12.31.9'), isTrue);

      // Same date, newer build number
      expect(AppUpdateInfo.isRemoteNewer('v2026.10.15.4', '2026.10.15.3'), isTrue);
      expect(AppUpdateInfo.isRemoteNewer('v2026.10.15+5', '2026.10.15+4'), isTrue);

      // Identical or older CalVer
      expect(AppUpdateInfo.isRemoteNewer('v2026.10.15.3', '2026.10.15.3'), isFalse);
      expect(AppUpdateInfo.isRemoteNewer('v2026.10.14.9', '2026.10.15.1'), isFalse);
    });

    test('returns false for identical or older versions', () {
      expect(AppUpdateInfo.isRemoteNewer('v1.0.0', '1.0.0'), isFalse);
      expect(AppUpdateInfo.isRemoteNewer('1.0.0', '1.0.0+1'), isFalse);
      expect(AppUpdateInfo.isRemoteNewer('0.9.9', '1.0.0'), isFalse);
      expect(AppUpdateInfo.isRemoteNewer('v1.0.0', '1.1.0'), isFalse);
    });

    test('handles malformed version strings safely without throwing', () {
      expect(AppUpdateInfo.isRemoteNewer('invalid', '1.0.0'), isFalse);
      expect(AppUpdateInfo.isRemoteNewer('', ''), isFalse);
    });
  });

  group('AppUpdateInfo GitHub JSON Parsing', () {
    test('correctly extracts tag, body, and APK asset URL', () {
      final sampleJson = {
        'tag_name': 'v1.2.0',
        'body': '• Added receipt splitting\n• Bug fixes',
        'published_at': '2026-10-15T12:00:00Z',
        'assets': [
          {
            'name': 'source-code.zip',
            'browser_download_url': 'https://github.com/downloads/src.zip',
          },
          {
            'name': 'FairShare-v1.2.0.apk',
            'browser_download_url':
                'https://github.com/downloads/FairShare-v1.2.0.apk',
          },
        ],
      };

      final info = AppUpdateInfo.fromGitHubReleaseJson(
        sampleJson,
        currentVersion: '1.0.0',
      );

      expect(info.tagName, 'v1.2.0');
      expect(info.version, '1.2.0');
      expect(info.releaseNotes, contains('Added receipt splitting'));
      expect(info.apkDownloadUrl,
          'https://github.com/downloads/FairShare-v1.2.0.apk');
      expect(info.hasUpdate, isTrue);
    });
  });

  group('UpdateCheckService', () {
    test('returns AppUpdateInfo when newer release is found', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/repos/lk-03/FairShare/releases/latest');
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.1.0',
            'body': 'New features',
            'assets': [
              {
                'name': 'FairShare.apk',
                'browser_download_url': 'https://example.com/FairShare.apk',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = UpdateCheckService(client: mockClient);
      final update = await service.checkForUpdate(
        repository: 'lk-03/FairShare',
        currentVersion: '1.0.0',
      );

      expect(update, isNotNull);
      expect(update!.hasUpdate, isTrue);
      expect(update.version, '1.1.0');
      expect(update.apkDownloadUrl, 'https://example.com/FairShare.apk');
    });

    test('returns null gracefully on 404 or network error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = UpdateCheckService(client: mockClient);
      final update = await service.checkForUpdate(
        repository: 'lk-03/FairShare',
        currentVersion: '1.0.0',
      );

      expect(update, isNull);
    });
  });
}
