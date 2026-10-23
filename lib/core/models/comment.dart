import 'profile.dart';

/// Represents a discussion comment or system audit log attached to an expense or cohort
class TransactionComment {
  final String id;
  final String? expenseId;
  final String? cohortId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final UserProfile? profile;

  const TransactionComment({
    required this.id,
    this.expenseId,
    this.cohortId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.profile,
  });

  factory TransactionComment.fromJson(Map<String, dynamic> json) {
    UserProfile? profile;
    final rawProfile = json['profiles'] ?? json['profile'];
    if (rawProfile != null && rawProfile is Map<String, dynamic>) {
      profile = UserProfile.fromJson(rawProfile);
    }

    return TransactionComment(
      id: json['id'] as String? ?? '',
      expenseId: json['expense_id'] as String? ?? json['expenseId'] as String?,
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String?,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      profile: profile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (expenseId != null) 'expense_id': expenseId,
      if (cohortId != null) 'cohort_id': cohortId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      if (profile != null) 'profiles': profile!.toJson(),
    };
  }

  TransactionComment copyWith({
    String? id,
    String? expenseId,
    String? cohortId,
    String? userId,
    String? content,
    DateTime? createdAt,
    UserProfile? profile,
  }) {
    return TransactionComment(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      cohortId: cohortId ?? this.cohortId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      profile: profile ?? this.profile,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionComment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
