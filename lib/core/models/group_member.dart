import 'profile.dart';

class GroupMember {
  final String id;
  final String cohortId;
  final String userId;
  final String role; // 'admin' | 'member'
  final DateTime joinedAt;
  final UserProfile? profile;
  final bool isPlaceholder;
  final String? originalCsvName;

  const GroupMember({
    required this.id,
    required this.cohortId,
    required this.userId,
    this.role = 'member',
    required this.joinedAt,
    this.profile,
    this.isPlaceholder = false,
    this.originalCsvName,
  });

  bool get isAdmin => role == 'admin';

  String get displayName =>
      profile?.displayName ?? originalCsvName ?? 'Member';

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString()) ?? DateTime.now()
          : (json['joinedAt'] != null
              ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      profile: json['profile'] != null && json['profile'] is Map<String, dynamic>
          ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      isPlaceholder: json['is_placeholder'] as bool? ??
          json['isPlaceholder'] as bool? ??
          false,
      originalCsvName: json['original_csv_name'] as String? ??
          json['originalCsvName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cohort_id': cohortId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      if (profile != null) 'profile': profile!.toJson(),
      'is_placeholder': isPlaceholder,
      if (originalCsvName != null) 'original_csv_name': originalCsvName,
    };
  }

  GroupMember copyWith({
    String? id,
    String? cohortId,
    String? userId,
    String? role,
    DateTime? joinedAt,
    UserProfile? profile,
    bool? isPlaceholder,
    String? originalCsvName,
  }) {
    return GroupMember(
      id: id ?? this.id,
      cohortId: cohortId ?? this.cohortId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      profile: profile ?? this.profile,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      originalCsvName: originalCsvName ?? this.originalCsvName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
