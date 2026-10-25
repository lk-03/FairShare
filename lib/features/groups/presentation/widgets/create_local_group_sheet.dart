import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class CreateLocalGroupSheet extends ConsumerStatefulWidget {
  final ValueChanged<Group>? onGroupCreated;

  const CreateLocalGroupSheet({
    super.key,
    this.onGroupCreated,
  });

  static Future<Group?> show(
    BuildContext context, {
    ValueChanged<Group>? onGroupCreated,
  }) {
    return showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateLocalGroupSheet(onGroupCreated: onGroupCreated),
    );
  }

  @override
  ConsumerState<CreateLocalGroupSheet> createState() =>
      _CreateLocalGroupSheetState();
}

class _CreateLocalGroupSheetState extends ConsumerState<CreateLocalGroupSheet> {
  final _nameController = TextEditingController();
  final _participantController = TextEditingController();
  final _participantFocusNode = FocusNode();

  String _selectedCategory = 'dining';
  final String _currency = 'INR';
  final List<String> _participants = ['Me'];
  bool _isCreating = false;
  String? _error;

  final List<({String key, String label})> _categories = [
    (key: 'dining', label: 'Dining / Food'),
    (key: 'trip', label: 'Trip / Travel'),
    (key: 'event', label: 'Event / Party'),
    (key: 'house', label: 'House / Roommates'),
    (key: 'transport', label: 'Transport'),
    (key: 'custom', label: 'Custom'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _participantController.dispose();
    _participantFocusNode.dispose();
    super.dispose();
  }

  void _addParticipant() {
    final name = _participantController.text.trim();
    if (name.isEmpty) return;

    if (_participants.any((p) => p.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = '"$name" is already in the list');
      return;
    }

    setState(() {
      _participants.add(name);
      _participantController.clear();
      _error = null;
    });

    _participantFocusNode.requestFocus();
  }

  void _removeParticipant(int index) {
    if (_participants.length <= 1) {
      setState(() => _error = 'An outing needs at least 2 people to split');
      return;
    }
    setState(() {
      _participants.removeAt(index);
      _error = null;
    });
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter an outing or group name');
      return;
    }

    if (_participants.length < 2) {
      setState(() => _error = 'Please add at least one other friend to split with');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final groupId = 'local_${now.millisecondsSinceEpoch}';

      final currentUser = ref.read(currentUserProvider);
      final myName = currentUser?.displayName.isNotEmpty == true
          ? currentUser!.displayName
          : 'Me';

      final List<GroupMember> members = [];
      for (int i = 0; i < _participants.length; i++) {
        final pName = _participants[i];
        final isMe = i == 0;
        final userId = isMe && currentUser != null
            ? currentUser.id
            : 'user_local_${now.microsecondsSinceEpoch}_$i';

        final effectiveName = isMe && pName == 'Me' ? myName : pName;

        members.add(
          GroupMember(
            id: 'gm_local_${now.microsecondsSinceEpoch}_$i',
            cohortId: groupId,
            userId: userId,
            role: isMe ? 'admin' : 'member',
            joinedAt: now,
            isPlaceholder: !isMe,
            originalCsvName: effectiveName,
            profile: UserProfile(
              id: userId,
              fullName: effectiveName,
              createdAt: now,
            ),
          ),
        );
      }

      final newGroup = Group(
        id: groupId,
        name: name,
        category: _selectedCategory,
        currency: _currency,
        createdBy: members.first.userId,
        inviteCode: '',
        isLocal: true,
        createdAt: now,
        updatedAt: now,
        members: members,
      );

      final created =
          await ref.read(groupsProvider.notifier).createGroup(newGroup);

      if (mounted) {
        widget.onGroupCreated?.call(created);
        Navigator.of(context).pop(created);
        context.push('/groups/${created.id}');
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: colors.screen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 38,
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flash_on_rounded, color: colors.cyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Local Outing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: colors.textMain,
                        ),
                      ),
                      Text(
                        'Offline on this device · Zero login required',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
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

            // Error Banner
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: colors.red),
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
            ],

            // Outing Name Input
            Text(
              'OUTING / GROUP NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(color: colors.textMain, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Goa Trip, Friday Dinner, Social Drinks',
                hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
                filled: true,
                fillColor: colors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.cyan, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Picker
            Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat.key == _selectedCategory;
                  return InkWell(
                    onTap: () => setState(() => _selectedCategory = cat.key),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.cyan.withValues(alpha: 0.15)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? colors.cyan : colors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryIcon(category: cat.key, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? colors.cyan
                                  : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Participants Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PEOPLE SPLITTING (${_participants.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  'Quick naming · No phone or email',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick add participant input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _participantController,
                    focusNode: _participantFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addParticipant(),
                    style: TextStyle(color: colors.textMain, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type friend name (e.g. Rahul, Priya)...',
                      hintStyle: TextStyle(
                          color: colors.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.cyan, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addParticipant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.cyan,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18),
                      SizedBox(width: 4),
                      Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chips of participants
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _participants.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final isMe = idx == 0;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: isMe
                        ? colors.cyan.withValues(alpha: 0.2)
                        : colors.accentPill,
                    child: Text(
                      p.isNotEmpty ? p[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isMe ? colors.cyan : colors.textMain,
                      ),
                    ),
                  ),
                  label: Text(
                    p,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                  ),
                  deleteIcon: isMe
                      ? null
                      : Icon(Icons.close_rounded, size: 14, color: colors.textSecondary),
                  onDeleted: isMe ? null : () => _removeParticipant(idx),
                  backgroundColor: colors.surface,
                  side: BorderSide(color: isMe ? colors.cyan : colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _handleCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.cyan,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Start Outing & Split Expenses',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
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
