import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

enum EmptyStateVariant { card, inline }

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final EmptyStateVariant variant;

  const EmptyState({
    super.key,
    this.icon = Icons.account_balance_wallet_outlined,
    required this.title,
    required this.description,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.variant = EmptyStateVariant.card,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCard = variant == EmptyStateVariant.card;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon Pill
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.accentPill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 28,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textMain,
          ),
        ),
        const SizedBox(height: 6),

        // Description
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
            ),
          ),
        ),

        if (primaryActionLabel != null || secondaryActionLabel != null) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                OutlinedButton(
                  onPressed: onSecondaryAction,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.accentPill,
                    side: BorderSide(color: colors.border, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    secondaryActionLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (primaryActionLabel != null) const SizedBox(width: 12),
              ],
              if (primaryActionLabel != null && onPrimaryAction != null)
                FilledButton(
                  onPressed: onPrimaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.textMain,
                    foregroundColor: colors.screen,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    primaryActionLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.screen,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    if (isCard) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}
