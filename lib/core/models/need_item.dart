class NeedItem {
  final String id;
  final String cohortId;
  final String title;
  final String addedByUserId;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String? addedByName;

  const NeedItem({
    required this.id,
    required this.cohortId,
    required this.title,
    required this.addedByUserId,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    this.addedByName,
  });

  /// True if item is unchecked and was created 5 or more days ago
  bool get isStale {
    if (isCompleted) return false;
    final now = DateTime.now();
    return now.difference(createdAt).inDays >= 5;
  }

  int get daysOld {
    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  factory NeedItem.fromJson(Map<String, dynamic> json) {
    return NeedItem(
      id: json['id'] as String,
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      addedByUserId: json['added_by_user_id'] as String? ??
          json['addedByUserId'] as String? ??
          '',
      isCompleted: json['is_completed'] as bool? ??
          json['isCompleted'] as bool? ??
          false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : (json['completedAt'] != null
              ? DateTime.tryParse(json['completedAt'].toString())
              : null),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      addedByName: json['added_by_name'] as String? ?? json['addedByName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cohort_id': cohortId,
      'title': title,
      'added_by_user_id': addedByUserId,
      'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  NeedItem copyWith({
    String? id,
    String? cohortId,
    String? title,
    String? addedByUserId,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    String? addedByName,
  }) {
    return NeedItem(
      id: id ?? this.id,
      cohortId: cohortId ?? this.cohortId,
      title: title ?? this.title,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      addedByName: addedByName ?? this.addedByName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NeedItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
