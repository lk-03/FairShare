import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../core/widgets/group_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import 'edit_group_sheet.dart';
import 'group_qr_sheet.dart';

class GroupActionSheet extends ConsumerWidget {
  final Group group;
  final VoidCallback? onInvite;
  final VoidCallback? onEdit;

  const GroupActionSheet({
    super.key,
    required this.group,
    this.onInvite,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    Group group, {
    VoidCallback? onInvite,
    VoidCallback? onEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupActionSheet(
        group: group,
        onInvite: onInvite,
        onEdit: onEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentUser = ref.watch(currentUserProvider);
    final members = ref.watch(groupMembersProvider(group.id));

    final isCurrentAdmin = currentUser == null ||
        group.createdBy == currentUser.id ||
        members.any((m) => m.userId == currentUser.id && m.role == 'admin');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: colors.border, width: 1),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              GroupAvatar(
                avatarUrl: group.avatarUrl ?? group.bannerUrl,
                category: group.category,
                customIcon: group.customIcon,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Code: ${group.inviteCode}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (group.isArchived) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentPill,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              'Archived (Muted)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.cyan,
                              ),
                            ),
                          ),
                        ],
                      ],
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

          // Action: Invite Members
          _buildActionTile(
            context: context,
            icon: Icons.qr_code_2_rounded,
            iconColor: colors.cyan,
            iconBg: colors.cyan.withValues(alpha: 0.15),
            title: 'Invite Members',
            subtitle: 'Share QR code or copy invite code (${group.inviteCode})',
            onTap: () {
              Navigator.of(context).pop();
              if (onInvite != null) {
                onInvite!();
              } else {
                GroupQrSheet.show(context, group);
              }
            },
          ),

          const SizedBox(height: 10),

          // Action: Edit Group (Admin only)
          if (isCurrentAdmin) ...[
            _buildActionTile(
              context: context,
              icon: Icons.edit_outlined,
              iconColor: colors.emerald,
              iconBg: colors.emerald.withValues(alpha: 0.15),
              title: 'Edit Group',
              subtitle: 'Change name, icon, category, or description',
              onTap: () {
                Navigator.of(context).pop();
                if (onEdit != null) {
                  onEdit!();
                } else {
                  EditGroupSheet.show(context, group);
                }
              },
            ),
            const SizedBox(height: 10),
          ],

          // Action: Archive / Unarchive Group
          _buildActionTile(
            context: context,
            icon: group.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            title: group.isArchived ? 'Unarchive Group' : 'Archive Group',
            subtitle: group.isArchived
                ? 'Include group balance back into your total owings'
                : 'Stop including in total owings (never auto-deletes)',
            onTap: () async {
              Navigator.of(context).pop();
              final nextArchived = !group.isArchived;
              await ref.read(groupsProvider.notifier).toggleArchiveGroup(group.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      nextArchived
                          ? '"${group.name}" is now archived.'
                          : '"${group.name}" is now unarchived.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),

          // Action: Delete Group (Admin only)
          if (isCurrentAdmin) ...[
            const SizedBox(height: 10),
            _buildActionTile(
              context: context,
              icon: Icons.delete_outline_rounded,
              iconColor: colors.red,
              iconBg: colors.red.withValues(alpha: 0.15),
              title: 'Delete Group',
              titleColor: colors.red,
              subtitle:
                  'Move to Trash for 15 days before permanent database deletion',
              subtitleColor: colors.red.withValues(alpha: 0.8),
              borderColor: colors.red.withValues(alpha: 0.25),
              onTap: () => _confirmDeleteGroup(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? subtitleColor,
    Color? borderColor,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.accentPill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? colors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor ?? colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: titleColor ?? colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final colors = dialogCtx.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Delete Group',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.textMain,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${group.name}"?\n\n'
            'This group will be moved to Trash for 15 days, after which it will be permanently deleted from the database. You can restore it anytime within 15 days.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
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
                backgroundColor: colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text(
                'Delete Group (15 Days Trash)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close bottom sheet
        }
        await ref.read(groupsProvider.notifier).deleteGroup(group.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"${group.name}" has been moved to Trash and will be permanently deleted in 15 days.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }
}
