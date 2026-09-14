import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense_payer.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';

class PayerSelectionResult {
  final String primaryPaidByUserId;
  final List<ExpensePayer> payers;

  const PayerSelectionResult({
    required this.primaryPaidByUserId,
    required this.payers,
  });
}

class PayerSelectionSheet extends StatefulWidget {
  final List<GroupMember> members;
  final double totalAmount;
  final String initialPaidByUserId;
  final List<ExpensePayer> initialPayers;

  const PayerSelectionSheet({
    super.key,
    required this.members,
    required this.totalAmount,
    required this.initialPaidByUserId,
    this.initialPayers = const [],
  });

  static Future<PayerSelectionResult?> show(
    BuildContext context, {
    required List<GroupMember> members,
    required double totalAmount,
    required String initialPaidByUserId,
    List<ExpensePayer> initialPayers = const [],
  }) {
    return showModalBottomSheet<PayerSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayerSelectionSheet(
        members: members,
        totalAmount: totalAmount,
        initialPaidByUserId: initialPaidByUserId,
        initialPayers: initialPayers,
      ),
    );
  }

  @override
  State<PayerSelectionSheet> createState() => _PayerSelectionSheetState();
}

class _PayerSelectionSheetState extends State<PayerSelectionSheet> {
  bool _isMultiPayer = false;
  late String _selectedSingleUserId;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _selectedSingleUserId = widget.initialPaidByUserId.isNotEmpty
        ? widget.initialPaidByUserId
        : (widget.members.isNotEmpty ? widget.members.first.userId : '');

    final hasMultiple = widget.initialPayers.length > 1;
    _isMultiPayer = hasMultiple;

    for (final m in widget.members) {
      double initialVal = 0.0;
      if (hasMultiple) {
        final existing = widget.initialPayers.firstWhere(
          (p) => p.userId == m.userId,
          orElse: () => ExpensePayer(userId: m.userId, amount: 0.0),
        );
        initialVal = existing.amount;
      } else if (m.userId == _selectedSingleUserId) {
        initialVal = widget.totalAmount;
      }
      _controllers[m.userId] = TextEditingController(
        text: initialVal > 0 ? initialVal.toStringAsFixed(2) : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _currentMultiSum {
    double sum = 0.0;
    for (final c in _controllers.values) {
      final val = double.tryParse(c.text.trim()) ?? 0.0;
      sum += val;
    }
    return sum;
  }

  void _splitEquallyAmongPayers() {
    if (widget.members.isEmpty || widget.totalAmount <= 0) return;
    final count = widget.members.length;
    final base = (widget.totalAmount / count * 100).floor() / 100.0;
    final remainder = widget.totalAmount - (base * count);

    for (var i = 0; i < widget.members.length; i++) {
      final m = widget.members[i];
      final val = i == 0 ? base + remainder : base;
      _controllers[m.userId]?.text = val.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _clearInputs() {
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() {});
  }

  void _confirm() {
    if (!_isMultiPayer) {
      final result = PayerSelectionResult(
        primaryPaidByUserId: _selectedSingleUserId,
        payers: [
          ExpensePayer(
            userId: _selectedSingleUserId,
            amount: widget.totalAmount,
          ),
        ],
      );
      Navigator.of(context).pop(result);
      return;
    }

    final sum = _currentMultiSum;
    final diff = (sum - widget.totalAmount).abs();
    if (widget.totalAmount > 0 && diff > 0.05) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sum < widget.totalAmount
                ? 'Still ₹${(widget.totalAmount - sum).toStringAsFixed(2)} left to account for.'
                : 'Entered ₹${(sum - widget.totalAmount).toStringAsFixed(2)} more than the total.',
          ),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    final payers = <ExpensePayer>[];
    String primaryPayer = _selectedSingleUserId;
    double maxPaid = -1.0;

    for (final m in widget.members) {
      final amt = double.tryParse(_controllers[m.userId]?.text.trim() ?? '') ?? 0.0;
      if (amt > 0) {
        payers.add(ExpensePayer(userId: m.userId, amount: amt));
        if (amt > maxPaid) {
          maxPaid = amt;
          primaryPayer = m.userId;
        }
      }
    }

    if (payers.isEmpty) {
      payers.add(ExpensePayer(
        userId: _selectedSingleUserId,
        amount: widget.totalAmount,
      ));
    }

    Navigator.of(context).pop(PayerSelectionResult(
      primaryPaidByUserId: primaryPayer,
      payers: payers,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final multiSum = _currentMultiSum;
    final discrepancy = widget.totalAmount - multiSum;
    final isSettled = discrepancy.abs() <= 0.05;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
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
            // Drag handle
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

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Who paid?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_rounded, color: AppColors.emerald, size: 26),
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),

            // Expense Summary banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXPENSE TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(widget.totalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${widget.members.length} Members',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Mode Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isMultiPayer = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: !_isMultiPayer ? AppColors.primaryTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(
                            child: Text(
                              'Single Person',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !_isMultiPayer ? AppColors.surfaceDim : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isMultiPayer = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _isMultiPayer ? AppColors.primaryTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(
                            child: Text(
                              'Multiple People',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isMultiPayer ? AppColors.surfaceDim : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Member list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                itemCount: widget.members.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: AppColors.borderSubtle,
                ),
                itemBuilder: (context, index) {
                  final member = widget.members[index];
                  final isSelected = member.userId == _selectedSingleUserId;
                  final controller = _controllers[member.userId];

                  return InkWell(
                    onTap: !_isMultiPayer
                        ? () => setState(() => _selectedSingleUserId = member.userId)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: AppColors.surfaceCard,
                            child: Text(
                              (member.displayName.isNotEmpty
                                      ? member.displayName[0]
                                      : 'U')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name & Role
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.displayName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  member.role.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Controls
                          if (!_isMultiPayer)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppColors.primaryTeal : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryTeal : AppColors.borderFocus,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: AppColors.surfaceDim)
                                  : null,
                            )
                          else
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.surfaceCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primaryTeal),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),

            // Multi-payer live ticker / shortcuts footer
            if (_isMultiPayer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.borderSubtle)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSettled ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 16,
                              color: isSettled ? AppColors.emerald : AppColors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Paid: ${CurrencyFormatter.format(multiSum)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isSettled
                              ? 'All accounted for'
                              : (discrepancy > 0
                                  ? '${CurrencyFormatter.format(discrepancy)} left'
                                  : '${CurrencyFormatter.format(discrepancy.abs())} over'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSettled
                                ? AppColors.emerald
                                : (discrepancy > 0 ? AppColors.amber : AppColors.rose),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _splitEquallyAmongPayers,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryTeal,
                              side: const BorderSide(color: AppColors.borderSubtle),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Split Paid Equally', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _clearInputs,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            side: const BorderSide(color: AppColors.borderSubtle),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Clear', style: TextStyle(fontSize: 12)),
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
