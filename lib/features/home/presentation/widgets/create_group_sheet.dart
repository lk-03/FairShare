import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/friend.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../friends/presentation/widgets/friends_picker_modal.dart';
import '../../../groups/presentation/widgets/create_local_group_sheet.dart';
import '../../../profile/presentation/widgets/csv_import_sheet.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  final ValueChanged<Group>? onGroupCreated;

  const CreateGroupSheet({
    super.key,
    this.onGroupCreated,
  });

  static Future<Group?> show(BuildContext context) {
    return showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateGroupSheet(),
    );
  }

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'house';
  final String _currency = 'INR';
  List<Friend> _selectedFriends = [];
  bool _isCreating = false;
  String? _error;

  final List<({String key, String label})> _categories = [
    (key: 'house', label: 'House / Roommates'),
    (key: 'trip', label: 'Trip / Travel'),
    (key: 'event', label: 'Event'),
    (key: 'dining', label: 'Dining'),
    (key: 'transport', label: 'Transport'),
    (key: 'utilities', label: 'Utilities'),
    (key: 'custom', label: 'Custom'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickFriends() async {
    final picked = await FriendsPickerModal.show(
      context,
      initiallySelected: _selectedFriends,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedFriends = picked;
      });
    }
  }

  String _generateInviteCode(String groupName) {
    final clean = groupName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final prefix = clean.length >= 3 ? clean.substring(0, 3) : (clean.isNotEmpty ? clean : 'FS');
    final randomSuffix = (100 + Random().nextInt(900)).toString();
    return '$prefix$randomSuffix';
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a group name');
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      setState(() => _error = 'Please sign in to create a group');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final inviteCode = _generateInviteCode(name);
      final newGroup = Group(
        id: 'cohort_${now.millisecondsSinceEpoch}',
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        category: _selectedCategory,
        currency: _currency,
        createdBy: currentUser.id,
        inviteCode: inviteCode,
        createdAt: now,
        updatedAt: now,
      );

      final created = await ref.read(groupsProvider.notifier).createGroup(newGroup);
      if (_selectedFriends.isNotEmpty) {
        final friendMembers = _selectedFriends.map((f) => GroupMember(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}_${f.id}',
          cohortId: created.id,
          userId: f.friendUserId,
          profile: f.profile,
          joinedAt: DateTime.now(),
        )).toList();
        await ref.read(groupRepositoryProvider).addMembersToCohort(created.id, friendMembers);
        ref.invalidate(groupMembersProvider(created.id));
      }

      if (mounted) {
        widget.onGroupCreated?.call(created);
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                        'Create New Group',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set up a shared ledger with friends or roommates',
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
            const SizedBox(height: 16),

            // Group Type Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.accentPill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_outlined, size: 16, color: colors.cyan),
                          const SizedBox(width: 6),
                          Text(
                            'Cloud Group',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        CreateLocalGroupSheet.show(
                          context,
                          onGroupCreated: widget.onGroupCreated,
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phonelink_setup_rounded, size: 16, color: colors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Quick Group',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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

            // Group Name Input
            Text(
              'GROUP NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.cyan,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(fontSize: 15, color: colors.textMain),
              decoration: InputDecoration(
                hintText: 'e.g., Flat 402, Goa Trip 2026',
                hintStyle: TextStyle(fontSize: 14, color: colors.textSecondary.withValues(alpha: 0.6)),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            Text(
              'DESCRIPTION (OPTIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.cyan,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              style: TextStyle(fontSize: 14, color: colors.textMain),
              decoration: InputDecoration(
                hintText: 'e.g., Monthly groceries & Wi-Fi bills',
                hintStyle: TextStyle(fontSize: 14, color: colors.textSecondary.withValues(alpha: 0.6)),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Category Picker
            Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.cyan,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.key;
                return InkWell(
                  onTap: () => setState(() => _selectedCategory = cat.key),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.cyan.withValues(alpha: 0.15)
                          : colors.accentPill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? colors.cyan : colors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryIcon(
                          category: cat.key,
                          size: 24,
                          variant: isSelected
                              ? CategoryIconVariant.solid
                              : CategoryIconVariant.light,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? colors.cyan : colors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Add Friends Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ADD FRIENDS (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.cyan,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickFriends,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: Text(_selectedFriends.isEmpty ? 'Select Friends' : 'Edit (${_selectedFriends.length})'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.cyan,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_selectedFriends.isEmpty)
              InkWell(
                onTap: _pickFriends,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.accentPill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 18, color: colors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        'Tap to invite friends from your hub',
                        style: TextStyle(fontSize: 13, color: colors.textSecondary),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, size: 18, color: colors.textSecondary),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedFriends.map((f) {
                  return Chip(
                    avatar: UserAvatar(
                      avatarUrl: f.avatarUrl,
                      name: f.displayName,
                      radius: 12,
                    ),
                    label: Text(
                      f.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textMain,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedFriends.removeWhere((item) => item.id == f.id);
                      });
                    },
                    backgroundColor: colors.surfaceElevated,
                    side: BorderSide(color: colors.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton(
              onPressed: _isCreating ? null : _handleCreate,
              style: FilledButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Create Group',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.screen,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Divider(color: colors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colors.border)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                CsvImportSheet.show(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.emerald,
                side: BorderSide(color: colors.emerald.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text(
                'Import from CSV (Splitwise)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
