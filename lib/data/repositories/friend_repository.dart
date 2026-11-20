import 'package:flutter/foundation.dart';
import '../../core/models/friend.dart';
import '../../core/models/profile.dart';
import '../local/local_cache_service.dart';
import '../services/supabase_service.dart';
import 'profile_repository.dart';

class FriendRepository {
  final SupabaseService supabaseService;
  final ProfileRepository profileRepository;
  final LocalCacheService cacheService;

  FriendRepository({
    required this.supabaseService,
    required this.profileRepository,
    required this.cacheService,
  });

  /// Fetches all friends (both cloud friendships and local offline contacts)
  Future<List<Friend>> fetchFriends(String currentUserId) async {
    final cached = cacheService.getCachedFriends(currentUserId: currentUserId);
    final localFriends = cached.where((f) => f.isLocal).toList();

    if (!supabaseService.isConfigured || !isUuid(currentUserId)) {
      return cached;
    }

    try {
      final rows = await supabaseService.client
          .from('friendships')
          .select('*, profile_1:user_id_1(*), profile_2:user_id_2(*)')
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId')
          .order('created_at', ascending: false);

      final List<Friend> cloudFriends = [];
      for (final raw in (rows as List)) {
        final map = raw as Map<String, dynamic>;
        final uid1 = map['user_id_1'] as String? ?? '';
        final isUser1 = uid1 == currentUserId;
        final friendProfileMap = isUser1 ? map['profile_2'] : map['profile_1'];

        Map<String, dynamic> friendJson = Map<String, dynamic>.from(map);
        if (friendProfileMap != null && friendProfileMap is Map) {
          friendJson['profile'] = friendProfileMap;
        }

        cloudFriends.add(Friend.fromJson(friendJson, currentUserId: currentUserId));
      }

      // Merge cloud friends and preserve offline local contacts
      final combinedMap = <String, Friend>{};
      for (final f in cloudFriends) {
        combinedMap[f.id] = f;
      }
      for (final f in localFriends) {
        combinedMap.putIfAbsent(f.id, () => f);
      }

      final result = combinedMap.values.toList();
      await cacheService.saveFriends(result);
      return result;
    } catch (e) {
      debugPrint('Error fetching friends from Supabase: $e');
      return cached;
    }
  }

  /// Searches for registered users in public.profiles by username, email, or name
  Future<List<UserProfile>> searchProfiles(String query, {String? excludeUserId}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || !supabaseService.isConfigured) return [];

    try {
      final rows = await supabaseService.client
          .from('profiles')
          .select('*')
          .or('username.ilike.%$q%,email.ilike.%$q%,full_name.ilike.%$q%')
          .limit(20);

      final profiles = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => UserProfile.fromJson(m))
          .where((p) => excludeUserId == null || p.id != excludeUserId)
          .toList();

