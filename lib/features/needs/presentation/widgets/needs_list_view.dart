import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/needs_provider.dart';
import 'needs_reminder_settings_sheet.dart';

class NeedsListView extends ConsumerStatefulWidget {
  final String cohortId;

  const NeedsListView({
    super.key,
    required this.cohortId,
  });

  @override
  ConsumerState<NeedsListView> createState() => _NeedsListViewState();
}

class _NeedsListViewState extends ConsumerState<NeedsListView> {
  final _newController = TextEditingController();
  String _filter = 'all'; // 'all' | 'pending' | 'bought'

  static const List<String> _creativeReminders = [
    'Check the list before Blinkiting, BigBasketing, or Instamarting!',
    'Don\'t double-order! Review house needs before checkout.',
    'Someone might have added eggs or milk—peek at the list first!',
    'Buying groceries? Tap off checked items to keep the house synced.',
    'Household Hero Alert: Check the Cart of the House list now!',
  ];

  late final String _selectedReminder;

  @override
  void initState() {
    super.initState();
    final idx = DateTime.now().millisecond % _creativeReminders.length;
    _selectedReminder = _creativeReminders[idx];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupNeedsProvider(widget.cohortId).notifier).loadNeeds();
    });
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _handleAddItem() async {
    final text = _newController.text.trim();
    if (text.isEmpty) return;

    _newController.clear();
    await ref
        .read(groupNeedsProvider(widget.cohortId).notifier)
        .addNeed(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentUser = ref.watch(currentUserProvider);
    final needsAsync = ref.watch(groupNeedsProvider(widget.cohortId));
    final allItems = needsAsync.value ?? [];

    final now = DateTime.now();

    // Filter out items checked > 5 days ago
    final validItems = allItems.where((item) {
      if (!item.isCompleted || item.completedAt == null) return true;
      return now.difference(item.completedAt!).inDays < 5;
    }).toList();

    // Apply UI filter ('all', 'pending', 'bought')
    final filteredItems = validItems.where((item) {
      if (_filter == 'pending') return !item.isCompleted;
      if (_filter == 'bought') return item.isCompleted;
      return true;
    }).toList();

    final pendingCount = validItems.where((i) => !i.isCompleted).length;
    final boughtCount = validItems.where((i) => i.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Creative Reminder Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.accentPill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: colors.cyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedReminder,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.textMain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () =>
                    NeedsReminderSettingsSheet.show(context, widget.cohortId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Quick-Add Bar
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: TextField(
                  controller: _newController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleAddItem(),
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add needed item (e.g. Milk, Bread)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary.withValues(alpha: 0.7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _handleAddItem,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.cyan,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  size: 26,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Filter Pills
        Row(
          children: [
            _buildFilterChip(
              label: 'All (${validItems.length})',
              id: 'all',
              colors: colors,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Pending ($pendingCount)',
              id: 'pending',
              colors: colors,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Bought ($boughtCount)',
              id: 'bought',
              colors: colors,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Items Checklist
        if (filteredItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 36,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: 10),
                Text(
                  _filter == 'all'
                      ? 'House cart is empty!'
                      : 'No $_filter items found.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add grocery items or household supplies above.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final item = filteredItems[idx];
              final isDone = item.isCompleted;
              final daysOld = now.difference(item.createdAt).inDays;
              final isStale = !isDone && daysOld >= 3;

              int expiryDaysLeft = 5;
              if (isDone && item.completedAt != null) {
                final elapsed = now.difference(item.completedAt!).inDays;
                expiryDaysLeft = (5 - elapsed).clamp(0, 5);
              }

              final isMine =
                  currentUser != null && item.addedByUserId == currentUser.id;
              final addedLabel = isMine
                  ? 'Added by You'
                  : item.addedByName != null
                      ? 'Added by ${item.addedByName}'
                      : 'Added ${daysOld}d ago';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDone
                      ? colors.surface.withValues(alpha: 0.6)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    InkWell(
                      onTap: () {
                        ref
                            .read(groupNeedsProvider(widget.cohortId).notifier)
                            .toggleNeed(item.id);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          isDone
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 24,
                          color: isDone
                              ? colors.emerald
                              : isStale
                                  ? const Color(0xFFF59E0B)
                                  : colors.textSecondary,
                        ),
                      ),
                    ),

                    // Title & Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDone
                                  ? colors.textSecondary
                                  : colors.textMain,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isStale
                                ? 'Added ${daysOld}d ago • Waiting to be bought'
                                : addedLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isStale
                                  ? const Color(0xFFF59E0B)
                                  : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badges
                    if (isStale) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${daysOld}d pending',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (isDone) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colors.red.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '${expiryDaysLeft}d left',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Delete Button
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colors.red.withValues(alpha: 0.8),
                      ),
                      onPressed: () {
                        ref
                            .read(groupNeedsProvider(widget.cohortId).notifier)
                            .deleteNeed(item.id);
                      },
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String id,
    required AppThemeColors colors,
  }) {
    final isSelected = _filter == id;
    return InkWell(
      onTap: () => setState(() => _filter = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.cyan.withValues(alpha: 0.18) : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.cyan : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? colors.cyan : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
