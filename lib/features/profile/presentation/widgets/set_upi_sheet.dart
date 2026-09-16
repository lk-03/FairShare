import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/profile.dart';
import '../../../../data/providers/auth_provider.dart';

final _upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

const List<String> _popularHandles = [
  '@okhdfcbank',
  '@oksbi',
  '@okaxis',
  '@okicici',
  '@paytm',
  '@ybl',
  '@ibl',
  '@apl',
];

class SetUpiSheet extends ConsumerStatefulWidget {
  final UserProfile user;

  const SetUpiSheet({
    super.key,
    required this.user,
  });

  static Future<void> show(BuildContext context, {required UserProfile user}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SetUpiSheet(user: user),
    );
  }

  @override
  ConsumerState<SetUpiSheet> createState() => _SetUpiSheetState();
}

class _SetUpiSheetState extends ConsumerState<SetUpiSheet> {
  late final TextEditingController _vpaController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _vpaController = TextEditingController(text: widget.user.vpaId ?? '');
  }

  @override
  void dispose() {
    _vpaController.dispose();
    super.dispose();
  }

  String get _sanitizedVpa =>
      _vpaController.text.trim().replaceAll(' ', '').toLowerCase();

  bool get _isValidVpa => _upiRegex.hasMatch(_sanitizedVpa);

  void _handleAppendHandle(String handle) {
    final vpa = _sanitizedVpa;
    if (vpa.contains('@')) {
      final prefix = vpa.split('@').first;
      _vpaController.text = '$prefix$handle';
    } else if (vpa.isNotEmpty) {
      _vpaController.text = '$vpa$handle';
    } else {
      _vpaController.text = handle;
    }
    setState(() {});
  }

  Future<void> _handlePasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }

    String cleaned = text;
    if (cleaned.contains('pa=')) {
      final match = RegExp(r'pa=([^&]+)').firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        cleaned = Uri.decodeComponent(match.group(1)!);
      }
    } else if (cleaned.startsWith('upi://pay?')) {
      cleaned = cleaned.replaceFirst('upi://pay?', '');
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    setState(() {
      _vpaController.text = cleaned;
    });
  }

  Future<void> _handleSave() async {
    if (_sanitizedVpa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your UPI ID')),
      );
      return;
    }

    if (!_isValidVpa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid UPI ID format. Expected format: username@bank (e.g. rahul@okaxis)',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(currentUserProvider.notifier).updateProfile(
            vpaId: _sanitizedVpa,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UPI ID saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save UPI ID: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isPaytm = _sanitizedVpa.endsWith('@paytm');

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.88,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set UPI ID',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colors.textMain,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.screen,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accentPill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.credit_card_rounded,
                        color: colors.cyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Direct 0-Fee Settlements',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: colors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your UPI ID allows friends to settle group debts with 1 tap via GPay, PhonePe, or Paytm.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Label & Paste Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOUR UPI ADDRESS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: colors.textSecondary,
                    ),
                  ),
                  InkWell(
                    onTap: _handlePasteFromClipboard,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.accentPill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_paste_rounded,
                              size: 13, color: colors.cyan),
                          const SizedBox(width: 5),
                          Text(
                            'Paste from Clipboard',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Input Field
              TextField(
                key: const Key('set_upi_input_field'),
                controller: _vpaController,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textMain,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    size: 20,
                    color: _isValidVpa ? colors.cyan : colors.textSecondary,
                  ),
                  suffixIcon: _isValidVpa
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        size: 14, color: colors.cyan),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Valid',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: colors.cyan,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                  hintText: 'e.g. mobile@okhdfcbank, name@upi',
                  hintStyle: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: colors.screen,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: _isValidVpa ? colors.cyan : colors.border,
                        width: _isValidVpa ? 1.5 : 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: _isValidVpa ? colors.cyan : colors.border,
                        width: _isValidVpa ? 1.5 : 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.cyan, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Bank Handles
              Text(
                'QUICK BANK HANDLES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularHandles.map((handle) {
                  final atIndex = _sanitizedVpa.indexOf('@');
                  final currentHandle =
                      atIndex > -1 ? _sanitizedVpa.substring(atIndex) : '';
                  final isSelected = currentHandle == handle;

                  return InkWell(
                    onTap: () => _handleAppendHandle(handle),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.cyan : colors.screen,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? colors.cyan : colors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        handle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : colors.textMain,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (isPaytm) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: Paytm Payments Bank wallet VPAs may have settlement limitations. Bank-linked accounts function normally.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Typo & Error Prevention Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.screen,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: colors.cyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Typo & Error Prevention',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ensure your UPI ID matches the one in your Google Pay, PhonePe, or BHIM settings. You can paste directly using the button above or tap one of the common bank handles.',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isValidVpa && !_isSaving ? _handleSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.cyan,
                  foregroundColor: const Color(0xFF0F172A),
                  disabledBackgroundColor: colors.accentPill,
                  disabledForegroundColor: colors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                        ),
                      )
                    : const Text(
                        'Save UPI ID',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
