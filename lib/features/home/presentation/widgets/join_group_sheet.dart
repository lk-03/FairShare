import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../data/providers/groups_provider.dart';

class JoinGroupSheet extends ConsumerStatefulWidget {
  final ValueChanged<Group>? onGroupJoined;
  final VoidCallback? onScanQr;

  const JoinGroupSheet({
    super.key,
    this.onGroupJoined,
    this.onScanQr,
  });

  static Future<Group?> show(
    BuildContext context, {
    VoidCallback? onScanQr,
  }) {
    return showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JoinGroupSheet(onScanQr: onScanQr),
    );
  }

  @override
  ConsumerState<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<JoinGroupSheet> {
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final clean = data.text!
            .replaceAll(RegExp(r'^(fairshare:\/\/join\/|https?:\/\/[^\/]+\/join\/)', caseSensitive: false), '')
            .trim()
            .toUpperCase();
        setState(() {
          _codeController.text = clean;
          _error = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleJoin() async {
    final raw = _codeController.text.trim();
    final clean = raw
        .replaceAll(RegExp(r'^(fairshare:\/\/join\/|https?:\/\/[^\/]+\/join\/)', caseSensitive: false), '')
        .trim()
        .toUpperCase();

    if (clean.isEmpty) {
      setState(() => _error = 'Please enter an invite code');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final group = await ref.read(groupsProvider.notifier).joinGroupByInviteCode(clean);
      if (group != null) {
        if (mounted) {
          widget.onGroupJoined?.call(group);
          Navigator.of(context).pop(group);
        }
      } else {
        setState(() {
          _isJoining = false;
          _error = 'Invite code "$clean" was not found. Please verify with your group admin.';
        });
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join a Group',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enter the 6-8 digit invite code shared with you',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Invite Code input
            Text(
              'INVITE CODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.cyan,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: colors.textMain,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. BLR402',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        letterSpacing: 0,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: colors.accentPill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.cyan, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _pasteClipboard,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.accentPill,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.border, width: 1),
                    ),
                    padding: const EdgeInsets.all(14),
                  ),
                  tooltip: 'Paste from clipboard',
                  icon: Icon(Icons.content_paste_rounded, color: colors.cyan),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            FilledButton(
              onPressed: _isJoining ? null : _handleJoin,
              style: FilledButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Join Group',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.screen,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
