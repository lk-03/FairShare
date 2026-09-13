import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/direct_debt.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/split.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/upi_intent.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class SettleUpSheet extends ConsumerStatefulWidget {
  final String cohortId;
  final DirectDebt debt;

  const SettleUpSheet({
    super.key,
    required this.cohortId,
    required this.debt,
  });

  static Future<void> show(
    BuildContext context, {
    required String cohortId,
    required DirectDebt debt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettleUpSheet(
        cohortId: cohortId,
        debt: debt,
      ),
    );
  }

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  late final TextEditingController _amountController;
  bool _isLoading = false;
  bool _copiedVpa = false;
  bool _showQr = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.debt.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  void _handleCopyVpa(String vpa) {
    Clipboard.setData(ClipboardData(text: vpa));
    setState(() => _copiedVpa = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI ID "$vpa" copied! Open GPay, PhonePe, or Paytm to pay safely.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedVpa = false);
    });
  }

  Future<void> _handleLaunchUPI({
    required String vpa,
    required String payeeName,
  }) async {
    final amount = _currentAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than 0'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final config = UPIPaymentConfig(
      vpaId: vpa,
      payeeName: payeeName,
      amount: amount,
      currency: 'INR',
      note: 'FairShare Settlement',
    );

    final result = await UPIIntentHelper.launchUPIIntent(config);
    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Could not launch UPI payment app.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening UPI App... (Tip: If Paytm blocks with "risk policy", use Google Pay / PhonePe or copy UPI ID)'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _recordSettlement({
    required String payerName,
    required String payeeName,
    required String method,
  }) async {
    final amount = _currentAmount;
    if (amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final settlementExpense = Expense(
        id: 'settle_${now.millisecondsSinceEpoch}',
        cohortId: widget.cohortId,
        title: '$payerName paid $payeeName ($method)',
        category: 'settlement',
        totalAmount: amount,
        currency: 'INR',
        paidByUserId: widget.debt.fromUserId,
        paidByName: payerName,
        splitType: SplitType.exact,
        splits: [
          ExpenseSplit(userId: widget.debt.toUserId, amount: amount),
        ],
        notes: 'Settle Up Payment',
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(groupExpensesProvider(widget.cohortId).notifier)
          .addExpense(settlementExpense);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Settlement of ${CurrencyFormatter.formatINR(amount)} recorded successfully!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record settlement: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final members = ref.watch(groupMembersProvider(widget.cohortId));

    final creditorMember = members.where((m) => m.userId == widget.debt.toUserId).firstOrNull;
    final debtorMember = members.where((m) => m.userId == widget.debt.fromUserId).firstOrNull;

    final isMeDebtor = widget.debt.fromUserId == currentUser?.id;
    final isMeCreditor = widget.debt.toUserId == currentUser?.id;

    final payerDisplayName = isMeDebtor
        ? 'You'
        : (debtorMember?.profile?.displayName ?? 'Payer');

    final payeeDisplayName = isMeCreditor
        ? 'You'
        : (creditorMember?.profile?.displayName ?? 'Payee');

    final rawVpa = creditorMember?.profile?.vpaId;
    final fallbackVpa = '${payeeDisplayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@upi';
    final payeeVpa = (rawVpa != null && rawVpa.isNotEmpty) ? rawVpa : fallbackVpa;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                'Settle Up Balance',
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

          // Visual Transaction Flow Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                // Payer Avatar
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.crimson.withValues(alpha: 0.2),
                        child: Text(
                          payerDisplayName.isNotEmpty ? payerDisplayName[0].toUpperCase() : 'P',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.crimson,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        payerDisplayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      Text(
                        'Payer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow & Amount
                Column(
                  children: [
                    Icon(Icons.arrow_forward_rounded, color: colors.cyan, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatINR(widget.debt.amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: colors.cyan,
                      ),
                    ),
                  ],
                ),

                // Payee Avatar
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.emerald.withValues(alpha: 0.2),
                        child: Text(
                          payeeDisplayName.isNotEmpty ? payeeDisplayName[0].toUpperCase() : 'R',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.emerald,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        payeeDisplayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                      Text(
                        'Payee',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Settlement Amount Input
          Text(
            'SETTLEMENT AMOUNT (INR)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.textMain,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: colors.cyan,
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
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Payee UPI ID Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 20, color: colors.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payee UPI ID (VPA)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        payeeVpa,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _handleCopyVpa(payeeVpa),
                  icon: Icon(
                    _copiedVpa ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18,
                    color: _copiedVpa ? colors.emerald : colors.cyan,
                  ),
                  tooltip: 'Copy UPI ID',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Paytm & Bank Risk Notice Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paytm Intent Policy Notice',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.amber,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Paytm blocks third-party app intents ("Payment failed as per UPI risk policy"). For a smooth payment, select Google Pay / PhonePe, scan the QR code below, or copy the UPI ID.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary: Launch UPI Payment Intent
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _handleLaunchUPI(vpa: payeeVpa, payeeName: payeeDisplayName),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.cyan,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.flash_on_rounded, size: 20),
              label: Text(
                'Pay with UPI App (${CurrencyFormatter.formatINR(_currentAmount)})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // QR Code Toggle Button
          OutlinedButton.icon(
            onPressed: () => setState(() => _showQr = !_showQr),
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.accentPill,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: Icon(
              _showQr ? Icons.qr_code_rounded : Icons.qr_code_scanner_rounded,
              size: 18,
              color: colors.cyan,
            ),
            label: Text(
              _showQr ? 'Hide Settlement QR Code' : 'Show Settlement QR Code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.textMain,
              ),
            ),
          ),
          if (_showQr) ...[
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: UPIIntentHelper.buildUPIIntentURL(
                    UPIPaymentConfig(
                      vpaId: payeeVpa,
                      payeeName: payeeDisplayName,
                      amount: _currentAmount > 0 ? _currentAmount : widget.debt.amount,
                    ),
                  ),
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan directly or screenshot & scan from gallery in Paytm/GPay to bypass intent blocks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Secondary: Record as Settled (Cash / Bank Transfer)
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _recordSettlement(
                        payerName: payerDisplayName,
                        payeeName: payeeDisplayName,
                        method: 'Cash / Transfer',
                      ),
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.accentPill,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(Icons.check_circle_outline_rounded, size: 18, color: colors.emerald),
              label: Text(
                'Record as Settled (Cash / Paid)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.textMain,
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
