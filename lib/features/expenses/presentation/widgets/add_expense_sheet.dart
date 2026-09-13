import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/models/split.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  final String cohortId;
  final Expense? existingExpense;

  const AddExpenseSheet({
    super.key,
    required this.cohortId,
    this.existingExpense,
  });

  static Future<Expense?> show(
    BuildContext context, {
    required String cohortId,
    Expense? existingExpense,
  }) {
    return showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(
        cohortId: cohortId,
        existingExpense: existingExpense,
      ),
    );
  }

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late String _category;
  late String _paidByUserId;
  late String _splitType; // 'equal', 'exact', 'percentage', 'shares'
  final Set<String> _includedMemberIds = {};
  final Map<String, TextEditingController> _exactControllers = {};
  final Map<String, TextEditingController> _percentControllers = {};
  final Map<String, int> _shares = {};

  bool _isLoading = false;

  final List<String> _categories = [
    'dining',
    'house',
    'transport',
    'trip',
    'utilities',
    'event',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    final exp = widget.existingExpense;
    _titleController = TextEditingController(text: exp?.title ?? '');
    _amountController = TextEditingController(
      text: exp != null ? exp.totalAmount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: exp?.notes ?? '');
    _category = exp?.category ?? 'dining';
    _splitType = exp?.splitType.name ?? 'equal';

    final currentUser = ref.read(currentUserProvider);
    _paidByUserId = exp?.paidByUserId ?? (currentUser?.id ?? '');

    // Initialize splits from existing expense if available
    if (exp != null && exp.splits.isNotEmpty) {
      for (final s in exp.splits) {
        _includedMemberIds.add(s.userId);
        _exactControllers[s.userId] = TextEditingController(
          text: s.amount.toStringAsFixed(2),
        );
        if (s.percentage != null) {
          _percentControllers[s.userId] = TextEditingController(
            text: s.percentage!.toStringAsFixed(1),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(List<GroupMember> members) {
    for (final m in members) {
      if (!_exactControllers.containsKey(m.userId)) {
        _exactControllers[m.userId] = TextEditingController();
      }
      if (!_percentControllers.containsKey(m.userId)) {
        _percentControllers[m.userId] = TextEditingController();
      }
      _shares.putIfAbsent(m.userId, () => 1);
    }
    if (_includedMemberIds.isEmpty && widget.existingExpense == null) {
      _includedMemberIds.addAll(members.map((m) => m.userId));
    }
  }

  double get _totalAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  List<ExpenseSplit>? _calculateSplits(List<GroupMember> members) {
    final total = _totalAmount;
    if (total <= 0) return null;

    if (_splitType == 'equal') {
      final activeIds = _includedMemberIds.toList();
      if (activeIds.isEmpty) return null;

      final count = activeIds.length;
      final baseShare = (total / count * 100).floor() / 100;
      final remainder = double.parse((total - (baseShare * count)).toStringAsFixed(2));

      return activeIds.asMap().entries.map((entry) {
        final idx = entry.key;
        final uId = entry.value;
        final amt = idx == 0
            ? double.parse((baseShare + remainder).toStringAsFixed(2))
            : baseShare;
        return ExpenseSplit(userId: uId, amount: amt);
      }).toList();
    } else if (_splitType == 'exact') {
      double sum = 0.0;
      final splits = <ExpenseSplit>[];

      for (final m in members) {
        final text = _exactControllers[m.userId]?.text.trim() ?? '0';
        final amt = double.tryParse(text) ?? 0.0;
        sum += amt;
        if (amt > 0) {
          splits.add(ExpenseSplit(userId: m.userId, amount: amt));
        }
      }

      if ((sum - total).abs() > 0.05) {
        final diff = sum - total;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              diff > 0
                  ? 'Split sum exceeds total by ${CurrencyFormatter.formatINR(diff)}'
                  : 'Split sum is under total by ${CurrencyFormatter.formatINR(diff.abs())}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
      return splits;
    } else if (_splitType == 'percentage') {
      double totalPct = 0.0;
      final splits = <ExpenseSplit>[];

      for (final m in members) {
        final text = _percentControllers[m.userId]?.text.trim() ?? '0';
        final pct = double.tryParse(text) ?? 0.0;
        totalPct += pct;
        if (pct > 0) {
          final amt = double.parse(((pct / 100) * total).toStringAsFixed(2));
          splits.add(ExpenseSplit(userId: m.userId, amount: amt, percentage: pct));
        }
      }

      if ((totalPct - 100).abs() > 0.5) {
        final diff = totalPct - 100;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              diff > 0
                  ? 'Percentages sum to ${totalPct.toStringAsFixed(1)}% (+${diff.toStringAsFixed(1)}%). Must equal 100%.'
                  : 'Percentages sum to ${totalPct.toStringAsFixed(1)}% (-${diff.abs().toStringAsFixed(1)}%). Must equal 100%.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
      return splits;
    } else if (_splitType == 'shares') {
      int totalShares = 0;
      for (final m in members) {
        totalShares += _shares[m.userId] ?? 0;
      }
      if (totalShares <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please assign at least 1 share across members.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }

      final amountPerShare = total / totalShares;
      final splits = <ExpenseSplit>[];
      for (final m in members) {
        final s = _shares[m.userId] ?? 0;
        if (s > 0) {
          final amt = double.parse((s * amountPerShare).toStringAsFixed(2));
          splits.add(ExpenseSplit(userId: m.userId, amount: amt));
        }
      }
      return splits;
    }

    return null;
  }

  Future<void> _handleSave(List<GroupMember> members) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an expense title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final total = _totalAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than 0'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final splits = _calculateSplits(members);
    if (splits == null || splits.isEmpty) return;

    final payer = members.where((m) => m.userId == _paidByUserId).firstOrNull;
    final payerName = payer?.profile?.displayName ?? 'Member';

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final expense = Expense(
        id: widget.existingExpense?.id ?? 'exp_${now.millisecondsSinceEpoch}',
        cohortId: widget.cohortId,
        title: title,
        category: _category,
        totalAmount: total,
        currency: 'INR',
        paidByUserId: _paidByUserId,
        paidByName: payerName,
        splitType: SplitType.fromString(_splitType),
        splits: splits,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: widget.existingExpense?.createdAt ?? now,
        updatedAt: now,
      );

      final notifier = ref.read(groupExpensesProvider(widget.cohortId).notifier);
      if (widget.existingExpense != null) {
        await notifier.updateExpense(expense);
      } else {
        await notifier.addExpense(expense);
      }

      if (!mounted) return;
      Navigator.of(context).pop(expense);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingExpense != null
                ? 'Expense updated successfully'
                : 'Expense "$title" added',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save expense: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = ref.watch(groupMembersProvider(widget.cohortId));
    final currentUser = ref.watch(currentUserProvider);

    _ensureControllers(members);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingExpense != null ? 'Edit Expense' : 'Add Expense',
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
          ),
          const Divider(height: 1),

          // Scrollable Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Prominent Amount Input
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.accentPill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.cyan.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: colors.cyan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IntrinsicWidth(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: colors.textMain,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: colors.textSecondary.withValues(alpha: 0.4),
                                ),
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title Input
                  Text(
                    'EXPENSE TITLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Dinner, Groceries, Fuel',
                      hintStyle: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _category == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CategoryIcon(
                                  category: cat,
                                  size: 18,
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
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Paid By Selector
                  Text(
                    'PAID BY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.accentPill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _paidByUserId.isNotEmpty ? _paidByUserId : currentUser?.id,
                        isExpanded: true,
                        dropdownColor: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.cyan),
                        items: members.map((m) {
                          final isMe = m.userId == currentUser?.id;
                          final name = isMe
                              ? 'You (${m.profile?.displayName ?? 'You'})'
                              : m.profile?.displayName ?? 'Member';
                          return DropdownMenuItem<String>(
                            value: m.userId,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: colors.cyan.withValues(alpha: 0.2),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: colors.cyan,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textMain,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _paidByUserId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Split Mode Selector
                  Text(
                    'SPLIT METHOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.accentPill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        _buildSplitTab('equal', 'Equal (=)', colors),
                        _buildSplitTab('exact', 'Exact (₹)', colors),
                        _buildSplitTab('percentage', 'Percent (%)', colors),
                        _buildSplitTab('shares', 'Shares (x:y)', colors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Split Participant Customizer
                  _buildSplitCustomizer(members, colors),
                  const SizedBox(height: 16),

                  // Notes Input
                  Text(
                    'OPTIONAL NOTES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textMain,
                    ),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add invoice notes, bill items, etc.',
                      hintStyle: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _handleSave(members),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : Text(
                              widget.existingExpense != null
                                  ? 'Update Expense'
                                  : 'Save Expense',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTab(String mode, String label, AppThemeColors colors) {
    final isSelected = _splitType == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _splitType = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSelected ? const Color(0xFF0F172A) : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitCustomizer(List<GroupMember> members, AppThemeColors colors) {
    final currentUser = ref.read(currentUserProvider);

    if (_splitType == 'equal') {
      final activeCount = _includedMemberIds.length;
      final perPerson = activeCount > 0 ? _totalAmount / activeCount : 0.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PARTICIPANTS ($activeCount)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              if (_totalAmount > 0 && activeCount > 0)
                Text(
                  '${CurrencyFormatter.formatINR(perPerson)} / person',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colors.cyan,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...members.map((m) {
            final isIncluded = _includedMemberIds.contains(m.userId);
            final isMe = m.userId == currentUser?.id;
            final name = isMe ? 'You' : m.profile?.displayName ?? 'Member';

            return Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: isIncluded,
                activeColor: colors.cyan,
                checkColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textMain,
                  ),
                ),
                secondary: CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.accentPill,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.cyan,
                    ),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _includedMemberIds.add(m.userId);
                    } else {
                      if (_includedMemberIds.length > 1) {
                        _includedMemberIds.remove(m.userId);
                      }
                    }
                  });
                },
              ),
            );
          }),
        ],
      );
    } else if (_splitType == 'exact') {
      double sum = 0.0;
      for (final m in members) {
        sum += double.tryParse(_exactControllers[m.userId]?.text ?? '0') ?? 0.0;
      }
      final diff = _totalAmount - sum;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXACT AMOUNTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                diff.abs() < 0.01
                    ? '✓ Settled'
                    : (diff > 0
                        ? 'Remaining: ${CurrencyFormatter.formatINR(diff)}'
                        : 'Over: ${CurrencyFormatter.formatINR(diff.abs())}'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: diff.abs() < 0.01
                      ? colors.emerald
                      : (diff > 0 ? colors.amber : colors.crimson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...members.map((m) {
            final isMe = m.userId == currentUser?.id;
            final name = isMe ? 'You' : m.profile?.displayName ?? 'Member';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.accentPill,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textMain,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 40,
                    child: TextField(
                      controller: _exactControllers[m.userId],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: colors.cyan, fontWeight: FontWeight.w800),
                        hintText: '0.00',
                        filled: true,
                        fillColor: colors.accentPill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    } else if (_splitType == 'percentage') {
      double sumPct = 0.0;
      for (final m in members) {
        sumPct += double.tryParse(_percentControllers[m.userId]?.text ?? '0') ?? 0.0;
      }
      final diffPct = 100.0 - sumPct;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PERCENTAGES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                diffPct.abs() < 0.1
                    ? '✓ 100%'
                    : (diffPct > 0
                        ? 'Remaining: ${diffPct.toStringAsFixed(1)}%'
                        : 'Over: +${diffPct.abs().toStringAsFixed(1)}%'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: diffPct.abs() < 0.1
                      ? colors.emerald
                      : (diffPct > 0 ? colors.amber : colors.crimson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...members.map((m) {
            final isMe = m.userId == currentUser?.id;
            final name = isMe ? 'You' : m.profile?.displayName ?? 'Member';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.accentPill,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textMain,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    height: 40,
                    child: TextField(
                      controller: _percentControllers[m.userId],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        suffixText: '%',
                        suffixStyle: TextStyle(color: colors.cyan, fontWeight: FontWeight.w800),
                        hintText: '0',
                        filled: true,
                        fillColor: colors.accentPill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    } else {
      // Shares mode
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SHARES ALLOCATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...members.map((m) {
            final isMe = m.userId == currentUser?.id;
            final name = isMe ? 'You' : m.profile?.displayName ?? 'Member';
            final shareVal = _shares[m.userId] ?? 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.accentPill,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textMain,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: shareVal > 0
                            ? () => setState(() => _shares[m.userId] = shareVal - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                        color: colors.textSecondary,
                      ),
                      Text(
                        '$shareVal ${shareVal == 1 ? 'share' : 'shares'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _shares[m.userId] = shareVal + 1),
                        icon: Icon(Icons.add_circle_outline_rounded, size: 20, color: colors.cyan),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }
  }
}
