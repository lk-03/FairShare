import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/models/split.dart';
import '../../../../core/utils/currency_formatter.dart';

class AdjustSplitResult {
  final SplitType splitType;
  final List<ExpenseSplit> splits;

  const AdjustSplitResult({
    required this.splitType,
    required this.splits,
  });
}

class AdjustSplitSheet extends StatefulWidget {
  final List<GroupMember> members;
  final double totalAmount;
  final SplitType initialSplitType;
  final List<ExpenseSplit> initialSplits;

  const AdjustSplitSheet({
    super.key,
    required this.members,
    required this.totalAmount,
    this.initialSplitType = SplitType.equal,
    this.initialSplits = const [],
  });

  static Future<AdjustSplitResult?> show(
    BuildContext context, {
    required List<GroupMember> members,
    required double totalAmount,
    SplitType initialSplitType = SplitType.equal,
    List<ExpenseSplit> initialSplits = const [],
  }) {
    return showModalBottomSheet<AdjustSplitResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdjustSplitSheet(
        members: members,
        totalAmount: totalAmount,
        initialSplitType: initialSplitType,
        initialSplits: initialSplits,
      ),
    );
  }

  @override
  State<AdjustSplitSheet> createState() => _AdjustSplitSheetState();
}

class _AdjustSplitSheetState extends State<AdjustSplitSheet> {
  late SplitType _currentType;

  // Mode 1: Equal
  final Set<String> _selectedEqualMemberIds = {};

  // Mode 2: Exact (Unequally)
  final Map<String, TextEditingController> _exactControllers = {};

  // Mode 3: Percentages
  final Map<String, TextEditingController> _percentControllers = {};

  // Mode 4: Shares
  final Map<String, int> _shares = {};

  // Mode 5: Adjustments
  final Map<String, TextEditingController> _adjustmentControllers = {};

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialSplitType;

    for (final m in widget.members) {
      _selectedEqualMemberIds.add(m.userId);
      _shares[m.userId] = 1;

      // Find initial split if present
      final existing = widget.initialSplits.firstWhere(
        (s) => s.userId == m.userId,
        orElse: () => ExpenseSplit(userId: m.userId, amount: 0.0),
      );

      _exactControllers[m.userId] = TextEditingController(
        text: existing.amount > 0 ? existing.amount.toStringAsFixed(2) : '',
      );

      final pct = existing.percentage ??
          (widget.totalAmount > 0 ? (existing.amount / widget.totalAmount) * 100 : 0.0);
      _percentControllers[m.userId] = TextEditingController(
        text: pct > 0 ? pct.toStringAsFixed(1) : '',
      );

      final adj = existing.adjustment ?? 0.0;
      _adjustmentControllers[m.userId] = TextEditingController(
        text: adj > 0 ? (adj % 1 == 0 ? adj.toInt().toString() : adj.toStringAsFixed(2)) : '',
      );
    }

    if (widget.initialSplits.isNotEmpty && _currentType == SplitType.equal) {
      _selectedEqualMemberIds.clear();
      for (final s in widget.initialSplits) {
        if (s.amount > 0) _selectedEqualMemberIds.add(s.userId);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    for (final c in _adjustmentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Helper calculations
  double get _exactSum {
    double s = 0.0;
    for (final c in _exactControllers.values) {
      s += double.tryParse(c.text.trim()) ?? 0.0;
    }
    return s;
  }

  double get _percentSum {
    double s = 0.0;
    for (final c in _percentControllers.values) {
      s += double.tryParse(c.text.trim()) ?? 0.0;
    }
    return s;
  }

  int get _totalShares {
    int s = 0;
    for (final v in _shares.values) {
      s += v;
    }
    return s;
  }

  double get _adjustmentSum {
    double s = 0.0;
    for (final c in _adjustmentControllers.values) {
      s += double.tryParse(c.text.trim()) ?? 0.0;
    }
    return s;
  }

  double _calculateMemberAdjustmentTotal(String userId) {
    if (widget.members.isEmpty) return 0.0;
    final adjSum = _adjustmentSum;
    final remainder = widget.totalAmount - adjSum;
    final base = remainder > 0 ? remainder / widget.members.length : 0.0;
    final myAdj = double.tryParse(_adjustmentControllers[userId]?.text.trim() ?? '') ?? 0.0;
    return base + myAdj;
  }

  void _toggleAllEqual(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedEqualMemberIds.addAll(widget.members.map((m) => m.userId));
      } else {
        _selectedEqualMemberIds.clear();
      }
    });
  }

