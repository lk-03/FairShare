import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/direct_debt.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'settlement_invoice_card.dart';

class SettlementShareSheet extends ConsumerStatefulWidget {
  final Group group;
  final List<Expense> expenses;
  final List<DirectDebt> debts;
  final Map<String, double> memberBalances;
  final List<GroupMember> members;
  final String? organizerVpa;

  const SettlementShareSheet({
    super.key,
    required this.group,
    required this.expenses,
    required this.debts,
    required this.memberBalances,
    required this.members,
    this.organizerVpa,
  });

  static Future<void> show(
    BuildContext context, {
    required Group group,
    required List<Expense> expenses,
    required List<DirectDebt> debts,
    required Map<String, double> memberBalances,
    required List<GroupMember> members,
    String? organizerVpa,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettlementShareSheet(
        group: group,
        expenses: expenses,
        debts: debts,
        memberBalances: memberBalances,
        members: members,
        organizerVpa: organizerVpa,
      ),
    );
  }

  @override
  ConsumerState<SettlementShareSheet> createState() =>
      _SettlementShareSheetState();
}

class _SettlementShareSheetState extends ConsumerState<SettlementShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;

  String _generateTextBreakdown() {
    final totalSpent =
        widget.expenses.fold(0.0, (sum, e) => sum + e.totalAmount);
    final memberNameMap = {
      for (final m in widget.members) m.userId: m.displayName,
    };

    final buffer = StringBuffer();
    buffer.writeln('🧾 *FairShare Outing Invoice: ${widget.group.name}*');
    buffer.writeln(
        '💰 Total Spent: ${CurrencyFormatter.formatINR(totalSpent)} across ${widget.expenses.length} expenses');
    buffer.writeln('👥 Participants: ${widget.members.length}');
    buffer.writeln();

    buffer.writeln('👉 *Who Pays Whom (Settlement):*');
    if (widget.debts.isEmpty) {
      buffer.writeln('✅ All settled up! No money owed.');
    } else {
      for (final d in widget.debts) {
        final from = memberNameMap[d.fromUserId] ?? 'Someone';
        final to = memberNameMap[d.toUserId] ?? 'Someone';
        buffer.writeln(
            '• *$from* pays *$to* ${CurrencyFormatter.formatINR(d.amount)}');
      }
    }
    buffer.writeln();

    buffer.writeln('📊 *Net Balances:*');
    for (final m in widget.members) {
      final bal = widget.memberBalances[m.userId] ?? 0.0;
      final sign = bal > 0.01 ? '+' : '';
      buffer.writeln('• ${m.displayName}: $sign${CurrencyFormatter.formatINR(bal)}');
    }

    if (widget.organizerVpa != null && widget.organizerVpa!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📱 *UPI ID for Payment:* ${widget.organizerVpa}');
    }

    buffer.writeln();
    buffer.writeln('_Calculated with FairShare (Offline Outings)_');

    return buffer.toString();
  }

  Future<void> _shareInvoiceImage() async {
    setState(() => _isSharing = true);

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not capture invoice');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Image encoding failed');

      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        // On web, share text breakdown as fallback
        await SharePlus.instance.share(
          ShareParams(
            text: _generateTextBreakdown(),
            subject: 'FairShare Settlement: ${widget.group.name}',
          ),
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/fairshare_${widget.group.id}_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: 'FairShare Settlement Invoice: ${widget.group.name}',
            subject: 'Settlement Invoice for ${widget.group.name}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share image: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _copyTextBreakdown() {
    final text = _generateTextBreakdown();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Breakdown copied! Ready to paste into WhatsApp.'),
          ],
        ),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 24),
      decoration: BoxDecoration(
        color: colors.screen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Settlement Invoice',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: colors.textMain,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Preview
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: SettlementInvoiceCard(
                    group: widget.group,
                    expenses: widget.expenses,
                    debts: widget.debts,
                    memberBalances: widget.memberBalances,
                    members: widget.members,
                    organizerVpa: widget.organizerVpa,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Share Image & Copy Text
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : _shareInvoiceImage,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      _isSharing ? 'Generating...' : 'Share Image',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cyan,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _copyTextBreakdown,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      'Copy Text',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.surface,
                      foregroundColor: colors.textMain,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
