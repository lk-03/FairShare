import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/avatar_picker_modal.dart';
import '../../../../data/providers/auth_provider.dart';

final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,24}$');

class EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile user;

  const EditProfileSheet({
    super.key,
    required this.user,
  });

  static Future<void> show(BuildContext context, {required UserProfile user}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(user: user),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _usernameController;
  String? _avatarUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _nicknameController =
        TextEditingController(text: widget.user.nickname ?? '');
    _usernameController =
        TextEditingController(text: widget.user.username ?? '');
    _avatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String get _sanitizedUsername => _usernameController.text
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^@'), '');

  bool get _isValidUsername =>
      _sanitizedUsername.isEmpty || _usernameRegex.hasMatch(_sanitizedUsername);

  Future<void> _handleSave() async {
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }

    if (_sanitizedUsername.isNotEmpty &&
        !_usernameRegex.hasMatch(_sanitizedUsername)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Username must be between 3 and 24 characters (letters, numbers, underscores only)',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final nickname = _nicknameController.text.trim();
      await ref.read(currentUserProvider.notifier).updateProfile(
            fullName: fullName,
            nickname: nickname.isNotEmpty ? nickname : fullName,
            username: _sanitizedUsername.isNotEmpty ? _sanitizedUsername : null,
            avatarUrl: _avatarUrl,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
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
    final displayName = _nicknameController.text.trim().isNotEmpty
        ? _nicknameController.text.trim()
        : (_fullNameController.text.trim().isNotEmpty
            ? _fullNameController.text.trim()
            : 'You');

    return Container(
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
              // Handle Bar
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
                    'Edit Profile',
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

              // Avatar Row
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
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.cyan, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: colors.accentPill,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: colors.cyan,
                                  size: 28,
                                ),
                              ),
                            )
                          : Container(
                              color: colors.accentPill,
                              alignment: Alignment.center,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: colors.cyan,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Photo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cartoon avatar or picture',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        AvatarPickerModal.show(
                          context,
                          currentAvatarUrl: _avatarUrl,
                          onSelectAvatar: (selected) {
                            setState(() => _avatarUrl = selected);
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        side: BorderSide(color: colors.cyan, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: colors.cyan.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nickname Field
              Text(
                'NICKNAME (PRIMARY DISPLAY NAME)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_profile_nickname_field'),
                controller: _nicknameController,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textMain,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.sentiment_satisfied_alt_rounded,
                    color: colors.cyan,
                    size: 20,
                  ),
                  hintText: 'e.g. Sam, Rahul',
                  hintStyle: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: colors.screen,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.cyan, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This will be shown prominently in your groups, debts, and expense splits.',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Username Handle Field
              Text(
                'USERNAME HANDLE (@TAG)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_profile_username_field'),
                controller: _usernameController,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textMain,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '@',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colors.cyan,
                      ),
                    ),
                  ),
                  suffixIcon: _sanitizedUsername.isNotEmpty && _isValidUsername
                      ? Icon(Icons.check_circle_rounded,
                          color: colors.cyan, size: 20)
                      : null,
                  hintText: 'username',
                  hintStyle: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: colors.screen,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: _isValidUsername ? colors.border : colors.red),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: _isValidUsername ? colors.border : colors.red),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: _isValidUsername ? colors.cyan : colors.red,
                        width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Friends can mention you in comments with @${_sanitizedUsername.isEmpty ? 'username' : _sanitizedUsername}.',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Full Legal Name Field
              Text(
                'FULL LEGAL NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_profile_fullname_field'),
                controller: _fullNameController,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textMain,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  hintText: 'Your Full Name',
                  hintStyle: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: colors.screen,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.cyan, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.cyan,
                  foregroundColor: const Color(0xFF0F172A),
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
                        'Save Profile Changes',
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
