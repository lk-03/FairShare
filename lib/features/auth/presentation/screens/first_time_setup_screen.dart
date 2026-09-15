import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/avatar_picker_modal.dart';
import '../../../../data/providers/auth_provider.dart';

const List<String> commonUpiHandles = [
  '@okhdfcbank',
  '@oksbi',
  '@paytm',
  '@ybl',
  '@axl',
  '@ibl',
];

/// FirstTimeSetupScreen guides new users through setting their display name,
/// username handle (@tag), cartoon avatar, and optional UPI VPA for settlement.
class FirstTimeSetupScreen extends ConsumerStatefulWidget {
  final String? initialName;
  final String? initialEmail;
  final VoidCallback onFinish;

  const FirstTimeSetupScreen({
    super.key,
    this.initialName,
    this.initialEmail,
    required this.onFinish,
  });

  @override
  ConsumerState<FirstTimeSetupScreen> createState() =>
      _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends ConsumerState<FirstTimeSetupScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _vpaController;

  String _selectedAvatar = diverseCartoonAvatars[0];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(currentUserProvider);
    final String defaultName = (currentUser?.nickname != null && currentUser!.nickname!.isNotEmpty)
        ? currentUser.nickname!
        : (widget.initialName != null && widget.initialName!.isNotEmpty
            ? widget.initialName!
            : 'You');

    final String defaultUsername = (currentUser?.username != null && currentUser!.username!.isNotEmpty)
        ? currentUser.username!
        : defaultName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    _nicknameController = TextEditingController(text: defaultName);
    _usernameController = TextEditingController(text: defaultUsername);
    _vpaController = TextEditingController(text: currentUser?.vpaId ?? '');

    if (currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty) {
      _selectedAvatar = currentUser.avatarUrl!;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _usernameController.dispose();
    _vpaController.dispose();
    super.dispose();
  }

  void _showMessage(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.colors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.colors.border, width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.colors.cyan,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: TextStyle(
                color: context.colors.textMain,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePasteVpa() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.contains('@')) {
        setState(() => _vpaController.text = text);
      } else {
        _showMessage(
          'No UPI ID in Clipboard',
          'Clipboard does not contain a valid UPI format (e.g. name@bank).',
        );
      }
    } catch (_) {
      _showMessage('Clipboard Error', 'Could not read from clipboard.');
    }
  }

  Future<void> _handleSaveAndStart() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showMessage(
        'Nickname Required',
        'Please enter a display name or nickname.',
      );
      return;
    }

    final username = _usernameController.text
        .trim()
        .replaceAll(RegExp(r'^@'), '')
        .toLowerCase();
    final vpaId = _vpaController.text.trim();

    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      final userId = currentUser?.id ?? 'guest-${DateTime.now().millisecondsSinceEpoch}';
      final email = currentUser?.email ?? widget.initialEmail ?? 'user@fairshare.app';

      final updatedProfile = UserProfile(
        id: userId,
        email: email,
        fullName: nickname,
        nickname: nickname,
        username: username.isNotEmpty ? username : null,
        avatarUrl: _selectedAvatar,
        vpaId: vpaId.isNotEmpty ? vpaId : null,
        isGuest: false,
        createdAt: currentUser?.createdAt ?? DateTime.now(),
      );

      await ref.read(currentUserProvider.notifier).saveProfile(updatedProfile);
      if (mounted) {
        setState(() => _isSaving = false);
      }
      widget.onFinish();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Setup Error', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.screen,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 26, withGlow: true, withShadow: true),
                      const SizedBox(width: 8),
                      Text(
                        'Customize Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: colors.textMain,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: widget.onFinish,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: colors.border, width: 1),
                      ),
                    ),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        // Avatar Picker Preview & Action
                        GestureDetector(
                          onTap: () {
                            AvatarPickerModal.show(
                              context,
                              currentAvatarUrl: _selectedAvatar,
                              onSelectAvatar: (url) {
                                setState(() => _selectedAvatar = url);
                              },
                            );
                          },
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.cyan,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.cyan
                                              .withValues(alpha: 0.25),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.network(
                                      _selectedAvatar,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        color: colors.accentPill,
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 48,
                                          color: colors.cyan,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: colors.cyan,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to change profile picture',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.cyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Display Name / Nickname
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'NICKNAME / DISPLAY NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nicknameController,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (text) {
                            if (_usernameController.text.isEmpty ||
                                _usernameController.text.startsWith('you') ||
                                _usernameController.text.startsWith('alex')) {
                              _usernameController.text = text
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
                            }
                          },
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Alex',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: colors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.border, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.border, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.cyan, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Username Handle (@)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'USERNAME HANDLE (@)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          autocorrect: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 6,
                                top: 14,
                                bottom: 14,
                              ),
                              child: Text(
                                '@',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.cyan,
                                ),
                              ),
                            ),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 0, minHeight: 0),
                            hintText: 'alex_d',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: colors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.border, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.border, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.cyan, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // UPI ID Input with Paste & Handle Chips
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'UPI ID (FOR INSTANT SETTLEMENTS)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _handlePasteVpa,
                              child: Text(
                                'Paste Clipboard',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: colors.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _vpaController,
                          autocorrect: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                          decoration: InputDecoration(
                            hintText: 'name@okaxis',
                            hintStyle: TextStyle(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: colors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.border, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.border, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.cyan, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Common UPI handle chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: commonUpiHandles.map((handle) {
                              return GestureDetector(
                                onTap: () {
                                  final current = _vpaController.text.trim();
                                  final prefix = current.contains('@')
                                      ? current.split('@')[0]
                                      : (current.isNotEmpty
                                          ? current
                                          : _nicknameController.text
                                              .toLowerCase()
                                              .replaceAll(
                                                  RegExp(r'[^a-z0-9]'), ''));
                                  setState(() {
                                    _vpaController.text = '$prefix$handle';
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colors.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    handle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: colors.cyan,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Splitwise Migration Callout Banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colors.emerald.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      colors.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 20,
                                  color: colors.emerald,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Migrating from Splitwise?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: colors.textMain,
                                      ),
                                    ),
                                    Text(
                                      '1-Tap Import export.csv available on Home',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colors.emerald,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: colors.emerald,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSaveAndStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cyan,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF0F172A),
                            ),
                          )
                        : const Text(
                            'Complete Setup & Start',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
