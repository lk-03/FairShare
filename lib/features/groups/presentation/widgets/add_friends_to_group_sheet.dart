import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/friend.dart';
import '../../../../core/models/group.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/friends_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class AddFriendsToGroupSheet extends ConsumerStatefulWidget {
  final Group group;

  const AddFriendsToGroupSheet({
    super.key,
    required this.group,
  });

  static Future<void> show(
    BuildContext context, {
    required Group group,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddFriendsToGroupSheet(group: group),
    );
  }

  @override
  ConsumerState<AddFriendsToGroupSheet> createState() => _AddFriendsToGroupSheetState();
}

class _AddFriendsToGroupSheetState extends ConsumerState<AddFriendsToGroupSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFriendIds = {};
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
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

  void _toggleFriend(Friend friend) {
    setState(() {
      if (_selectedFriendIds.contains(friend.id)) {
        _selectedFriendIds.remove(friend.id);
      } else {
        _selectedFriendIds.add(friend.id);
      }
    });
  }

  Future<void> _handleAddSelected(List<Friend> candidateFriends) async {
    final selectedFriends = candidateFriends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();

    if (selectedFriends.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(groupsProvider.notifier)
          .addFriendsToGroup(widget.group.id, selectedFriends);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${selectedFriends.length} friend${selectedFriends.length == 1 ? '' : 's'} to ${widget.group.name}',
          ),
          backgroundColor: AppColors.primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add friends: $e'),
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final allAccepted = ref.watch(acceptedFriendsProvider);

    // Existing member user IDs
    final existingMemberIds = widget.group.members.map((m) => m.userId).toSet();

    // Available friends who aren't yet in this group
    final availableFriends = allAccepted.where((f) {
      return !existingMemberIds.contains(f.friendUserId);
    }).toList();

    // Filter by search query
    final filtered = availableFriends.where((f) {
      if (_searchQuery.isEmpty) return true;
      final name = f.displayName.toLowerCase();
      final username = (f.username ?? '').toLowerCase();
      return name.contains(_searchQuery) || username.contains(_searchQuery);
    }).toList();

    final mediaQuery = MediaQuery.of(context);
    final maxHeight = (mediaQuery.size.height - mediaQuery.padding.top) * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Friends to Group',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add mutual friends into "${widget.group.name}"',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Search Bar
          if (availableFriends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.cyan),
                  ),
                ),
                style: TextStyle(color: colors.textMain, fontSize: 14),
              ),
            ),

          const SizedBox(height: 4),

          // List of Friends or Empty State
          Expanded(
            child: availableFriends.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 48,
                            color: colors.textSecondary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            allAccepted.isEmpty
                                ? 'No friends added yet'
                                : 'All your friends are already in this group!',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textMain,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            allAccepted.isEmpty
                                ? 'Add mutual friends in the Friends tab to quickly invite them to groups.'
                                : 'Invite new people using your group invite code or QR code.',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No friends match "$_searchQuery"',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final friend = filtered[index];
                          final isSelected = _selectedFriendIds.contains(friend.id);

                          return InkWell(
                            onTap: () => _toggleFriend(friend),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.cyan.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? colors.cyan : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    avatarUrl: friend.avatarUrl,
                                    name: friend.displayName,
                                    radius: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.displayName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textMain,
                                          ),
                                        ),
                                        if (friend.username != null && friend.username!.isNotEmpty)
                                          Text(
                                            '@${friend.username}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleFriend(friend),
                                    activeColor: colors.cyan,
                                    checkColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Action Button
          if (availableFriends.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.borderSubtle),
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selectedFriendIds.isEmpty || _isSubmitting
                        ? null
                        : () => _handleAddSelected(availableFriends),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cyan,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: colors.borderSubtle,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _selectedFriendIds.isEmpty
                                ? 'Select Friends to Add'
                                : 'Add ${_selectedFriendIds.length} Friend${_selectedFriendIds.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
