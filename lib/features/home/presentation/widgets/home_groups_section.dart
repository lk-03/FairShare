import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/algorithms/debt_simplifier.dart';
import '../../../../core/models/group.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/group_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class HomeGroupsSection extends ConsumerWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  final VoidCallback onImportSplitwise;
  final ValueChanged<Group> onGroupTap;
  final ValueChanged<Group>? onGroupLongPress;

  const HomeGroupsSection({
    super.key,
    required this.onCreateGroup,
    required this.onJoinGroup,
    required this.onImportSplitwise,
    required this.onGroupTap,
    this.onGroupLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider);

    final allGroups = groupsAsync.value ?? [];
    final activeCohorts = allGroups.where((c) => !c.isDeleted).toList();
    final isLoading = groupsAsync.isLoading && allGroups.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Groups',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.textMain,
              ),
            ),
            Row(
              children: [
                // Splitwise Import Chip
                InkWell(
                  onTap: onImportSplitwise,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.emerald.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 14,
                          color: colors.emerald,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Import Splitwise',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (activeCohorts.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => context.go('/groups'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View All (${activeCohorts.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.cyan,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Section Body
        if (isLoading)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading your groups...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (activeCohorts.isEmpty)
          EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No Groups Yet',
            description:
                'Create or join an event cohort to start splitting expenses with friends, roommates, or travel partners.',
            primaryActionLabel: 'Create First Group',
            onPrimaryAction: onCreateGroup,
            secondaryActionLabel: 'Join with Code',
            onSecondaryAction: onJoinGroup,
            variant: EmptyStateVariant.card,
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: activeCohorts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final cohort = activeCohorts[index];
                final expenses =
                    ref.watch(groupExpensesProvider(cohort.id)).value ?? [];
                final members = ref.watch(groupMembersProvider(cohort.id));

                final res = DebtSimplifier.calculateSimplifiedDebts(
                  cohortId: cohort.id,
                  members: members,
                  expenses: expenses,
                );
                final userBal =
                    currentUser != null ? (res.netBalances[currentUser.id] ?? 0.0) : 0.0;

                final isPositive = userBal > 0.01;
                final isNegative = userBal < -0.01;

                Color badgeBg = isDark ? colors.accentPill : const Color(0xFFF1F5F9);
                Color badgeTextColor = colors.textSecondary;
                String badgeText = '₹0';

                if (isPositive) {
                  badgeBg = colors.emerald.withValues(alpha: 0.15);
                  badgeTextColor = colors.emerald;
                  badgeText = '+₹${userBal.toStringAsFixed(0)}';
                } else if (isNegative) {
                  badgeBg = colors.red.withValues(alpha: 0.15);
                  badgeTextColor = colors.red;
                  badgeText = '-₹${userBal.abs().toStringAsFixed(0)}';
                }

                return InkWell(
                  onTap: () => onGroupTap(cohort),
                  onLongPress: onGroupLongPress != null
                      ? () => onGroupLongPress!(cohort)
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 176,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top row: Avatar + Balance pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GroupAvatar(
                              avatarUrl: cohort.avatarUrl ?? cohort.bannerUrl,
                              category: cohort.category,
                              customIcon: cohort.customIcon,
                              size: 40,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Bottom info: Name, members, archive tag
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cohort.name,
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
                              '${members.length} members',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                            if (cohort.isArchived) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accentPill,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: colors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Archived (Muted)',
                                  style: TextStyle(
                                    fontSize: 9,
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
                );
              },
            ),
          ),
      ],
    );
  }
}
