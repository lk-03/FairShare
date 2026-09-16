import 'group_member.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String category; // 'trip', 'house', 'event', 'dining', etc.
  final String? customIcon;
  final String? bannerUrl;
  final String? avatarUrl;
  final String currency;
  final String createdBy;
  final String inviteCode;
  final bool isArchived;
  final DateTime? archivedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GroupMember> members;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.category = 'trip',
    this.customIcon,
    this.bannerUrl,
    this.avatarUrl,
    this.currency = 'INR',
    required this.createdBy,
    required this.inviteCode,
    this.isArchived = false,
    this.archivedAt,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.members = const [],
  });

  int get memberCount => members.length;

  /// Returns remaining days before permanent purge if [isDeleted] is true
  int get daysUntilPermanentDeletion {
    if (!isDeleted || deletedAt == null) return 15;
    final deadline = deletedAt!.add(const Duration(days: 15));
    final diff = deadline.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    var rawMembers = json['members'] ?? json['cohort_members'];
    List<GroupMember> parsedMembers = [];
    if (rawMembers != null && rawMembers is List) {
      parsedMembers = rawMembers
          .whereType<Map<String, dynamic>>()
          .map((m) => GroupMember.fromJson(m))
          .toList();
    }

    return Group(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'trip',
      customIcon: json['custom_icon'] as String? ?? json['customIcon'] as String?,
      bannerUrl: json['banner_url'] as String? ?? json['bannerUrl'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      currency: json['currency'] as String? ?? 'INR',
      createdBy: json['created_by'] as String? ?? json['createdBy'] as String? ?? '',
      inviteCode: json['invite_code'] as String? ?? json['inviteCode'] as String? ?? '',
      isArchived: json['is_archived'] as bool? ?? json['isArchived'] as bool? ?? false,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'].toString())
          : (json['archivedAt'] != null
              ? DateTime.tryParse(json['archivedAt'].toString())
              : null),
      isDeleted: json['is_deleted'] as bool? ?? json['isDeleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : (json['deletedAt'] != null
              ? DateTime.tryParse(json['deletedAt'].toString())
              : null),
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
      members: parsedMembers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'category': category,
      if (customIcon != null) 'custom_icon': customIcon,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'currency': currency,
      'created_by': createdBy,
      'invite_code': inviteCode,
      'is_archived': isArchived,
      if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
      'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (members.isNotEmpty) 'members': members.map((m) => m.toJson()).toList(),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? customIcon,
    String? bannerUrl,
    String? avatarUrl,
    String? currency,
    String? createdBy,
    String? inviteCode,
    bool? isArchived,
    DateTime? archivedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<GroupMember>? members,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      customIcon: customIcon ?? this.customIcon,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currency: currency ?? this.currency,
      createdBy: createdBy ?? this.createdBy,
      inviteCode: inviteCode ?? this.inviteCode,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
