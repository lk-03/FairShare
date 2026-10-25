import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../data/providers/groups_provider.dart';

class EditGroupSheet extends ConsumerStatefulWidget {
  final Group group;
  final VoidCallback? onDeleted;

  const EditGroupSheet({
    super.key,
    required this.group,
    this.onDeleted,
  });

  static Future<void> show(BuildContext context, Group group, {VoidCallback? onDeleted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditGroupSheet(group: group, onDeleted: onDeleted),
    );
  }

  @override
  ConsumerState<EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<EditGroupSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late String _category;
  late String _currency;
  bool _isLoading = false;

  final List<String> _categories = [
    'trip',
    'house',
    'dining',
    'event',
    'transport',
    'utilities',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descController = TextEditingController(text: widget.group.description);
    _category = widget.group.category;
    _currency = widget.group.currency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group name cannot be empty'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(groupsProvider.notifier).updateGroup(widget.group.id, {
        'name': name,
        'description': _descController.text.trim(),
        'category': _category,
        'currency': _currency,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update group: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleToggleArchive() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(groupsProvider.notifier).toggleArchiveGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.group.isArchived ? 'Group unarchived' : 'Group archived'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: Text('Are you sure you want to move "${widget.group.name}" to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(groupsProvider.notifier).deleteGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDeleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${widget.group.name}" deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.88,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        mediaQuery.viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Group',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: colors.textMain,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Group Name
            Text(
              'GROUP NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textMain),
              decoration: InputDecoration(
                hintText: 'e.g. Bangalore Roadtrip',
                hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: colors.accentPill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.cyan, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector
            Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _category.toLowerCase() == cat.toLowerCase();
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CategoryIcon(
                        category: cat,
                        size: 20,
                        variant: isSelected
                            ? CategoryIconVariant.solid
                            : CategoryIconVariant.light,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat[0].toUpperCase() + cat.substring(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: colors.cyan,
                  backgroundColor: colors.accentPill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? colors.cyan : colors.border,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) setState(() => _category = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save Changes Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.cyan,
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Archive / Unarchive Button
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleToggleArchive,
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.accentPill,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  widget.group.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  size: 18,
                  color: colors.textSecondary,
                ),
                label: Text(
                  widget.group.isArchived ? 'Unarchive Group' : 'Archive Group',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Delete Group Button
            SizedBox(
              height: 44,
              child: TextButton.icon(
                onPressed: _isLoading ? null : _handleDelete,
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.crimson),
                label: Text(
                  'Delete Group',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.crimson,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