  void _confirm() {
    final splits = <ExpenseSplit>[];

    switch (_currentType) {
      case SplitType.equal:
        final count = _selectedEqualMemberIds.length;
        if (count == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Select at least one member to split equally.'),
              backgroundColor: AppColors.rose,
            ),
          );
          return;
        }
        final base = (widget.totalAmount / count * 100).floor() / 100.0;
        final remainder = widget.totalAmount - (base * count);
        final sortedIds = _selectedEqualMemberIds.toList();

        for (var i = 0; i < sortedIds.length; i++) {
          final uId = sortedIds[i];
          final amt = i == 0 ? base + remainder : base;
          splits.add(ExpenseSplit(userId: uId, amount: amt));
        }
        break;

      case SplitType.exact:
        final sum = _exactSum;
        if ((sum - widget.totalAmount).abs() > 0.05) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                sum < widget.totalAmount
                    ? '₹${(widget.totalAmount - sum).toStringAsFixed(2)} left to distribute.'
                    : '₹${(sum - widget.totalAmount).toStringAsFixed(2)} over the total amount.',
              ),
              backgroundColor: AppColors.rose,
            ),
          );
          return;
        }
        for (final m in widget.members) {
          final amt = double.tryParse(_exactControllers[m.userId]?.text.trim() ?? '') ?? 0.0;
          if (amt > 0) {
            splits.add(ExpenseSplit(userId: m.userId, amount: amt));
          }
        }
        break;

      case SplitType.percentage:
        final pctSum = _percentSum;
        if ((pctSum - 100.0).abs() > 0.5) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                pctSum < 100.0
                    ? '${(100.0 - pctSum).toStringAsFixed(1)}% remaining to assign.'
                    : '${(pctSum - 100.0).toStringAsFixed(1)}% over 100%.',
              ),
              backgroundColor: AppColors.rose,
            ),
          );
          return;
        }
        for (final m in widget.members) {
          final pct = double.tryParse(_percentControllers[m.userId]?.text.trim() ?? '') ?? 0.0;
          if (pct > 0) {
            final amt = double.parse(((widget.totalAmount * pct) / 100.0).toStringAsFixed(2));
            splits.add(ExpenseSplit(userId: m.userId, amount: amt, percentage: pct));
          }
        }
        break;

      case SplitType.shares:
        final totShares = _totalShares;
        if (totShares <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one member must have 1 share.'),
              backgroundColor: AppColors.rose,
            ),
          );
          return;
        }
        final shareUnit = widget.totalAmount / totShares;
        for (final m in widget.members) {
          final sh = _shares[m.userId] ?? 0;
          if (sh > 0) {
            final amt = double.parse((sh * shareUnit).toStringAsFixed(2));
            splits.add(ExpenseSplit(userId: m.userId, amount: amt));
          }
        }
        break;

      case SplitType.adjustment:
        final adjSum = _adjustmentSum;
        if (adjSum > widget.totalAmount + 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Adjustments exceed total amount by ${CurrencyFormatter.format(adjSum - widget.totalAmount)}.',
              ),
              backgroundColor: AppColors.rose,
            ),
          );
          return;
        }

        final count = widget.members.length;
        if (count == 0) return;

        final remainder = widget.totalAmount - adjSum;
        final baseCents = ((remainder / count) * 100).floor() / 100.0;
        final distributedRemainder = baseCents * count;
        final pennyRemainder = double.parse((remainder - distributedRemainder).toStringAsFixed(2));

        for (var i = 0; i < widget.members.length; i++) {
          final m = widget.members[i];
          final adj = double.tryParse(_adjustmentControllers[m.userId]?.text.trim() ?? '') ?? 0.0;
          final extraCent = (i == 0 && pennyRemainder > 0) ? pennyRemainder : 0.0;
          final amt = double.parse((baseCents + extraCent + adj).toStringAsFixed(2));
          splits.add(ExpenseSplit(
            userId: m.userId,
            amount: amt,
            adjustment: adj > 0 ? adj : null,
          ));
        }
        break;

      case SplitType.itemized:
        // Itemized fallback to equal
        for (final m in widget.members) {
          splits.add(ExpenseSplit(userId: m.userId, amount: widget.totalAmount / widget.members.length));
        }
        break;
    }

    Navigator.of(context).pop(AdjustSplitResult(
      splitType: _currentType,
      splits: splits,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

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
            // Grab handle
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

            // Top bar
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
                        'Adjust split',
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

            // Tab bar for Splitwise-style 5 modes
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  _buildTabItem(SplitType.equal, 'Equally', '='),
                  _buildTabItem(SplitType.exact, 'Unequally', '₹'),
                  _buildTabItem(SplitType.percentage, 'Percent', '%'),
                  _buildTabItem(SplitType.shares, 'Shares', 'x:y'),
                  _buildTabItem(SplitType.adjustment, 'Adjust', '+'),
                ],
              ),
            ),

            // Explanatory Mode Description Card for all split modes
            _buildExplanationCard(),

            // Member list with mode-specific controls
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                itemCount: widget.members.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: AppColors.borderSubtle,
                ),
                itemBuilder: (context, index) {
                  final member = widget.members[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surfaceCard,
                          child: Text(
                            (member.displayName.isNotEmpty
                                    ? member.displayName[0]
                                    : 'U')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name and calculated total share in adjustment mode
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                member.displayName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_currentType == SplitType.adjustment) ...[
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(_calculateMemberAdjustmentTotal(member.userId)),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Controls per mode
                        _buildMemberControl(member),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom summary footer
            _buildBottomFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(SplitType type, String label, String symbol) {
    final isActive = _currentType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.surfaceDim : AppColors.textSecondary,
                ),
              ),
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppColors.surfaceDim.withValues(alpha: 0.8)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    final IconData icon1;
    final IconData icon2;
    final String title;
    final String description;

    switch (_currentType) {
      case SplitType.equal:
        icon1 = Icons.drag_handle_rounded;
        icon2 = Icons.balance_rounded;
        title = 'Split equally';
        description =
            'Everyone pays an equal share of the total bill. Toggle members to include or exclude them.';
        break;
      case SplitType.exact:
        icon1 = Icons.currency_rupee_rounded;
        icon2 = Icons.edit_note_rounded;
        title = 'Split by exact amounts';
        description =
            'Specify exactly how much each person owes. The sum of all shares must match the total bill.';
        break;
      case SplitType.percentage:
        icon1 = Icons.percent_rounded;
        icon2 = Icons.pie_chart_outline_rounded;
        title = 'Split by percentages';
        description =
            'Enter the percentage split for each person. Total percentages must add up to 100%.';
        break;
      case SplitType.shares:
        icon1 = Icons.pie_chart_rounded;
        icon2 = Icons.call_split_rounded;
        title = 'Split by shares';
        description =
            'Enter the number of shares each person owes. FairShare will divide the bill proportionally.';
        break;
      case SplitType.adjustment:
        icon1 = Icons.tune_rounded;
        icon2 = Icons.balance_rounded;
        title = 'Split by adjustment';
        description =
            'Enter adjustments to reflect who owes extra; FairShare will distribute the remainder equally.';
        break;
      case SplitType.itemized:
        icon1 = Icons.receipt_long_rounded;
        icon2 = Icons.checklist_rounded;
        title = 'Itemized split';
        description = 'Items and taxes are split according to receipt line items.';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon1,
                    color: AppColors.primaryTeal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon2,
                    color: AppColors.emerald,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberControl(GroupMember member) {
    switch (_currentType) {
      case SplitType.equal:
        final isChecked = _selectedEqualMemberIds.contains(member.userId);
        return Checkbox(
          value: isChecked,
          activeColor: AppColors.primaryTeal,
          checkColor: AppColors.surfaceDim,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          side: const BorderSide(color: AppColors.borderFocus, width: 1.5),
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedEqualMemberIds.add(member.userId);
              } else {
                _selectedEqualMemberIds.remove(member.userId);
              }
            });
          },
        );

      case SplitType.exact:
        return SizedBox(
          width: 100,
          child: TextField(
            controller: _exactControllers[member.userId],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
        );

      case SplitType.percentage:
        return SizedBox(
          width: 80,
          child: TextField(
            controller: _percentControllers[member.userId],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixText: ' %',
              suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
        );

      case SplitType.shares:
        final currentShares = _shares[member.userId] ?? 1;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (currentShares > 0) {
                    setState(() => _shares[member.userId] = currentShares - 1);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$currentShares',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _shares[member.userId] = currentShares + 1);
                },
              ),
            ],
          ),
        );

      case SplitType.adjustment:
        return SizedBox(
          width: 105,
          child: TextField(
            controller: _adjustmentControllers[member.userId],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '+ ',
              prefixStyle: const TextStyle(
                color: AppColors.primaryTeal,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              hintText: '0.00',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
              ),
            ),
          ),
        );

      case SplitType.itemized:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomFooter() {
    switch (_currentType) {
      case SplitType.equal:
        final count = _selectedEqualMemberIds.length;
        final perHead = count > 0 ? widget.totalAmount / count : 0.0;
        final allChecked = count == widget.members.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '~${CurrencyFormatter.format(perHead)} / person',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '($count people)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('All', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(width: 6),
                  Checkbox(
                    value: allChecked,
                    activeColor: AppColors.primaryTeal,
                    checkColor: AppColors.surfaceDim,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => _toggleAllEqual(val == true),
                  ),
                ],
              ),
            ],
          ),
        );

      case SplitType.exact:
        final sum = _exactSum;
        final diff = widget.totalAmount - sum;
        final isSettled = diff.abs() <= 0.05;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyFormatter.format(sum)} of ${CurrencyFormatter.format(widget.totalAmount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                isSettled
                    ? '✓ All settled'
                    : (diff > 0
                        ? '${CurrencyFormatter.format(diff)} left'
                        : '${CurrencyFormatter.format(diff.abs())} over'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSettled
                      ? AppColors.emerald
                      : (diff > 0 ? AppColors.amber : AppColors.rose),
                ),
              ),
            ],
          ),
        );

      case SplitType.percentage:
        final sum = _percentSum;
        final diff = 100.0 - sum;
        final isSettled = diff.abs() <= 0.05;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sum.toStringAsFixed(1)}% of 100%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                isSettled
                    ? '✓ 100% split'
                    : (diff > 0
                        ? '${diff.toStringAsFixed(1)}% left'
                        : '${diff.abs().toStringAsFixed(1)}% over'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSettled
                      ? AppColors.emerald
                      : (diff > 0 ? AppColors.amber : AppColors.rose),
                ),
              ),
            ],
          ),
        );

      case SplitType.shares:
        final totShares = _totalShares;
        final perShare = totShares > 0 ? widget.totalAmount / totShares : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totShares total shares',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                totShares > 0 ? '(~${CurrencyFormatter.format(perShare)} / share)' : '(0 shares)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
        );

      case SplitType.adjustment:
        final adjSum = _adjustmentSum;
        final remainder = widget.totalAmount - adjSum;
        final isOver = adjSum > widget.totalAmount + 0.01;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${CurrencyFormatter.format(adjSum)} in adjustments',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'of ${CurrencyFormatter.format(widget.totalAmount)} total',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isOver
                      ? '${CurrencyFormatter.format(adjSum - widget.totalAmount)} over'
                      : '✓ Remainder ${CurrencyFormatter.format(remainder)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOver ? AppColors.rose : AppColors.emerald,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

      case SplitType.itemized:
        return const SizedBox.shrink();
    }
  }
}
