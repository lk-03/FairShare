import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../core/widgets/group_avatar.dart';
import '../../../../core/widgets/theme_gradient_header.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../home/presentation/widgets/create_group_sheet.dart';
import '../../../home/presentation/widgets/join_group_sheet.dart';
import '../widgets/group_action_sheet.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _trashExpanded = false;
  bool _fabOpen = false;

  final List<({String id, String label, IconData icon})> _categoryFilters = const [
    (id: 'all', label: 'All', icon: Icons.grid_view_rounded),
    (id: 'house', label: 'House', icon: Icons.home_rounded),
    (id: 'trip', label: 'Trip', icon: Icons.flight_rounded),
    (id: 'dining', label: 'Dining', icon: Icons.restaurant_rounded),
    (id: 'event', label: 'Event', icon: Icons.event_rounded),
    (id: 'transport', label: 'Transport', icon: Icons.directions_car_rounded),
    (id: 'utilities', label: 'Utilities', icon: Icons.bolt_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ref.read(groupsProvider.notifier).loadUserGroups();
    final groups = ref.read(groupsProvider).value ?? [];
    for (final cohort in groups) {
      ref.read(groupExpensesProvider(cohort.id).notifier).loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(groupsProvider);
    final allGroups = groupsAsync.value ?? [];

    final activeCohorts = allGroups.where((g) => !g.isDeleted).toList();
    final deletedCohorts = allGroups.where((g) => g.isDeleted).toList();

    // Filter active cohorts
    final filteredActive = activeCohorts.where((c) {
      final matchesCategory = _selectedCategory == 'all' ||
          c.category.toLowerCase() == _selectedCategory.toLowerCase();
      final q = _searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          (c.description != null && c.description!.toLowerCase().contains(q));
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: colors.screen,
      body: Stack(
        children: [
          // Main Scrollable Content
          RefreshIndicator(
            onRefresh: _loadData,
            color: colors.cyan,
            backgroundColor: colors.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Gradient Header
                SliverToBoxAdapter(
                  child: ThemeGradientHeader(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Groups',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: colors.textMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentPill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text(
                                '${activeCohorts.length} Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EVENT COHORTS & SHARED LEDGERS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textMain,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search groups by name...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary.withValues(alpha: 0.7),
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: colors.textSecondary,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: colors.textSecondary,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category Chips
                        SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categoryFilters.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final cat = _categoryFilters[idx];
                              final isSelected = _selectedCategory == cat.id;

                              return InkWell(
                                onTap: () => setState(() => _selectedCategory = cat.id),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.cyan.withValues(alpha: 0.18)
                                        : colors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? colors.cyan : colors.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        cat.icon,
                                        size: 14,
                                        color: isSelected
                                            ? colors.cyan
                                            : colors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cat.label,
                                        style: TextStyle(
                                          fontSize: 11,
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
                      ],
                    ),
                  ),
                ),

                // Active Groups Section
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (filteredActive.isEmpty)
                        _buildEmptyState(context, colors)
                      else ...[
                        ...filteredActive.map((cohort) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _GroupCard(
                                cohort: cohort,
                                onTap: () => context.push('/groups/${cohort.id}'),
                                onLongPress: () =>
                                    GroupActionSheet.show(context, cohort),
                              ),
                            )),
                      ],

                      // Trash / Scheduled Deletion Section
                      if (deletedCohorts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTrashSection(context, colors, isDark, deletedCohorts),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Speed-Dial Backdrop Overlay
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _fabOpen = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),

          // Speed-Dial Action Options
          if (_fabOpen)
            Positioned(
              right: 20,
              bottom: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Join Group Option
                  _buildSpeedDialItem(
                    label: 'Join Group',
                    icon: Icons.login_rounded,
                    iconColor: colors.cyan,
                    iconBg: colors.cyan.withValues(alpha: 0.18),
                    borderColor: colors.cyan.withValues(alpha: 0.35),
                    onTap: () {
                      setState(() => _fabOpen = false);
                      JoinGroupSheet.show(
                        context,
                        onScanQr: () => context.push('/scan'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // New Event Cohort Option
                  _buildSpeedDialItem(
                    label: 'New Event Cohort',
                    icon: Icons.add_rounded,
                    iconColor: colors.emerald,
                    iconBg: colors.emerald.withValues(alpha: 0.18),
                    borderColor: colors.emerald.withValues(alpha: 0.35),
                    onTap: () {
                      setState(() => _fabOpen = false);
                      CreateGroupSheet.show(context);
                    },
                  ),
                ],
              ),
            ),

          // Main Bottom-Right FAB Button
          Positioned(
            right: 20,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'groups_fab',
              backgroundColor: _fabOpen ? colors.surface : colors.cyan,
              foregroundColor: _fabOpen ? colors.textSecondary : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: _fabOpen ? colors.border : colors.cyan,
                  width: 1.5,
                ),
              ),
              onPressed: () => setState(() => _fabOpen = !_fabOpen),
              child: Icon(
                _fabOpen ? Icons.close_rounded : Icons.add_rounded,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.border,
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.accentPill,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 30,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No Matching Groups'
                : 'No Active Groups',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'No groups match your current search or category filter.'
                : 'Create a new group or join one with an invite code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.cyan,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'New Group',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => CreateGroupSheet.show(context),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.cyan,
                    side: BorderSide(color: colors.cyan),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text(
                    'Join with Code',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => JoinGroupSheet.show(
                    context,
                    onScanQr: () => context.push('/scan'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpeedDialItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.textMain,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashSection(
    BuildContext context,
    dynamic colors,
    bool isDark,
    List<Group> deletedCohorts,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accordion Header
          InkWell(
            onTap: () => setState(() => _trashExpanded = !_trashExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TRASH / SCHEDULED FOR DELETION (${deletedCohorts.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _trashExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Groups stay in Trash for 15 days before permanent database deletion.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),

          // Expanded Content
          if (_trashExpanded) ...[
            const SizedBox(height: 14),
            ...deletedCohorts.map((cohort) {
              final deletedAtTime = cohort.deletedAt ?? DateTime.now();
              final daysElapsed =
                  DateTime.now().difference(deletedAtTime).inDays;
              final daysRemaining = max(1, 15 - daysElapsed);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GroupAvatar(
                          avatarUrl: cohort.avatarUrl ?? cohort.bannerUrl,
                          category: cohort.category,
                          customIcon: cohort.customIcon,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cohort.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'Deletes in $daysRemaining day${daysRemaining == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.cyan,
                              side: BorderSide(
                                color: colors.cyan.withValues(alpha: 0.35),
                              ),
                              backgroundColor:
                                  colors.cyan.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 15),
                            label: const Text(
                              'Restore',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () async {
                              await ref
                                  .read(groupsProvider.notifier)
                                  .restoreGroup(cohort.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '"${cohort.name}" has been restored to active groups.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.red,
                            side: BorderSide(
                              color: colors.red.withValues(alpha: 0.35),
                            ),
                            backgroundColor:
                                colors.red.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            'Delete Now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _confirmPermanentDelete(
                            context,
                            ref,
                            cohort,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _confirmPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    Group cohort,
  ) {
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
            'Delete Permanently',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.textMain,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete "${cohort.name}" and all its records now? This action cannot be undone.',
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
                'Delete Forever',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        await ref
            .read(groupsProvider.notifier)
            .deleteGroupPermanently(cohort.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"${cohort.name}" has been permanently removed.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }
}

class _GroupCard extends ConsumerWidget {
  final Group cohort;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GroupCard({
    required this.cohort,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentUser = ref.watch(currentUserProvider);
    final userBal = ref.watch(userNetBalanceProvider(cohort.id));
    final members = ref.watch(groupMembersProvider(cohort.id));

    final isPositive = userBal > 0.01;
    final isNegative = userBal < -0.01;

    Color badgeBg = colors.accentPill;
    Color badgeTextColor = colors.textSecondary;
    String badgeText = '₹0.00';

    if (isPositive) {
      badgeBg = colors.emerald.withValues(alpha: 0.15);
      badgeTextColor = colors.emerald;
      badgeText = '+₹${userBal.toStringAsFixed(2)}';
    } else if (isNegative) {
      badgeBg = colors.red.withValues(alpha: 0.15);
      badgeTextColor = colors.red;
      badgeText = '-₹${userBal.abs().toStringAsFixed(2)}';
    }

    // Format member display string
    final memberNames = members
        .map((m) {
          if (m.userId == currentUser?.id) return 'You';
          return m.profile?.displayName ?? 'Member';
        })
        .where((name) => name.isNotEmpty)
        .toList();

    String memberDisplay = '1 active member';
    if (memberNames.length == 1) {
      memberDisplay = memberNames[0];
    } else if (memberNames.length == 2) {
      memberDisplay = '${memberNames[0]} & ${memberNames[1]}';
    } else if (memberNames.length == 3) {
      memberDisplay = '${memberNames[0]}, ${memberNames[1]} & ${memberNames[2]}';
    } else if (memberNames.length > 3) {
      memberDisplay =
          '${memberNames[0]}, ${memberNames[1]} & ${memberNames.length - 2} others';
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GroupAvatar(
              avatarUrl: cohort.avatarUrl ?? cohort.bannerUrl,
              category: cohort.category,
              customIcon: cohort.customIcon,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: Name + Archived pill + Net balance badge
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                cohort.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (cohort.isArchived) ...[
                              const SizedBox(width: 6),
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: colors.cyan,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Line 2: Optional description
                  if (cohort.description != null &&
                      cohort.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      cohort.description!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Line 3: Members string
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 13,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          memberDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
