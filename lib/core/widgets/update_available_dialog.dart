import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme/app_colors.dart';
import '../models/app_update_info.dart';

class UpdateAvailableDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const UpdateAvailableDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateAvailableDialog(updateInfo: updateInfo),
    );
  }

  Future<void> _handleUpdate(BuildContext context) async {
    final url = updateInfo.apkDownloadUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.border, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header icon + Badge
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: colors.cyan,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Update Available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.textMain,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle with version badge
            Text(
              'FairShare ${updateInfo.tagName} is now ready to download.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Release Notes Card
            if (updateInfo.releaseNotes.trim().isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo.releaseNotes.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.textMain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Later',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _handleUpdate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cyan,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
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
