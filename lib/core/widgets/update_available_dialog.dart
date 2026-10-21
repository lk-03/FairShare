import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme/app_colors.dart';
import '../config/app_config.dart';
import '../models/app_update_info.dart';
import '../services/update_check_service.dart';

class UpdateAvailableDialog extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends ConsumerState<UpdateAvailableDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedApkPath;
  String? _errorMessage;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _cleanVersion(String v) {
    if (v.trim().isEmpty) return 'v1.0.0';
    return v.startsWith('v') || v.startsWith('V') ? v : 'v$v';
  }

  Future<void> _handleStartUpdate() async {
    final apkUrl = widget.updateInfo.apkDownloadUrl;
    if (apkUrl == null || apkUrl.isEmpty) {
      setState(() {
        _errorMessage = 'No direct APK download asset available for this release.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      final service = ref.read(updateCheckServiceProvider);
      final path = await service.downloadApk(
        url: apkUrl,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadedApkPath = path;
      });

      // Automatically trigger Android's native installer prompt
      await service.installApk(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Failed to download update: ${e.toString()}';
      });
    }
  }

  Future<void> _handleInstallExisting() async {
    if (_downloadedApkPath != null) {
      final service = ref.read(updateCheckServiceProvider);
      await service.installApk(_downloadedApkPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentVer = _cleanVersion(AppConfig.appVersion);
    final targetVer = _cleanVersion(widget.updateInfo.tagName);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.border, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header icon
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colors.cyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.cyan.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: colors.cyan,
                    size: 30,
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
              const SizedBox(height: 12),

              // Clean Version Transition Pill: Current Version -> New Version
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.accentPill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentVer,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: colors.cyan,
                        ),
                      ),
                      Text(
                        targetVer,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: colors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                _isDownloading
                    ? 'Downloading the latest update package in the background...'
                    : _downloadedApkPath != null
                        ? 'Download completed. Confirm installation to restart into the new version.'
                        : 'A new version of FairShare is ready to download and install.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Live Download Progress Bar
              if (_isDownloading) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _downloadProgress > 0 ? _downloadProgress : null,
                          backgroundColor: colors.surface,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Downloading...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            _totalBytes > 0
                                ? '${(_downloadProgress * 100).toInt()}% (${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)})'
                                : _formatBytes(_receivedBytes),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Success Message Box
              if (_downloadedApkPath != null && !_isDownloading) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.emerald.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: colors.emerald, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ready to install. Tap below to launch installer.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.crimson.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.crimson.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colors.crimson, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.crimson,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isDownloading
                          ? null
                          : () => Navigator.of(context).pop(),
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
                      onPressed: _isDownloading
                          ? null
                          : _downloadedApkPath != null
                              ? _handleInstallExisting
                              : _handleStartUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.cyan,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isDownloading
                            ? 'Downloading...'
                            : _downloadedApkPath != null
                                ? 'Install Now'
                                : 'Update Now',
                        style: const TextStyle(
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
      ),
    );
  }
}
