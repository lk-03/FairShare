import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/friend.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/friends_provider.dart';

class FriendsPickerModal extends ConsumerStatefulWidget {
  final List<Friend> initiallySelected;
  final ValueChanged<List<Friend>> onSelectionChanged;

  const FriendsPickerModal({
    super.key,
    this.initiallySelected = const [],
    required this.onSelectionChanged,
  });

  static Future<List<Friend>?> show(
    BuildContext context, {
    List<Friend> initiallySelected = const [],
  }) {
    List<Friend> selected = List.from(initiallySelected);
    return showModalBottomSheet<List<Friend>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FriendsPickerModal(
          initiallySelected: selected,
          onSelectionChanged: (updated) {
            selected = updated;
          },
        );
      },
    );
  }

  @override
  ConsumerState<FriendsPickerModal> createState() => _FriendsPickerModalState();
}

class _FriendsPickerModalState extends ConsumerState<FriendsPickerModal> {
  late List<Friend> _selected;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initiallySelected);
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
      final exists = _selected.any((f) => f.id == friend.id);
      if (exists) {
        _selected.removeWhere((f) => f.id == friend.id);
      } else {
        _selected.add(friend);
      }
      widget.onSelectionChanged(_selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final friendsAsync = ref.watch(friendsProvider);
    final allFriends = friendsAsync.value ?? [];

    final filtered = allFriends.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.displayName.toLowerCase().contains(_searchQuery) ||
          (f.username?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 580),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Friends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textMain,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(
                    'Done (${_selected.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: colors.textMain, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary, size: 18),
                filled: true,
                fillColor: colors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      allFriends.isEmpty ? 'No friends added yet' : 'No matching friends',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final friend = filtered[index];
                      final isSelected = _selected.any((f) => f.id == friend.id);

                      return InkWell(
                        onTap: () => _toggleFriend(friend),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.cyan.withValues(alpha: 0.1)
                                : colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colors.cyan.withValues(alpha: 0.4)
                                  : colors.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                avatarUrl: friend.avatarUrl,
                                name: friend.displayName,
                                radius: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  friend.displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: colors.textMain,
                                  ),
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? colors.cyan : colors.textSecondary,
                                size: 20,
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
    );
  }
}
