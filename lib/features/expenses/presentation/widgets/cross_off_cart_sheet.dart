import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/models/need_item.dart';

/// Modal bottom sheet prompting the user to cross off matching House Cart items
/// when adding or saving an expense.
class CrossOffCartSheet extends StatefulWidget {
  final List<NeedItem> matchedItems;
  final List<GroupMember> members;
  final String currentUserId;

  const CrossOffCartSheet({
    super.key,
    required this.matchedItems,
    required this.members,
    required this.currentUserId,
  });

  /// Displays the sheet and returns the set of NeedItem IDs that the user chose
  /// to cross off. Returns empty set if the user chose to keep all items in cart.
  static Future<Set<String>> show(
    BuildContext context, {
    required List<NeedItem> matchedItems,
    required List<GroupMember> members,
    required String currentUserId,
  }) async {
    if (matchedItems.isEmpty) return <String>{};

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrossOffCartSheet(
        matchedItems: matchedItems,
        members: members,
        currentUserId: currentUserId,
      ),
    );

    return result ?? <String>{};
  }

  @override
  State<CrossOffCartSheet> createState() => _CrossOffCartSheetState();
}

class _CrossOffCartSheetState extends State<CrossOffCartSheet> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    // Default: all matched items checked
    _selectedIds = widget.matchedItems.map((i) => i.id).toSet();
  }

  String _getAuthorName(NeedItem item) {
    if (item.addedByUserId.isNotEmpty && item.addedByUserId == widget.currentUserId) {
      return 'You';
    }
    if (item.addedByName != null && item.addedByName!.trim().isNotEmpty) {
      return item.addedByName!;
    }
    for (final m in widget.members) {
      if (m.userId == item.addedByUserId) {
        return m.displayName;
      }
    }
    return 'Someone';
  }

  @override
  Widget build(BuildContext context) {
    final isSingleItem = widget.matchedItems.length == 1;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderFocus,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Icon & Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: AppColors.primaryTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'House Cart Match',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSingleItem
                            ? 'Cross this off from the cart?'
                            : 'Found ${widget.matchedItems.length} matching cart items:',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (isSingleItem) ...[
              // Single item card view
              _buildSingleItemCard(widget.matchedItems.first),
            ] else ...[
              // Multiple items list
              _buildMultiItemList(),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                // Secondary "Keep in Cart"
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <String>{}),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Keep in Cart',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Primary "Cross Off & Save"
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _selectedIds);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isSingleItem
                          ? 'Cross Off & Save'
                          : 'Cross Off (${_selectedIds.length}) & Save',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleItemCard(NeedItem item) {
    final authorName = _getAuthorName(item);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Cart Item',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$authorName added this to the group house cart. Mark it as completed now?',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiItemList() {
    return Material(
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.matchedItems.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.borderSubtle,
        ),
        itemBuilder: (context, index) {
          final item = widget.matchedItems[index];
          final authorName = _getAuthorName(item);
          final isChecked = _selectedIds.contains(item.id);

          return CheckboxListTile(
            value: isChecked,
            activeColor: AppColors.primaryTeal,
            checkColor: Colors.black,
            title: Text(
              item.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isChecked ? AppColors.textPrimary : AppColors.textMuted,
                decoration: isChecked ? TextDecoration.none : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Text(
              'Added by $authorName',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.add(item.id);
                } else {
                  _selectedIds.remove(item.id);
                }
              });
            },
          );
        },
      ),
      ),
    );
  }
}
