import 'profile.dart';

enum FriendshipStatus {
  pending,
  accepted,
  declined,
  blocked;

  static FriendshipStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'declined':
        return FriendshipStatus.declined;
      case 'blocked':
        return FriendshipStatus.blocked;
      case 'accepted':
      default:
        return FriendshipStatus.accepted;
    }
  }

  String toDbValue() => name;
}

class Friend {
  final String id; // friendship ID or local_friend_...
  final String friendUserId; // ID of the other user profile
  final UserProfile profile; // friend profile details
  final FriendshipStatus status;
  final String createdBy;
  final bool isLocal;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Friend({
    required this.id,
    required this.friendUserId,
    required this.profile,
    this.status = FriendshipStatus.accepted,
    this.createdBy = '',
    this.isLocal = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => profile.displayName;
  String get initials => profile.initials;
  String? get avatarUrl => profile.avatarUrl;
  String? get vpaId => profile.vpaId;
  String? get upiId => profile.vpaId;
  String? get email => profile.email;
  String? get username => profile.username;
  bool get isLocalContact => isLocal;
  String get emailOrHandle {
    if (email != null && email!.isNotEmpty) return email!;
    if (username != null && username!.isNotEmpty) return '@$username';
    return '';
  }

  Friend copyWith({
    String? id,
    String? friendUserId,
    UserProfile? profile,
    FriendshipStatus? status,
    String? createdBy,
    bool? isLocal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Friend(
      id: id ?? this.id,
      friendUserId: friendUserId ?? this.friendUserId,
      profile: profile ?? this.profile,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      isLocal: isLocal ?? this.isLocal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Friend.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final friendshipId = json['id'] as String? ?? '';
    final isLocal = json['is_local'] as bool? ??
        json['isLocal'] as bool? ??
        friendshipId.startsWith('local_');

    final userId1 = json['user_id_1'] as String? ?? '';
    final userId2 = json['user_id_2'] as String? ?? '';

    String friendUid = '';
    if (json['friend_user_id'] != null) {
      friendUid = json['friend_user_id'] as String;
    } else if (currentUserId != null && currentUserId == userId1) {
      friendUid = userId2;
    } else if (currentUserId != null && currentUserId == userId2) {
      friendUid = userId1;
    } else {
      friendUid = json['user_id'] as String? ?? userId2;
    }

    UserProfile prof;
    if (json['profile'] != null && json['profile'] is Map) {
      prof = UserProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      );
    } else if (json['profiles'] != null && json['profiles'] is Map) {
      prof = UserProfile.fromJson(
        Map<String, dynamic>.from(json['profiles'] as Map),
      );
    } else {
      prof = UserProfile(
        id: friendUid.isNotEmpty ? friendUid : 'profile_$friendshipId',
        fullName: json['full_name'] as String? ??
            json['name'] as String? ??
            'Friend',
        username: json['username'] as String?,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        vpaId: json['vpa_id'] as String?,
        phoneNumber: json['phone_number'] as String?,
        createdAt: DateTime.now(),
      );
    }

    return Friend(
      id: friendshipId,
      friendUserId: friendUid.isNotEmpty ? friendUid : prof.id,
      profile: prof,
      status: FriendshipStatus.fromString(json['status'] as String?),
      createdBy: json['created_by'] as String? ?? '',
      isLocal: isLocal,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friend_user_id': friendUserId,
      'profile': profile.toJson(),
      'status': status.toDbValue(),
      'created_by': createdBy,
      'is_local': isLocal,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
