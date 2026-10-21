import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/widgets/avatar_picker_modal.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/group_avatar.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../profile/presentation/widgets/csv_import_sheet.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late String _category;
  String? _avatarUrl;
  bool _isSaving = false;
  bool _initialized = false;

  final List<String> _categories = [
    'trip',
    'house',
    'dining',
    'event',
    'transport',
    'utilities',
    'couple',
    'project',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _category = 'house';
  }

  void _initFields(Group group) {
    if (_initialized) return;
    _nameController.text = group.name;
    _descController.text = group.description ?? '';
    _category = group.category;
    _avatarUrl = group.avatarUrl;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveGroupInfo(Group group) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group name cannot be empty'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(groupsProvider.notifier).updateGroup(group.id, {
        'name': name,
        'description': _descController.text.trim(),
        'category': _category,
        'avatar_url': _avatarUrl,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group settings saved successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleKickMember(
    Group group,
    GroupMember member,
    double netBalance,
  ) async {
    final colors = context.colors;
    final hasUnsettledBalance = netBalance.abs() > 0.01;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Row(
            children: [
              Icon(
                hasUnsettledBalance
                    ? Icons.warning_amber_rounded
                    : Icons.person_remove_rounded,
                color: hasUnsettledBalance ? colors.amber : colors.crimson,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasUnsettledBalance ? 'Unsettled Balance Warning' : 'Remove Member',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textMain,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'Are you sure you want to remove ${member.displayName} from "${group.name}"?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textMain,
                ),
              ),
              if (hasUnsettledBalance) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          netBalance > 0.01
                              ? '${member.displayName} is currently owed ₹${netBalance.toStringAsFixed(2)}. Removing them will leave their balance unsettled.'
                              : '${member.displayName} currently owes ₹${netBalance.abs().toStringAsFixed(2)}. Removing them will leave their debt unsettled.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.crimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Remove Member',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(groupsProvider.notifier)
          .kickMember(group.id, member.userId);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.displayName} was removed from the group'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove member'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreExpense(Expense expense) async {
    await ref
        .read(groupExpensesProvider(widget.groupId).notifier)
        .restoreExpense(expense.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${expense.title}" restored to group ledger'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handlePurgeExpensePermanently(Expense expense) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Permanently Delete Expense',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textMain,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently erase "${expense.title}"? This action cannot be undone.',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.crimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref
          .read(groupExpensesProvider(widget.groupId).notifier)
          .purgeExpensePermanently(expense.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${expense.title}" permanently erased'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLeaveGroup(Group group) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Leave Group',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textMain,
            ),
          ),
          content: Text(
            'Are you sure you want to leave "${group.name}"? If you are the admin, leadership will automatically transfer to the next oldest active member.',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.amber,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Leave Group', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final res = await ref.read(groupsProvider.notifier).leaveGroup(group.id);
      if (!mounted) return;
      if (res.success) {
        context.go('/groups');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.nextAdminName != null
                  ? 'Left "${group.name}". ${res.nextAdminName} is now the admin.'
                  : 'Left "${group.name}".',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not leave group. You may be the only member.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteGroup(Group group) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Delete Group',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textMain,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${group.name}"?\n\nThis group will be moved to Trash for 15 days, after which it will be permanently deleted from the database. You can restore it anytime within 15 days.',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.crimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Move to Trash', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(groupsProvider.notifier).deleteGroup(group.id);
      if (!mounted) return;
      context.go('/groups');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${group.name}" moved to Trash for 15-day recovery'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final groups = ref.watch(groupsProvider).value ?? [];
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;

    if (group == null) {
      return Scaffold(
        backgroundColor: colors.screen,
        appBar: AppBar(
          backgroundColor: colors.screen,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textMain),
            onPressed: () => context.pop(),
          ),
          title: Text('Group Settings', style: TextStyle(color: colors.textMain)),
        ),
        body: Center(
          child: Text('Group not found', style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    _initFields(group);

    final currentUser = ref.watch(currentUserProvider);
    final members = ref.watch(groupMembersProvider(group.id));
    final memberBalances = ref.watch(groupMemberBalancesProvider(group.id));
    final trashExpenses = ref.watch(groupTrashExpensesProvider(group.id));

    final isCurrentAdmin = currentUser == null ||
        group.createdBy == currentUser.id ||
        members.any((m) => m.userId == currentUser.id && m.role == 'admin');

    return Scaffold(
      backgroundColor: colors.screen,
      appBar: AppBar(
        backgroundColor: colors.screen,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Group Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textMain,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : () => _saveGroupInfo(group),
              icon: _isSaving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
                      ),
                    )
                  : Icon(Icons.check_rounded, size: 18, color: colors.cyan),
              label: Text(
                'Save',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.cyan,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Group Profile & Avatar
                _buildSectionHeader(
                  title: 'Group Profile',
                  subtitle: 'Customize avatar, name, and category',
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildGroupProfileCard(group, colors),

                const SizedBox(height: 28),

                // Section 2: Members & Live Balances
                _buildSectionHeader(
                  title: 'Members Roster',
                  subtitle: 'Live group balances and governance',
                  badgeText: '${members.length}',
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildMembersRosterCard(group, members, memberBalances, isCurrentAdmin, currentUser?.id, colors),

                const SizedBox(height: 28),

                // Section 3: Data & History Import
                _buildSectionHeader(
                  title: 'Import History',
                  subtitle: 'Add past Splitwise or ledger transactions into this group',
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildImportCsvCard(group, colors),

                const SizedBox(height: 28),

                // Section 4: Trash & Recently Deleted Logs (24h Recovery)
                _buildSectionHeader(
                  title: 'Expense Trash',
                  subtitle: 'Restore deleted expenses within 24 hours',
                  badgeText: trashExpenses.isNotEmpty ? '${trashExpenses.length}' : null,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildTrashCard(trashExpenses, colors),

                const SizedBox(height: 28),

                // Section 4: Danger Zone
                _buildSectionHeader(
                  title: 'Danger Zone',
                  subtitle: 'Leave or schedule group for deletion',
                  isDestructive: true,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildDangerZoneCard(group, isCurrentAdmin, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    String? badgeText,
    bool isDestructive = false,
    required AppThemeColors colors,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDestructive ? colors.crimson : colors.textMain,
                      ),
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.cyan,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupProfileCard(Group group, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar Picker Row
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    AvatarPickerModal.show(
                      context,
                      currentAvatarUrl: _avatarUrl,
                      onSelectAvatar: (newUrl) {
                        setState(() => _avatarUrl = newUrl);
                      },
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.cyan, width: 2.5),
                    ),
                    child: GroupAvatar(
                      avatarUrl: _avatarUrl,
                      category: _category,
                      size: 72,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      AvatarPickerModal.show(
                        context,
                        currentAvatarUrl: _avatarUrl,
                        onSelectAvatar: (newUrl) {
                          setState(() => _avatarUrl = newUrl);
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.cyan,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () {
                AvatarPickerModal.show(
                  context,
                  currentAvatarUrl: _avatarUrl,
                  onSelectAvatar: (newUrl) {
                    setState(() => _avatarUrl = newUrl);
                  },
                );
              },
              child: Text(
                'Change Group Avatar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.cyan,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Name field
          Text(
            'Group Name',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textMain,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.accentPill,
              hintText: 'e.g. Goa Trip 2026',
              hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Category Chips
          Text(
            'Category',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isSelected = _category == cat;
              return ChoiceChip(
                label: Text(
                  cat[0].toUpperCase() + cat.substring(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFF0F172A) : colors.textMain,
                  ),
                ),
                selected: isSelected,
                selectedColor: colors.cyan,
                backgroundColor: colors.accentPill,
                showCheckmark: false,
                side: BorderSide(
                  color: isSelected ? colors.cyan : colors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _category = cat);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Description field
          Text(
            'Description (Optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            maxLines: 2,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textMain,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.accentPill,
              hintText: 'Add notes or group description',
              hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersRosterCard(
    Group group,
    List<GroupMember> members,
    Map<String, double> memberBalances,
    bool isCurrentAdmin,
    String? currentUserId,
    AppThemeColors colors,
  ) {
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, _) => Divider(
          color: colors.border.withValues(alpha: 0.5),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final member = members[index];
          final isAdmin = member.role == 'admin' || member.userId == group.createdBy;
          final isCurrentUser = member.userId == currentUserId;
          final balance = memberBalances[member.userId] ?? 0.0;

          final isSettled = balance.abs() <= 0.01;
          final isOwed = balance > 0.01;

          final balanceText = isSettled
              ? 'Settled'
              : (isOwed
                  ? 'Owed ₹${balance.toStringAsFixed(2)}'
                  : 'Owes ₹${balance.abs().toStringAsFixed(2)}');

          final balanceColor = isSettled
              ? colors.textSecondary
              : (isOwed ? colors.emerald : colors.crimson);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: UserAvatar(
              avatarUrl: member.profile?.avatarUrl,
              name: member.displayName,
              userId: member.userId,
              radius: 20,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isCurrentUser ? '${member.displayName} (You)' : member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colors.amber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: balanceColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    balanceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: balanceColor,
                    ),
                  ),
                ),
              ],
            ),
            trailing: (isCurrentAdmin && !isCurrentUser && member.role != 'admin')
                ? IconButton(
                    icon: Icon(Icons.person_remove_rounded, size: 20, color: colors.crimson),
                    tooltip: 'Remove from group',
                    onPressed: () => _handleKickMember(group, member, balance),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildImportCsvCard(Group group, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.swap_horiz_rounded, size: 22, color: colors.emerald),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import CSV Transactions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Migrate past expenses directly into "${group.name}". Members will be matched automatically.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => CsvImportSheet.show(context, targetGroup: group),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.emerald,
                side: BorderSide(color: colors.emerald.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text(
                'Import CSV into Group',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCard(List<Expense> trashExpenses, AppThemeColors colors) {
    if (trashExpenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.accentPill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete_outline_rounded, color: colors.textSecondary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trash is empty',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Deleted expenses remain here for 24 hours before automatic permanent purge.',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: trashExpenses.length,
        separatorBuilder: (_, _) => Divider(
          color: colors.border.withValues(alpha: 0.5),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final exp = trashExpenses[index];
          final now = DateTime.now();
          final deletedTime = exp.deletedAt ?? exp.updatedAt;
          final hoursElapsed = now.difference(deletedTime).inHours;
          final hoursLeft = (24 - hoursElapsed).clamp(0, 24);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CategoryIcon(
                  category: exp.category,
                  customIcon: exp.customIcon,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${exp.totalAmount.toStringAsFixed(2)} · ${hoursLeft}h left to restore',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.restore_rounded, size: 20, color: colors.cyan),
                      tooltip: 'Restore',
                      onPressed: () => _handleRestoreExpense(exp),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_forever_rounded, size: 20, color: colors.crimson),
                      tooltip: 'Delete Now',
                      onPressed: () => _handlePurgeExpensePermanently(exp),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDangerZoneCard(Group group, bool isCurrentAdmin, AppThemeColors colors) {
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.crimson.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
        children: [
          // Leave Group
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.exit_to_app_rounded, color: colors.amber, size: 20),
            ),
            title: Text(
              'Leave Group',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textMain,
              ),
            ),
            subtitle: Text(
              'Remove yourself from this group. Admin role transfers if applicable.',
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
            onTap: () => _handleLeaveGroup(group),
          ),

          if (isCurrentAdmin) ...[
            Divider(color: colors.border.withValues(alpha: 0.5), height: 16),
            // Delete Group
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.crimson.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_forever_rounded, color: colors.crimson, size: 20),
              ),
              title: Text(
                'Delete Group',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.crimson,
                ),
              ),
              subtitle: Text(
                'Move group to Trash with 15-day recovery before permanent purge.',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
              onTap: () => _handleDeleteGroup(group),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