      return profiles;
    } catch (e) {
      debugPrint('Error searching profiles: $e');
      return [];
    }
  }

  /// Adds a friend: creates a cloud friendship or a local offline contact
  Future<Friend> addFriend({
    required String currentUserId,
    String? friendUserId,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? vpaId,
  }) async {
    // 1. If friendUserId provided and cloud configured, create mutual friendship
    if (friendUserId != null &&
        supabaseService.isConfigured &&
        isUuid(currentUserId) &&
        isUuid(friendUserId)) {
      try {
        final uid1 = currentUserId.compareTo(friendUserId) < 0 ? currentUserId : friendUserId;
        final uid2 = currentUserId.compareTo(friendUserId) < 0 ? friendUserId : currentUserId;

        // Check if a friendship record already exists between uid1 and uid2
        final existing = await supabaseService.client
            .from('friendships')
            .select('*, profile_1:user_id_1(*), profile_2:user_id_2(*)')
            .eq('user_id_1', uid1)
            .eq('user_id_2', uid2)
            .maybeSingle();

        Map<String, dynamic> map;
        if (existing != null) {
          final existingStatus = existing['status'] as String? ?? 'pending';
          final existingCreatedBy = existing['created_by'] as String? ?? '';

          if (existingStatus == 'pending' && existingCreatedBy != currentUserId) {
            // Other user had already requested current user!
            // Both have requested / current user accepts -> status becomes 'accepted'
            map = await supabaseService.client
                .from('friendships')
                .update({
                  'status': 'accepted',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existing['id'])
                .select('*, profile_1:user_id_1(*), profile_2:user_id_2(*)')
                .single();
          } else if (existingStatus == 'declined') {
            // Re-requesting after previous decline
            map = await supabaseService.client
                .from('friendships')
                .update({
                  'status': 'pending',
                  'created_by': currentUserId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existing['id'])
                .select('*, profile_1:user_id_1(*), profile_2:user_id_2(*)')
                .single();
          } else {
            map = existing;
          }
        } else {
          // Create new pending friendship request
          map = await supabaseService.client
              .from('friendships')
              .insert({
                'user_id_1': uid1,
                'user_id_2': uid2,
                'status': 'pending',
                'created_by': currentUserId,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select('*, profile_1:user_id_1(*), profile_2:user_id_2(*)')
              .single();
        }
        final isUser1 = uid1 == currentUserId;
        final friendProfileMap = isUser1 ? map['profile_2'] : map['profile_1'];

        Map<String, dynamic> friendJson = Map<String, dynamic>.from(map);
        if (friendProfileMap != null && friendProfileMap is Map) {
          friendJson['profile'] = friendProfileMap;
        }

        final friend = Friend.fromJson(friendJson, currentUserId: currentUserId);

        final currentFriends = cacheService.getCachedFriends(currentUserId: currentUserId);
        final updated = [friend, ...currentFriends.where((f) => f.id != friend.id)];
        await cacheService.saveFriends(updated);

        return friend;
      } catch (e) {
        debugPrint('Error creating cloud friendship: $e');
      }
    }

    // 2. Offline / Local Contact Friend fallback
    final now = DateTime.now();
    final localId = 'local_friend_${now.millisecondsSinceEpoch}';
    final localProfileId = 'local_user_${now.millisecondsSinceEpoch}';

    final cleanName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : ((username != null && username.trim().isNotEmpty)
            ? username.trim()
            : ((email != null && email.trim().isNotEmpty) ? email.split('@').first : 'Friend'));

    final localProfile = UserProfile(
      id: localProfileId,
      fullName: cleanName,
      username: username?.trim(),
      email: email?.trim(),
      phoneNumber: phone?.trim(),
      vpaId: vpaId?.trim(),
      createdAt: now,
    );

    final localFriend = Friend(
      id: localId,
      friendUserId: localProfileId,
      profile: localProfile,
      status: FriendshipStatus.accepted,
      createdBy: currentUserId,
      isLocal: true,
      createdAt: now,
      updatedAt: now,
    );

    final currentFriends = cacheService.getCachedFriends(currentUserId: currentUserId);
    await cacheService.saveFriends([localFriend, ...currentFriends]);
    return localFriend;
  }

  /// Accepts an incoming friend request
  Future<bool> acceptFriendRequest(String friendshipId, {String? currentUserId}) async {
    if (supabaseService.isConfigured && isUuid(friendshipId)) {
      try {
        await supabaseService.client.from('friendships').update({
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', friendshipId);

        if (currentUserId != null) {
          final currentFriends = cacheService.getCachedFriends(currentUserId: currentUserId);
          final updated = currentFriends.map((f) {
            if (f.id == friendshipId) {
              return f.copyWith(
                status: FriendshipStatus.accepted,
                updatedAt: DateTime.now(),
              );
            }
            return f;
          }).toList();
          await cacheService.saveFriends(updated);
        }
        return true;
      } catch (e) {
        debugPrint('Error accepting friend request: $e');
        return false;
      }
    } else if (currentUserId != null) {
      // Offline/local fallback
      final currentFriends = cacheService.getCachedFriends(currentUserId: currentUserId);
      final updated = currentFriends.map((f) {
        if (f.id == friendshipId) {
          return f.copyWith(
            status: FriendshipStatus.accepted,
            updatedAt: DateTime.now(),
          );
        }
        return f;
      }).toList();
      await cacheService.saveFriends(updated);
      return true;
    }
    return false;
  }

  /// Declines an incoming friend request
  Future<bool> declineFriendRequest(String friendshipId, {String? currentUserId}) async {
    if (supabaseService.isConfigured && isUuid(friendshipId)) {
      try {
        await supabaseService.client.from('friendships').update({
          'status': 'declined',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', friendshipId);

        if (currentUserId != null) {
          final currentFriends = cacheService.getCachedFriends(currentUserId: currentUserId);
          final updated = currentFriends.where((f) => f.id != friendshipId).toList();
          await cacheService.saveFriends(updated);
        }
        return true;
      } catch (e) {
        debugPrint('Error declining friend request: $e');
        return false;
      }
    } else if (currentUserId != null) {
      // Offline/local fallback
      final currentFriends = cacheService.getCachedFriends(currentUserId: currentUserId);
      final updated = currentFriends.where((f) => f.id != friendshipId).toList();
      await cacheService.saveFriends(updated);
      return true;
    }
    return false;
  }

  /// Cancels an outgoing pending friend request
  Future<bool> cancelFriendRequest(String friendshipId, {String? currentUserId}) async {
    return removeFriend(friendshipId, currentUserId: currentUserId);
  }

  /// Removes a friendship or local contact
  Future<bool> removeFriend(String friendshipId, {String? currentUserId}) async {
    final currentFriends = cacheService.getCachedFriends(currentUserId: currentUserId);
    final updated = currentFriends.where((f) => f.id != friendshipId).toList();
    await cacheService.saveFriends(updated);

    if (supabaseService.isConfigured && isUuid(friendshipId)) {
      try {
        await supabaseService.client
            .from('friendships')
            .delete()
            .eq('id', friendshipId);
        return true;
      } catch (e) {
        debugPrint('Error deleting friendship: $e');
        return false;
      }
    }
    return true;
  }
}
