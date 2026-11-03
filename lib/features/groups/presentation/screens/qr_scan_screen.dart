import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../../features/home/presentation/widgets/join_group_sheet.dart';

/// Fullscreen live camera QR Code scanner for joining FairShare groups and cohorts.
class QrScanScreen extends ConsumerStatefulWidget {
  final MobileScannerController? controller;

  const QrScanScreen({
    super.key,
    this.controller,
  });

  /// Utility to extract an invite code from deep link URLs or raw text.
  /// Matches:
  /// - `fairshare://join/BLR402` -> `BLR402`
  /// - `https://fairshare.app/join/BLR402` -> `BLR402`
  /// - `BLR402` -> `BLR402`
  static String? extractInviteCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final regex = RegExp(
      r'^(?:(?:fairshare:\/\/join\/)|(?:https?:\/\/[^\/]+\/join\/))?([A-Za-z0-9_-]{3,16})$',
      caseSensitive: false,
    );
    final match = regex.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.toUpperCase();
    }
    return null;
  }

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  bool _ownsController = false;
  bool _isProcessing = false;
  bool _torchOn = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        torchEnabled: false,
      );
      _ownsController = true;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue ?? barcode.displayValue;
      final code = QrScanScreen.extractInviteCode(raw);
      if (code != null) {
        await _processInviteCode(code);
        break;
      }
    }
  }

  Future<void> _processInviteCode(String cleanCode) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      _controller.stop();
    } catch (_) {}

    Group? joinedGroup;
    String? errorMessage;

    try {
      joinedGroup = await ref
          .read(groupsProvider.notifier)
          .joinGroupByInviteCode(cleanCode);
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    if (!mounted) return;

    if (joinedGroup != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${joinedGroup.name}"!'),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      GoRouter.maybeOf(context)?.go('/groups/${joinedGroup.id}');
    } else {
      setState(() => _isProcessing = false);
      try {
        _controller.start();
      } catch (_) {}

      final msg = errorMessage ??
          'Invite code "$cleanCode" was not found or invalid.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openManualEntry() {
    Navigator.of(context).pop();
    JoinGroupSheet.show(context);
  }

  void _showTestSimulatorModal() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text(
          'Simulate QR Scan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a test code or deep link to simulate a successful camera QR scan:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. fairshare://join/BLR402 or BLR402',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = textController.text.trim();
              final code = QrScanScreen.extractInviteCode(raw);
              Navigator.of(ctx).pop();
              if (code != null) {
                _processInviteCode(code);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid test code format')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            child: const Text('Simulate Scan', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.of(context).size;
    final scanSize = (size.width * 0.70).clamp(200.0, 300.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. MobileScanner Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcodeDetected,
            errorBuilder: (ctx, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.rose,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Unavailable',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Camera access is required to scan group QR codes. Please check app permissions or enter code manually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _openManualEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.cyan,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.keyboard_outlined, size: 18),
                        label: const Text(
                          'Enter Code Manually',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _showTestSimulatorModal,
                        icon: const Icon(Icons.science_outlined, size: 16, color: Colors.white60),
                        label: const Text('Simulate QR Code', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Translucent Cutout Overlay & Viewfinder
          CustomPaint(
            size: size,
            painter: _ScannerOverlayPainter(
              scanSize: scanSize,
              borderColor: colors.cyan,
            ),
          ),

          // 3. Animated Scanning Beam
          Center(
            child: SizedBox(
              width: scanSize,
              height: scanSize,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0, (_animController.value * 2) - 1),
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.cyan.withValues(alpha: 0.1),
                            colors.cyan,
                            colors.cyan.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.cyan.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Top Navigation Bar & Action Icons
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),

                    // Title
                    const Text(
                      'Scan Group QR',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),

                    // Flashlight & Camera Switch Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          onPressed: () async {
                            try {
                              await _controller.toggleTorch();
                              setState(() => _torchOn = !_torchOn);
                            } catch (_) {}
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: _torchOn
                                ? colors.cyan.withValues(alpha: 0.3)
                                : Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: _torchOn
                                    ? colors.cyan
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          icon: Icon(
                            _torchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: _torchOn ? colors.cyan : Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () async {
                            try {
                              await _controller.switchCamera();
                            } catch (_) {}
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                          ),
                          icon: const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Bottom Instructions & Manual Fallback Button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        'Align FairShare QR code within the frame',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openManualEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF131B2E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: colors.cyan.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              elevation: 0,
                            ),
                            icon: Icon(Icons.dialpad_rounded, size: 18, color: colors.cyan),
                            label: const Text(
                              'Enter Code Manually',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: _showTestSimulatorModal,
                          tooltip: 'Simulate QR code',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF131B2E),
                            foregroundColor: colors.cyan,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: colors.cyan.withValues(alpha: 0.5),
                                width: 1.2,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.science_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Processing Loader
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.cyan.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colors.cyan),
                      const SizedBox(height: 16),
                      const Text(
                        'Joining group...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter that draws a semi-transparent mask with a rounded rectangular cutout and cyan corner accents.
class _ScannerOverlayPainter extends CustomPainter {
  final double scanSize;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.scanSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: scanSize,
      height: scanSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    // Draw background with cutout
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw subtle border
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // Draw 4 corner accents
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    const radius = 24.0;

    // Top-Left
    canvas.drawLine(
      Offset(rect.left, rect.top + radius),
      Offset(rect.left, rect.top + radius + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left + radius, rect.top),
      Offset(rect.left + radius + cornerLength, rect.top),
      cornerPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(rect.right, rect.top + radius),
      Offset(rect.right, rect.top + radius + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right - radius, rect.top),
      Offset(rect.right - radius - cornerLength, rect.top),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(rect.left, rect.bottom - radius),
      Offset(rect.left, rect.bottom - radius - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left + radius, rect.bottom),
      Offset(rect.left + radius + cornerLength, rect.bottom),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(rect.right, rect.bottom - radius),
      Offset(rect.right, rect.bottom - radius - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right - radius, rect.bottom),
      Offset(rect.right - radius - cornerLength, rect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanSize != scanSize || oldDelegate.borderColor != borderColor;
  }
}
