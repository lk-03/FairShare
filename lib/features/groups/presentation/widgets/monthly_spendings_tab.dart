import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';

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

  final List<Color> _chartPalette = [
    AppColors.primaryTeal,
    const Color(0xFF38BDF8),
    const Color(0xFFA855F7),
    const Color(0xFFF59E0B),
    const Color(0xFFEC4899),
    const Color(0xFF10B981),
    const Color(0xFF6366F1),
  ];

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

    // 1. Calculate Group Spend, Paid & Shares
    double totalGroupSpend = 0.0;
    double totalUserShare = 0.0;
    double totalPaid = 0.0;
    final Map<String, double> memberPaidMap = {};
    final Map<String, double> memberShareMap = {};

    for (final m in widget.members) {
      memberPaidMap[m.userId] = 0.0;
      memberShareMap[m.userId] = 0.0;
    }

    for (final exp in widget.expenses) {
      totalGroupSpend += exp.totalAmount;

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

    // Build chart sections
    final pieSections = <PieChartSectionData>[];
    for (var i = 0; i < memberSpendEntries.length; i++) {
      final item = memberSpendEntries[i];
      if (item.value <= 0) continue;
      final isTouched = i == _touchedIndex;
      final pct = relevantTotal > 0 ? (item.value / relevantTotal) * 100 : 0.0;
      final color = _chartPalette[i % _chartPalette.length];

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
                final color = _chartPalette[idx % _chartPalette.length];
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

        // Member Contribution Matrix
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
                'Member Contribution Matrix',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Comparison of upfront cash paid vs actual consumption share',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...widget.members.map((member) {
                final paid = memberPaidMap[member.userId] ?? 0.0;
                final share = memberShareMap[member.userId] ?? 0.0;
                final net = paid - share;
                final isMe = member.userId == widget.currentUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primaryTeal.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMe
                          ? AppColors.primaryTeal.withValues(alpha: 0.3)
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isMe
                                    ? AppColors.primaryTeal
                                    : AppColors.surfaceCard,
                                child: Text(
                                  (member.displayName.isNotEmpty
                                          ? member.displayName[0]
                                          : 'U')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isMe
                                        ? AppColors.surfaceDim
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMe ? 'You' : member.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            net > 0.01
                                ? '+${CurrencyFormatter.format(net)}'
                                : (net < -0.01
                                    ? CurrencyFormatter.format(net)
                                    : 'Settled'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: net > 0.01
                                  ? AppColors.emerald
                                  : (net < -0.01 ? AppColors.rose : AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paid: ${CurrencyFormatter.format(paid)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            'Share: ${CurrencyFormatter.format(share)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
