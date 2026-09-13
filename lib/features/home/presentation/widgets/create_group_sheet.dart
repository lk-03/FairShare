import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  final ValueChanged<Group>? onGroupCreated;

  const CreateGroupSheet({
    super.key,
    this.onGroupCreated,
  });

  static Future<Group?> show(BuildContext context) {
    return showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateGroupSheet(),
    );
  }

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'house';
  final String _currency = 'INR';
  bool _isCreating = false;
  String? _error;

  final List<({String key, String label})> _categories = [
    (key: 'house', label: 'House / Roommates'),
    (key: 'trip', label: 'Trip / Travel'),
    (key: 'event', label: 'Event'),
    (key: 'dining', label: 'Dining'),
    (key: 'transport', label: 'Transport'),
    (key: 'utilities', label: 'Utilities'),
    (key: 'custom', label: 'Custom'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _generateInviteCode(String groupName) {
    final clean = groupName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final prefix = clean.length >= 3 ? clean.substring(0, 3) : (clean.isNotEmpty ? clean : 'FS');
    final randomSuffix = (100 + Random().nextInt(900)).toString();
    return '$prefix$randomSuffix';
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a group name');
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      setState(() => _error = 'Please sign in to create a group');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final inviteCode = _generateInviteCode(name);
      final newGroup = Group(
        id: 'cohort_${now.millisecondsSinceEpoch}',
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        category: _selectedCategory,
        currency: _currency,
        createdBy: currentUser.id,
        inviteCode: inviteCode,
        createdAt: now,
        updatedAt: now,
      );

      final created = await ref.read(groupsProvider.notifier).createGroup(newGroup);
      if (mounted) {
        widget.onGroupCreated?.call(created);
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Group',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set up a shared ledger with friends or roommates',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Group Name Input
            Text(
              'GROUP NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.cyan,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(fontSize: 15, color: colors.textMain),
              decoration: InputDecoration(
                hintText: 'e.g., Flat 402, Goa Trip 2026',
                hintStyle: TextStyle(fontSize: 14, color: colors.textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: colors.accentPill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.cyan, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            Text(
              'DESCRIPTION (OPTIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.cyan,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              style: TextStyle(fontSize: 14, color: colors.textMain),
              decoration: InputDecoration(
                hintText: 'e.g., Monthly groceries & Wi-Fi bills',
                hintStyle: TextStyle(fontSize: 14, color: colors.textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: colors.accentPill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.cyan, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Category Picker
            Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.cyan,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.key;
                return InkWell(
                  onTap: () => setState(() => _selectedCategory = cat.key),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.cyan.withValues(alpha: 0.15)
                          : colors.accentPill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? colors.cyan : colors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryIcon(
                          category: cat.key,
                          size: 24,
                          variant: isSelected
                              ? CategoryIconVariant.solid
                              : CategoryIconVariant.light,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? colors.cyan : colors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton(
              onPressed: _isCreating ? null : _handleCreate,
              style: FilledButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Create Group',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.screen,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
