import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Launches the latest Android APK release on GitHub.
Future<void> launchApkDownload(BuildContext context) async {
  final repo = AppConfig.githubRepo;
  final uri = Uri.parse('https://github.com/$repo/releases/latest');

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open APK download link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open download link: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
