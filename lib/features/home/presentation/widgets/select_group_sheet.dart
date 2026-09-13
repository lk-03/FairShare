import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../core/widgets/group_avatar.dart';
import '../../../../data/providers/groups_provider.dart';

class SelectGroupSheet extends ConsumerWidget {
  final ValueChanged<Group> onSelectGroup;
  final VoidCallback? onCreateNewGroup;

  const SelectGroupSheet({
    super.key,
    required this.onSelectGroup,
    this.onCreateNewGroup,
  });

  static Future<Group?> show(
    BuildContext context, {
    VoidCallback? onCreateNewGroup,
  }) {
    return showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SelectGroupSheet(
        onSelectGroup: (g) => Navigator.of(ctx).pop(g),
        onCreateNewGroup: onCreateNewGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final groupsAsync = ref.watch(groupsProvider);
    final allGroups = groupsAsync.value ?? [];
    final activeCohorts = allGroups.where((c) => !c.isDeleted).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Group',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Which group is this expense for?',
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

          // Cohort List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: activeCohorts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cohort = activeCohorts[index];
                final memberCount = cohort.members.isNotEmpty
                    ? cohort.members.length
                    : ref.watch(groupMembersProvider(cohort.id)).length;

                return InkWell(
                  onTap: () => onSelectGroup(cohort),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.accentPill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        GroupAvatar(
                          avatarUrl: cohort.avatarUrl ?? cohort.bannerUrl,
                          category: cohort.category,
                          customIcon: cohort.customIcon,
                          size: 44,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cohort.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$memberCount ${memberCount == 1 ? 'member' : 'members'} • ${cohort.currency}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (onCreateNewGroup != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onCreateNewGroup!();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: colors.cyan.withValues(alpha: 0.5),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(Icons.add_rounded, color: colors.cyan, size: 20),
              label: Text(
                'Create New Group',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.cyan,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
