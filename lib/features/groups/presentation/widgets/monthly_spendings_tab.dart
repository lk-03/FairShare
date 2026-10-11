import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';

class MonthlySpendingsTab extends StatefulWidget {
  final Group cohort;
  final List<Expense> expenses;
  final List<GroupMember> members;
  final String currentUserId;

  const MonthlySpendingsTab({
    super.key,
    required this.cohort,
    required this.expenses,
    required this.members,
    required this.currentUserId,
  });

  @override
  State<MonthlySpendingsTab> createState() => _MonthlySpendingsTabState();
}

class _MonthlySpendingsTabState extends State<MonthlySpendingsTab> {
  int _touchedIndex = -1;
  int _memberChartMode = 0; // 0: By Share, 1: By Paid

  Color _getMemberColor(String userId, [int index = 0]) {
    final seed = userId.isNotEmpty ? userId : 'member_$index';
    final hash = seed.codeUnits.fold<int>(index * 17, (prev, curr) => (prev * 31 + curr) & 0x7FFFFFFF);
    // Golden angle distribution for wide visual separation between members
    final hue = ((hash + index * 59) * 137.508) % 360.0;
    // Slightly desaturated (0.40) and balanced lightness (0.60) - not too vibrant
    return HSLColor.fromAHSL(1.0, hue, 0.40, 0.60).toColor();
  }

  Widget _buildToggleChip(String label, int mode) {
    final isSelected = _memberChartMode == mode;
    return InkWell(
      onTap: () => setState(() {
        _memberChartMode = mode;
        _touchedIndex = -1;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryTeal.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.primaryTeal : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 32,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No expenses logged yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Spendings and member breakdown will appear here once expenses are added.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // 1. Calculate Group Spend, Paid, Shares & Categories
    double totalGroupSpend = 0.0;
    double totalUserShare = 0.0;
    double totalPaid = 0.0;
    final Map<String, double> categorySpend = {};
    final Map<String, double> memberPaidMap = {};
    final Map<String, double> memberShareMap = {};

    for (final m in widget.members) {
      memberPaidMap[m.userId] = 0.0;
      memberShareMap[m.userId] = 0.0;
    }

    for (final exp in widget.expenses) {
      totalGroupSpend += exp.totalAmount;
      categorySpend[exp.category] = (categorySpend[exp.category] ?? 0.0) + exp.totalAmount;

      // Calculate paid
      if (exp.payers.isNotEmpty) {
        for (final p in exp.payers) {
          memberPaidMap[p.userId] = (memberPaidMap[p.userId] ?? 0.0) + p.amount;
          totalPaid += p.amount;
        }
      } else {
        memberPaidMap[exp.paidByUserId] =
            (memberPaidMap[exp.paidByUserId] ?? 0.0) + exp.totalAmount;
        totalPaid += exp.totalAmount;
      }

      // Calculate share
      for (final s in exp.splits) {
        memberShareMap[s.userId] = (memberShareMap[s.userId] ?? 0.0) + s.amount;
        if (s.userId == widget.currentUserId) {
          totalUserShare += s.amount;
        }
      }
    }

    // Sort categories descending by spent amount
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Build member spending entries
    final memberSpendEntries = widget.members.map((m) {
      final share = memberShareMap[m.userId] ?? 0.0;
      final paid = memberPaidMap[m.userId] ?? 0.0;
      final val = _memberChartMode == 0 ? share : paid;
      return (member: m, value: val);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final relevantTotal = _memberChartMode == 0
        ? totalGroupSpend
        : (totalPaid > 0 ? totalPaid : totalGroupSpend);

    // Build chart sections with desaturated per-member colors
    final pieSections = <PieChartSectionData>[];
    for (var i = 0; i < memberSpendEntries.length; i++) {
      final item = memberSpendEntries[i];
      if (item.value <= 0) continue;
      final isTouched = i == _touchedIndex;
      final pct = relevantTotal > 0 ? (item.value / relevantTotal) * 100 : 0.0;
      final color = _getMemberColor(item.member.userId, i);

      pieSections.add(
        PieChartSectionData(
          color: color,
          value: item.value,
          title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
          radius: isTouched ? 58.0 : 48.0,
          titleStyle: TextStyle(
            fontSize: isTouched ? 14 : 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Dual Spend Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GROUP SPENDINGS OVERVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Group Spend',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(totalGroupSpend),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: AppColors.borderSubtle,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Your Personal Share',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(totalUserShare),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Donut Chart: Member Breakdown
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Member Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _memberChartMode == 0
                            ? 'By consumption share'
                            : 'By upfront payment',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleChip('Share', 0),
                        _buildToggleChip('Paid', 1),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 46,
                    sections: pieSections.isNotEmpty
                        ? pieSections
                        : [
                            PieChartSectionData(
                              color: AppColors.surface,
                              value: 1,
                              title: '0%',
                              radius: 48,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Member Ranking List
              ...memberSpendEntries.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final color = _getMemberColor(item.member.userId, idx);
                final isMe = item.member.userId == widget.currentUserId;
                final name = isMe ? 'You' : item.member.displayName;
                final pct = relevantTotal > 0 ? (item.value / relevantTotal) * 100 : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isMe
                            ? AppColors.primaryTeal.withValues(alpha: 0.2)
                            : AppColors.surfaceDim,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMe ? AppColors.primaryTeal : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.format(item.value),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Categories Spent
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Categories Spent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Distribution of group spending across expense categories',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (sortedCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No categorized expenses yet',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                )
              else
                ...sortedCategories.map((entry) {
                  final catKey = entry.key;
                  final amount = entry.value;
                  final pct = totalGroupSpend > 0 ? (amount / totalGroupSpend) * 100 : 0.0;
                  final cfg = categoryStyles[catKey.toLowerCase()];
                  final label = cfg?.label ??
                      (catKey.isNotEmpty
                          ? '${catKey[0].toUpperCase()}${catKey.substring(1)}'
                          : 'Other');
                  final color = cfg?.darkIcon ?? AppColors.primaryTeal;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CategoryIcon(
                              category: catKey,
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: totalGroupSpend > 0
                                      ? (amount / totalGroupSpend).clamp(0.0, 1.0)
                                      : 0.0,
                                  backgroundColor: AppColors.surfaceCard,
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
