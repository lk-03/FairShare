import 'expense.dart';

enum ActivityType {
  expense,
  comment,
  system,
}

/// Domain model representing an aggregated event in the global activity timeline
class ActivityItem {
  final String id;
  final ActivityType type;
  final DateTime timestamp;
  final String cohortId;
  final String cohortName;
  final String title;
  final double? amount;
  final String meta;
  final String? category;
  final String? customIcon;
  final Expense? rawExpense;
  final String? commentId;
  final String? commentContent;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.cohortId,
    required this.cohortName,
    required this.title,
    this.amount,
    required this.meta,
    this.category,
    this.customIcon,
    this.rawExpense,
    this.commentId,
    this.commentContent,
  });

  ActivityItem copyWith({
    String? id,
    ActivityType? type,
    DateTime? timestamp,
    String? cohortId,
    String? cohortName,
    String? title,
    double? amount,
    String? meta,
    String? category,
    String? customIcon,
    Expense? rawExpense,
    String? commentId,
    String? commentContent,
  }) {
    return ActivityItem(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      cohortId: cohortId ?? this.cohortId,
      cohortName: cohortName ?? this.cohortName,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      meta: meta ?? this.meta,
      category: category ?? this.category,
      customIcon: customIcon ?? this.customIcon,
      rawExpense: rawExpense ?? this.rawExpense,
      commentId: commentId ?? this.commentId,
      commentContent: commentContent ?? this.commentContent,
    );
  }
}
