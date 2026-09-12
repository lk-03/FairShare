class UserProfile {
  final String id;
  final String? email;
  final String fullName;
  final String? nickname;
  final String? username;
  final String? avatarUrl;
  final String? vpaId; // UPI ID (e.g. name@okaxis)
  final String? phoneNumber;
  final bool isGuest;
  final String? authProvider;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.email,
    required this.fullName,
    this.nickname,
    this.username,
    this.avatarUrl,
    this.vpaId,
    this.phoneNumber,
    this.isGuest = false,
    this.authProvider,
    required this.createdAt,
  });

  String get displayName =>
      nickname?.isNotEmpty == true ? nickname! : fullName;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      nickname: json['nickname'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      vpaId: json['vpa_id'] as String? ?? json['vpaId'] as String?,
      phoneNumber: json['phone_number'] as String? ?? json['phoneNumber'] as String?,
      isGuest: json['is_guest'] as bool? ?? json['isGuest'] as bool? ?? false,
      authProvider: json['auth_provider'] as String? ?? json['authProvider'] as String?,
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
      if (email != null) 'email': email,
      'full_name': fullName,
      if (nickname != null) 'nickname': nickname,
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (vpaId != null) 'vpa_id': vpaId,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'is_guest': isGuest,
      if (authProvider != null) 'auth_provider': authProvider,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? nickname,
    String? username,
    String? avatarUrl,
    String? vpaId,
    String? phoneNumber,
    bool? isGuest,
    String? authProvider,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      vpaId: vpaId ?? this.vpaId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isGuest: isGuest ?? this.isGuest,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
