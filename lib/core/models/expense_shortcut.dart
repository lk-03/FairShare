/// Represents a reusable group-scoped quick expense preset/shortcut
class ExpenseShortcut {
  final String id;
  final String cohortId;
  final String title;
  final String category;
  final String? customIcon;
  final double amount;
  final String? paidByUserId;
  final String splitType;
  final bool? isMultiplePayers;
  final Map<String, double>? paidAmounts;
  final List<String>? includedMemberIds;
  final Map<String, double>? exactSplits;
  final Map<String, double>? percentageSplits;
  final Map<String, double>? sharesSplits;
  final Map<String, double>? adjustmentSplits;
  final DateTime createdAt;

  const ExpenseShortcut({
    required this.id,
    required this.cohortId,
    required this.title,
    this.category = 'general',
    this.customIcon,
    required this.amount,
    this.paidByUserId,
    this.splitType = 'equal',
    this.isMultiplePayers,
    this.paidAmounts,
    this.includedMemberIds,
    this.exactSplits,
    this.percentageSplits,
    this.sharesSplits,
    this.adjustmentSplits,
    required this.createdAt,
  });

  factory ExpenseShortcut.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? splitPayload;
    if (json['split_payload'] != null && json['split_payload'] is Map<String, dynamic>) {
      splitPayload = json['split_payload'] as Map<String, dynamic>;
    }

    Map<String, double>? parseDoubleMap(dynamic raw) {
      if (raw == null || raw is! Map) return null;
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }

    List<String>? parseStringList(dynamic raw) {
      if (raw == null || raw is! List) return null;
      return raw.map((e) => e.toString()).toList();
    }

    return ExpenseShortcut(
      id: json['id'] as String? ?? '',
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      customIcon: json['custom_icon'] as String? ?? json['customIcon'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paidByUserId: json['paid_by_user_id'] as String? ?? json['paidByUserId'] as String?,
      splitType: json['split_type'] as String? ?? json['splitType'] as String? ?? 'equal',
      isMultiplePayers: splitPayload?['isMultiplePayers'] as bool? ??
          json['isMultiplePayers'] as bool?,
      paidAmounts: parseDoubleMap(splitPayload?['paidAmounts'] ?? json['paidAmounts']),
      includedMemberIds: parseStringList(
          splitPayload?['includedMemberIds'] ?? json['includedMemberIds']),
      exactSplits: parseDoubleMap(splitPayload?['exactSplits'] ?? json['exactSplits']),
      percentageSplits: parseDoubleMap(
          splitPayload?['percentageSplits'] ?? json['percentageSplits']),
      sharesSplits: parseDoubleMap(splitPayload?['sharesSplits'] ?? json['sharesSplits']),
      adjustmentSplits: parseDoubleMap(
          splitPayload?['adjustmentSplits'] ?? json['adjustmentSplits']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cohort_id': cohortId,
      'title': title,
      'category': category,
      if (customIcon != null) 'custom_icon': customIcon,
      'amount': amount,
      'paid_by_user_id': paidByUserId,
      'split_type': splitType,
      'split_payload': {
        if (isMultiplePayers != null) 'isMultiplePayers': isMultiplePayers,
        if (paidAmounts != null) 'paidAmounts': paidAmounts,
        if (includedMemberIds != null) 'includedMemberIds': includedMemberIds,
        if (exactSplits != null) 'exactSplits': exactSplits,
        if (percentageSplits != null) 'percentageSplits': percentageSplits,
        if (sharesSplits != null) 'sharesSplits': sharesSplits,
        if (adjustmentSplits != null) 'adjustmentSplits': adjustmentSplits,
      },
      'created_at': createdAt.toIso8601String(),
    };
  }

  ExpenseShortcut copyWith({
    String? id,
    String? cohortId,
    String? title,
    String? category,
    String? customIcon,
    double? amount,
    String? paidByUserId,
    String? splitType,
    bool? isMultiplePayers,
    Map<String, double>? paidAmounts,
    List<String>? includedMemberIds,
    Map<String, double>? exactSplits,
    Map<String, double>? percentageSplits,
    Map<String, double>? sharesSplits,
    Map<String, double>? adjustmentSplits,
    DateTime? createdAt,
  }) {
    return ExpenseShortcut(
      id: id ?? this.id,
      cohortId: cohortId ?? this.cohortId,
      title: title ?? this.title,
      category: category ?? this.category,
      customIcon: customIcon ?? this.customIcon,
      amount: amount ?? this.amount,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      splitType: splitType ?? this.splitType,
      isMultiplePayers: isMultiplePayers ?? this.isMultiplePayers,
      paidAmounts: paidAmounts ?? this.paidAmounts,
      includedMemberIds: includedMemberIds ?? this.includedMemberIds,
      exactSplits: exactSplits ?? this.exactSplits,
      percentageSplits: percentageSplits ?? this.percentageSplits,
      sharesSplits: sharesSplits ?? this.sharesSplits,
      adjustmentSplits: adjustmentSplits ?? this.adjustmentSplits,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
