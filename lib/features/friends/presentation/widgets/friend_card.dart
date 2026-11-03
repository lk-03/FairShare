import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/friend.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/friends_provider.dart';

class FriendCard extends ConsumerWidget {
  final Friend friend;
  final VoidCallback? onTap;

  const FriendCard({
    super.key,
    required this.friend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final balance = ref.watch(friendBalanceProvider(friend));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            UserAvatar(
              avatarUrl: friend.avatarUrl,
              name: friend.displayName,
              radius: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          friend.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (friend.isLocal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Local',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: colors.amber,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend.username != null && friend.username!.isNotEmpty
                        ? '@${friend.username}'
                        : (friend.email ?? 'FairShare Friend'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildBalanceBadge(context, balance),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceBadge(BuildContext context, dynamic balance) {
    final colors = context.colors;

    if (balance.friendOwesUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'owes you',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.emerald,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.formatINR(balance.absoluteAmount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.emerald,
            ),
          ),
        ],
      );
    } else if (balance.userOwesFriend) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'you owe',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.amber,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.formatINR(balance.absoluteAmount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.amber,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Settled',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
