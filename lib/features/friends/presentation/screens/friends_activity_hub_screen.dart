import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/friend.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/friends_provider.dart';
import '../../../activity/presentation/screens/activity_screen.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/friend_card.dart';

class FriendsActivityHubScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const FriendsActivityHubScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<FriendsActivityHubScreen> createState() => _FriendsActivityHubScreenState();
}

class _FriendsActivityHubScreenState extends ConsumerState<FriendsActivityHubScreen> {
  late int _selectedTab;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleAddFriend() {
    AddFriendSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: colors.screen,
      body: SafeArea(
        child: Column(
          children: [
            // Top Hub Header with Segmented Pill Selector
            _buildTopSegmentedHeader(colors, isDesktop),

            // Tab View Body
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildFriendsTab(colors, isDesktop),
                  const ActivityScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSegmentedHeader(dynamic colors, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, isDesktop ? 20 : 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.screen,
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Row(
            children: [
              Text(
                'Hub',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: colors.textMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 20),

              // Scandinavian Segmented Pill Switcher
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSegmentButton(
                          label: 'Friends',
                          icon: Icons.people_alt_rounded,
                          isSelected: _selectedTab == 0,
                          colors: colors,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildSegmentButton(
                          label: 'Activity',
                          icon: Icons.history_rounded,
                          isSelected: _selectedTab == 1,
                          colors: colors,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedTab == 0) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _handleAddFriend,
                  icon: Icon(Icons.person_add_alt_1_rounded, color: colors.cyan),
                  tooltip: 'Add Friend',
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: colors.borderSubtle),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required dynamic colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? colors.cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(dynamic colors, bool isDesktop) {
    final friendsAsync = ref.watch(friendsProvider);
    final aggregateBalance = ref.watch(friendsAggregateBalanceProvider);

    return RefreshIndicator(
      color: colors.cyan,
      onRefresh: () async {
        ref.invalidate(friendsProvider);
      },
      child: friendsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.rose),
                const SizedBox(height: 12),
                Text(
                  'Failed to load friends',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(friendsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.cyan,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (allFriends) {
          final currentUser = ref.watch(currentUserProvider);
          final myId = currentUser?.id ?? '';

          final acceptedFriends = allFriends.where((f) => f.isAccepted || f.isLocal).toList();
          final incomingRequests = allFriends.where((f) => f.isIncoming(myId)).toList();
          final outgoingRequests = allFriends.where((f) => f.isOutgoing(myId)).toList();

          final filteredFriends = acceptedFriends.where((friend) {
            if (_searchQuery.isEmpty) return true;
            final nameMatch = friend.displayName.toLowerCase().contains(_searchQuery);
            final emailMatch = (friend.email ?? '').toLowerCase().contains(_searchQuery);
            final userMatch = (friend.username ?? '').toLowerCase().contains(_searchQuery);
            return nameMatch || emailMatch || userMatch;
          }).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Aggregate Balance Banner
                          _buildAggregateBanner(aggregateBalance, colors),

                          const SizedBox(height: 16),

                          // Search Bar
                          _buildSearchBar(colors),

                          const SizedBox(height: 16),

                          // Incoming Friend Requests
                          if (incomingRequests.isNotEmpty)
                            _buildIncomingRequestsSection(incomingRequests, colors),

                          // Outgoing Sent Requests
                          if (outgoingRequests.isNotEmpty)
                            _buildOutgoingRequestsSection(outgoingRequests, colors),

                          // Header count & Add CTA
                          Row(
                            children: [
                              Text(
                                'All Friends (${filteredFriends.length})',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMain,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _handleAddFriend,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Friend'),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.cyan,
                                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (filteredFriends.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: 32,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No friends yet' : 'No friends match "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Add people via search or add local offline contacts to split bills 1-on-1.'
                              : 'Try a different name, email, or handle.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: colors.textSecondary),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _handleAddFriend,
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Add Your First Friend'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.cyan,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final friend = filteredFriends[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: FriendCard(
                              friend: friend,
                              onTap: () => context.push('/friends/${friend.id}'),
                            ),
                          ),
                        );
                      },
                      childCount: filteredFriends.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAggregateBanner(({double net, double youAreOwed, double youOwe}) aggregate, dynamic colors) {
    final net = aggregate.net;
    final owedToYou = aggregate.youAreOwed;
    final youOwe = aggregate.youOwe;

    final isPositive = net > 0.01;
    final isNegative = net < -0.01;
    final isSettled = !isPositive && !isNegative;

    final Color statusColor = isPositive
        ? AppColors.emerald
        : (isNegative ? AppColors.rose : colors.cyan);

    final String statusTitle = isPositive
        ? 'Total friends owe you'
        : (isNegative ? 'Total you owe friends' : 'All 1-on-1 balances settled');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 16, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'PERSONAL 1-ON-1 LEDGER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSettled
                        ? '₹0.00'
                        : CurrencyFormatter.formatINR(net.abs()),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (owedToYou > 0 || youOwe > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (owedToYou > 0)
                      Text(
                        '+${CurrencyFormatter.formatINR(owedToYou)} owed to you',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                        ),
                      ),
                    if (youOwe > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '-${CurrencyFormatter.formatINR(youOwe)} you owe',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.rose,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(dynamic colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 14, color: colors.textMain),
        decoration: InputDecoration(
          hintText: 'Search friends by name or handle...',
          hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildIncomingRequestsSection(List<Friend> requests, dynamic colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add_alt_1_rounded, size: 16, color: colors.cyan),
              ),
              const SizedBox(width: 8),
              Text(
                'Friend Requests (${requests.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (_, _) => Divider(
              color: colors.borderSubtle,
              height: 16,
            ),
            itemBuilder: (ctx, index) {
              final req = requests[index];
              return Row(
                children: [
                  UserAvatar(
                    avatarUrl: req.avatarUrl,
                    name: req.displayName,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          req.username != null && req.username!.isNotEmpty
                              ? '@${req.username}'
                              : 'FairShare User',
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
                  ElevatedButton(
                    onPressed: () => ref.read(friendsProvider.notifier).acceptRequest(req.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cyan,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => ref.read(friendsProvider.notifier).declineRequest(req.id),
                    icon: Icon(Icons.close_rounded, size: 18, color: colors.textSecondary),
                    tooltip: 'Decline',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestsSection(List<Friend> requests, dynamic colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: colors.amber),
              const SizedBox(width: 8),
              Text(
                'Sent Requests Pending (${requests.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...requests.map((req) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: req.avatarUrl,
                    name: req.displayName,
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      req.displayName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textMain),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(friendsProvider.notifier).cancelRequest(req.id),
                    style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
