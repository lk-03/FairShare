import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/friends_provider.dart';

class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddFriendSheet(),
    );
  }

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _vpaController = TextEditingController();

  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _vpaController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final currentUser = ref.read(currentUserProvider);
      final repo = ref.read(friendRepositoryProvider);
      final results = await repo.searchProfiles(query, excludeUserId: currentUser?.id);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _handleAddCloudUser(UserProfile profile) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(friendsProvider.notifier).addFriend(
            friendUserId: profile.id,
            name: profile.fullName,
            username: profile.username,
            email: profile.email,
            phone: profile.phoneNumber,
            vpaId: profile.vpaId,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile.displayName} added as friend!'),
            backgroundColor: AppColors.primaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not add friend: $e';
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleSaveLocalContact() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name for your contact');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(friendsProvider.notifier).addFriend(
            name: name,
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            vpaId: _vpaController.text.trim().isNotEmpty
                ? _vpaController.text.trim()
                : null,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added to friends!'),
            backgroundColor: AppColors.primaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not save contact: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: const BoxConstraints(maxHeight: 640),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Friend',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Connect with FairShare users or add local contacts',
                        style: TextStyle(
                          fontSize: 12,
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
          ),
          const SizedBox(height: 12),

          // Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: colors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.cyan.withValues(alpha: 0.4)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: colors.cyan,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Search Users'),
                  Tab(text: 'Local Contact'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(context),
                _buildLocalContactTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: colors.textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by @username, email, or name...',
              hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary, size: 20),
              filled: true,
              fillColor: colors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.cyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.cyan),
                ),
              ),
            )
          else if (_searchResults.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search_rounded, size: 48, color: colors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      _searchController.text.trim().isEmpty
                          ? 'Type a username or email to search'
                          : 'No FairShare users found',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final profile = _searchResults[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          avatarUrl: profile.avatarUrl,
                          name: profile.displayName,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMain,
                                ),
                              ),
                              Text(
                                profile.username != null ? '@${profile.username}' : (profile.email ?? ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSaving ? null : () => _handleAddCloudUser(profile),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.cyan,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalContactTab(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.offline_bolt_rounded, size: 20, color: colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Local contacts are saved on your device. You can track expenses with them without requiring them to have an account.',
                    style: TextStyle(fontSize: 12, color: colors.textMain, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nameController,
            label: 'Name *',
            hint: 'e.g. Rahul Sharma',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _vpaController,
            label: 'UPI ID (Optional)',
            hint: 'e.g. rahul@okaxis',
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone (Optional)',
            hint: 'e.g. +91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSaveLocalContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'Save Contact',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: colors.textMain, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
            prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
            filled: true,
            fillColor: colors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.cyan, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
