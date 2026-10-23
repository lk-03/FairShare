import 'dart:convert';
import 'expense_payer.dart';
export 'expense_payer.dart';
import 'split.dart';

class Expense {
  final String id;
  final String cohortId;
  final String title;
  final String category;
  final String? customIcon;
  final double totalAmount;
  final String currency;
  final String paidByUserId;
  final List<ExpensePayer> payers;
  final SplitType splitType;
  final List<ExpenseSplit> splits;
  final String? receiptUrl;
  final String? notes;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? paidByName;

  const Expense({
    required this.id,
    required this.cohortId,
    required this.title,
    this.category = 'dining',
    this.customIcon,
    required this.totalAmount,
    this.currency = 'INR',
    required this.paidByUserId,
    this.payers = const [],
    this.splitType = SplitType.equal,
    this.splits = const [],
    this.receiptUrl,
    this.notes,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.paidByName,
  });

  /// Calculates personal share of this expense for a given user ID
  double userShare(String userId) {
    return splits
        .where((s) => s.userId == userId)
        .fold<double>(0.0, (sum, s) => sum + s.amount);
  }

  /// Alias for userShare
  double userSplitAmount(String userId) => userShare(userId);

  /// Calculates how much a given user contributed upfront towards paying this expense
  double userPaid(String userId) {
    if (payers.isNotEmpty) {
      return payers
          .where((p) => p.userId == userId)
          .fold<double>(0.0, (sum, p) => sum + p.amount);
    }
    return paidByUserId == userId ? totalAmount : 0.0;
  }

  /// Alias for userPaid
  double userPaidAmount(String userId) => userPaid(userId);

  /// Calculates net impact on the user (+ money they are owed, - money they owe)
  double userNetBalance(String userId) {
    return userPaid(userId) - userShare(userId);
  }

  bool isUserInvolved(String userId) {
    return userPaid(userId) > 0.005 || userShare(userId) > 0.005;
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    var rawSplits = json['splits'] ?? json['expense_splits'];
    List<ExpenseSplit> parsedSplits = [];
    if (rawSplits != null && rawSplits is List) {
      parsedSplits = rawSplits
          .whereType<Map<String, dynamic>>()
          .map((s) => ExpenseSplit.fromJson(s))
          .toList();
    }

    var rawPayers = json['payers'] ?? json['expense_payers'];
    List<ExpensePayer> parsedPayers = [];
    if (rawPayers != null && rawPayers is List) {
      parsedPayers = rawPayers
          .whereType<Map<String, dynamic>>()
          .map((p) => ExpensePayer.fromJson(p))
          .toList();
    }

    String? rawNotes = json['notes'] as String?;
    String? cleanNotes = rawNotes;

    bool parsedIsDeleted = json['is_deleted'] as bool? ?? json['isDeleted'] as bool? ?? false;
    DateTime? parsedDeletedAt;
    if (json['deleted_at'] != null || json['deletedAt'] != null) {
      final rawDt = json['deleted_at'] ?? json['deletedAt'];
      parsedDeletedAt = DateTime.tryParse(rawDt.toString());
    }

    // Decode [FS_DELETED: ...] if present in notes
    if (rawNotes != null && rawNotes.contains('[FS_DELETED:')) {
      final regExp = RegExp(r'\[FS_DELETED:\s*(.*?)\]', dotAll: true);
      final match = regExp.firstMatch(rawNotes);
      if (match != null) {
        parsedIsDeleted = true;
        final deletedJsonStr = match.group(1);
        if (deletedJsonStr != null) {
          try {
            final decoded = jsonDecode(deletedJsonStr);
            if (decoded is Map && decoded['deleted_at'] != null) {
              parsedDeletedAt = DateTime.tryParse(decoded['deleted_at'].toString());
            }
          } catch (_) {}
        }
        cleanNotes = cleanNotes?.replaceAll(regExp, '').trim();
        if (cleanNotes != null && cleanNotes.isEmpty) cleanNotes = null;
      }
    }

    // Decode [FS_PAYERS: ...] if rawPayers was not found (e.g. from Supabase text column)
    if (rawNotes != null && rawNotes.contains('[FS_PAYERS:')) {
      final regExp = RegExp(r'\[FS_PAYERS:\s*(.*?)\]', dotAll: true);
      final match = regExp.firstMatch(rawNotes);
      if (match != null) {
        final payersJsonStr = match.group(1);
        if (payersJsonStr != null && parsedPayers.isEmpty) {
          try {
            final decoded = jsonDecode(payersJsonStr);
            if (decoded is List) {
              parsedPayers = decoded
                  .whereType<Map<String, dynamic>>()
                  .map((p) => ExpensePayer.fromJson(p))
                  .toList();
            }
          } catch (_) {}
        }
        cleanNotes = rawNotes.replaceAll(regExp, '').trim();
        if (cleanNotes.isEmpty) cleanNotes = null;
      }
    }

    final totalAmt = (json['total_amount'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble() ??
        0.0;
    final primaryPayerId = json['paid_by_user_id'] as String? ??
        json['paidByUserId'] as String? ??
        '';

    // If payers list is empty but primary payer exists, initialize default single payer
    if (parsedPayers.isEmpty && primaryPayerId.isNotEmpty && totalAmt > 0) {
      parsedPayers = [ExpensePayer(userId: primaryPayerId, amount: totalAmt)];
    }

    return Expense(
      id: json['id'] as String,
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'dining',
      customIcon: json['custom_icon'] as String? ?? json['customIcon'] as String?,
      totalAmount: totalAmt,
      currency: json['currency'] as String? ?? 'INR',
      paidByUserId: primaryPayerId,
      payers: parsedPayers,
      splitType: SplitType.fromString(
        json['split_type'] as String? ?? json['splitType'] as String?,
      ),
      splits: parsedSplits,
      receiptUrl: json['receipt_url'] as String? ?? json['receiptUrl'] as String?,
      notes: cleanNotes,
      isDeleted: parsedIsDeleted,
      deletedAt: parsedDeletedAt,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      paidByName: json['paid_by_name'] as String? ?? json['paidByName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cohort_id': cohortId,
      'title': title,
      'category': category,
      if (customIcon != null) 'custom_icon': customIcon,
      'total_amount': totalAmount,
      'currency': currency,
      'paid_by_user_id': paidByUserId,
      if (payers.isNotEmpty) 'payers': payers.map((p) => p.toJson()).toList(),
      'split_type': splitType.toDbString(),
      'splits': splits.map((s) => s.toJson()).toList(),
      if (receiptUrl != null) 'receipt_url': receiptUrl,
      if (notes != null) 'notes': notes,
      'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Expense copyWith({
    String? id,
    String? cohortId,
    String? title,
    String? category,
    String? customIcon,
    double? totalAmount,
    String? currency,
    String? paidByUserId,
    List<ExpensePayer>? payers,
    SplitType? splitType,
    List<ExpenseSplit>? splits,
    String? receiptUrl,
    String? notes,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? paidByName,
  }) {
    return Expense(
      id: id ?? this.id,
      cohortId: cohortId ?? this.cohortId,
      title: title ?? this.title,
      category: category ?? this.category,
      customIcon: customIcon ?? this.customIcon,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      payers: payers ?? this.payers,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidByName: paidByName ?? this.paidByName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
