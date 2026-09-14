import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/expense_payer.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/models/split.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import 'adjust_split_sheet.dart';
import 'itemized_receipt_sheet.dart';
import 'payer_selection_sheet.dart';

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
      useSafeArea: true,
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
  List<ExpensePayer> _payers = [];
  late SplitType _splitType;
  List<ExpenseSplit> _splits = [];
  DateTime _selectedDate = DateTime.now();
  String? _receiptName;
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
      text: exp != null && exp.totalAmount > 0 ? exp.totalAmount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: exp?.notes ?? '');
    _category = exp?.category ?? 'dining';
    _splitType = exp?.splitType ?? SplitType.equal;
    _splits = exp?.splits ?? [];
    _payers = exp?.payers ?? [];
    _selectedDate = exp?.createdAt ?? DateTime.now();

    final currentUser = ref.read(currentUserProvider);
    _paidByUserId = exp?.paidByUserId ?? (currentUser?.id ?? '');

    if (_payers.isEmpty && _paidByUserId.isNotEmpty && exp != null) {
      _payers = [ExpensePayer(userId: _paidByUserId, amount: exp.totalAmount)];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  void _ensureSplits(List<GroupMember> members) {
    if (_splits.isEmpty && members.isNotEmpty && _totalAmount > 0) {
      final count = members.length;
      final base = (_totalAmount / count * 100).floor() / 100.0;
      final remainder = _totalAmount - (base * count);

      _splits = members.asMap().entries.map((entry) {
        final idx = entry.key;
        final m = entry.value;
        final amt = idx == 0 ? base + remainder : base;
        return ExpenseSplit(userId: m.userId, amount: amt);
      }).toList();
    }
  }

  Future<void> _openPayerSheet(List<GroupMember> members) async {
    final result = await PayerSelectionSheet.show(
      context,
      members: members,
      totalAmount: _totalAmount,
      initialPaidByUserId: _paidByUserId,
      initialPayers: _payers,
    );

    if (result != null) {
      setState(() {
        _paidByUserId = result.primaryPaidByUserId;
        _payers = result.payers;
      });
    }
  }

  Future<void> _openSplitSheet(List<GroupMember> members) async {
    _ensureSplits(members);
    final result = await AdjustSplitSheet.show(
      context,
      members: members,
      totalAmount: _totalAmount,
      initialSplitType: _splitType,
      initialSplits: _splits,
    );

    if (result != null) {
      setState(() {
        _splitType = result.splitType;
        _splits = result.splits;
      });
    }
  }

  Future<void> _openReceiptScanner() async {
    final parsed = await ItemizedReceiptSheet.show(context);
    if (parsed != null) {
      setState(() {
        if (_titleController.text.isEmpty) {
          _titleController.text = parsed.merchantName;
        }
        _amountController.text = parsed.totalAmount.toStringAsFixed(2);
        _category = _categories.contains(parsed.category) ? parsed.category : 'dining';
        _receiptName = '${parsed.merchantName}_receipt.jpg';
      });
    }
  }

  void _openCategoryPicker() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderFocus,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _categories.map((c) {
                  final isSelected = c == _category;
                  return InkWell(
                    onTap: () {
                      setState(() => _category = c);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryTeal.withValues(alpha: 0.15)
                            : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryTeal : AppColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryIcon(category: c, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            c[0].toUpperCase() + c.substring(1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppColors.primaryTeal : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDim,
        title: const Text('Add Notes', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: _notesController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter expense notes or details...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: AppColors.primaryTeal)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit(List<GroupMember> members) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description for the expense.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    final total = _totalAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    _ensureSplits(members);
    if (_splits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not determine expense splits.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    if (_payers.isEmpty) {
      _payers = [ExpensePayer(userId: _paidByUserId, amount: total)];
    }

    setState(() => _isLoading = true);

    try {
      final payerName = members
          .firstWhere(
            (m) => m.userId == _paidByUserId,
            orElse: () => GroupMember(
              id: _paidByUserId,
              cohortId: widget.cohortId,
              userId: _paidByUserId,
              originalCsvName: 'Someone',
              joinedAt: DateTime.now(),
            ),
          )
          .displayName;

      if (widget.existingExpense != null) {
        final updated = widget.existingExpense!.copyWith(
          title: title,
          category: _category,
          totalAmount: total,
          paidByUserId: _paidByUserId,
          payers: _payers,
          splitType: _splitType,
          splits: _splits,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          paidByName: payerName,
        );
        await ref.read(groupExpensesProvider(widget.cohortId).notifier).updateExpense(updated);
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        final newExpense = Expense(
          id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
          cohortId: widget.cohortId,
          title: title,
          category: _category,
          totalAmount: total,
          paidByUserId: _paidByUserId,
          payers: _payers,
          splitType: _splitType,
          splits: _splits,
          createdAt: _selectedDate,
          updatedAt: DateTime.now(),
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          paidByName: payerName,
          receiptUrl: _receiptName,
        );
        final saved = await ref.read(groupExpensesProvider(widget.cohortId).notifier).addExpense(newExpense);
        if (mounted) Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getPayerLabel(List<GroupMember> members, String currentUserId) {
    if (_payers.length > 1) {
      return '${_payers.length} people';
    }
    if (_paidByUserId == currentUserId) {
      return 'you';
    }
    final m = members.firstWhere(
      (mem) => mem.userId == _paidByUserId,
      orElse: () => GroupMember(
        id: _paidByUserId,
        cohortId: widget.cohortId,
        userId: _paidByUserId,
        originalCsvName: 'Someone',
        joinedAt: DateTime.now(),
      ),
    );
    return m.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(groupMembersProvider(widget.cohortId));
    final cohorts = ref.watch(groupsProvider).value ?? [];
    final currentCohort = cohorts.where((c) => c.id == widget.cohortId).firstOrNull;
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.id ?? '';

    _ensureSplits(members);
    final payerLabel = _getPayerLabel(members, currentUserId);
    final splitLabel = switch (_splitType) {
      SplitType.equal => 'equally',
      SplitType.exact => 'unequally',
      SplitType.percentage => 'by percentage',
      SplitType.shares => 'by shares',
      SplitType.adjustment => 'by adjustment',
      SplitType.itemized => 'itemized',
    };
    final participantCount = _splits.isNotEmpty ? _splits.length : members.length;
    final perPerson = participantCount > 0 && _totalAmount > 0
        ? _totalAmount / participantCount
        : 0.0;

    final topPadding = MediaQuery.of(context).padding.top;
    final availableHeight = MediaQuery.of(context).size.height - topPadding;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.88,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
          left: BorderSide(color: AppColors.borderSubtle, width: 1),
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderFocus,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        widget.existingExpense != null ? 'Edit expense' : 'Add an expense',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryTeal,
                                ),
                              )
                            : const Icon(Icons.check_rounded, color: AppColors.primaryTeal, size: 26),
                        onPressed: _isLoading ? null : () => _submit(members),
                      ),
                    ],
                  ),
                ),

                // Main Scrollable Body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // Group Indicator Pill
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'With ',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              Text(
                                currentCohort?.name ?? 'Group',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description & Category Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: _openCategoryPicker,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Center(
                                child: CategoryIcon(category: _category, size: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter a description',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.document_scanner_rounded,
                              color: AppColors.primaryTeal,
                              size: 22,
                            ),
                            tooltip: 'Scan Receipt',
                            onPressed: _openReceiptScanner,
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 24),

                      // Hero Amount Input
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text(
                                  '₹',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryTeal,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IntrinsicWidth(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -1,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: TextStyle(
                                        color: AppColors.borderFocus,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: const Text(
                                'INR (Indian Rupee)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Natural-Language Payment & Distribution Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'Paid by ',
                                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                                ),
                                InkWell(
                                  onTap: () => _openPayerSheet(members),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Text(
                                      payerLabel,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryTeal,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.primaryTeal,
                                      ),
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' and split ',
                                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                                ),
                                InkWell(
                                  onTap: () => _openSplitSheet(members),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Text(
                                      splitLabel,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryTeal,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.primaryTeal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: AppColors.borderSubtle, height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  perPerson > 0
                                      ? '$participantCount people (${CurrencyFormatter.format(perPerson)} / person)'
                                      : '$participantCount people',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openSplitSheet(members),
                                  child: const Row(
                                    children: [
                                      Text(
                                        'Change split',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryTeal,
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryTeal),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick Utility Strip: Date, Notes, Receipt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _showNotesDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.sticky_note_2_rounded, size: 15, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    _notesController.text.isNotEmpty ? 'Note added' : 'Add note',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _openReceiptScanner,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.photo_camera_rounded, size: 15, color: AppColors.primaryTeal),
                                  SizedBox(width: 6),
                                  Text(
                                    'Receipt',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryTeal),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Attached Receipt Thumbnail Preview (if present)
                      if (_receiptName != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, color: AppColors.primaryTeal, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _receiptName!,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                onPressed: () => setState(() => _receiptName = null),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Bottom Primary CTA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _submit(members),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: AppColors.surfaceDim,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.surfaceDim,
                                  ),
                                )
                              : const Text(
                                  'Save Expense',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                          SizedBox(width: 4),
                          Text(
                            'Instant sync across all group members',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
