import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/group.dart';
import '../../core/models/group_member.dart';
import '../../core/models/comment.dart';
import '../repositories/group_repository.dart';
import 'auth_provider.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final cache = ref.watch(localCacheServiceProvider);
  return GroupRepository(
    supabaseService: supabase,
    profileRepository: profileRepo,
    cacheService: cache,
  );
});

class GroupsNotifier extends Notifier<AsyncValue<List<Group>>> {
  @override
  AsyncValue<List<Group>> build() {
    final cache = ref.watch(localCacheServiceProvider);
    final cached = cache.getCachedGroups();
    return AsyncValue.data(cached);
  }

  Future<void> loadUserGroups() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    state = const AsyncValue.loading();
    try {
      final repo = ref.read(groupRepositoryProvider);
      final result = await repo.fetchUserCohorts(currentUser.id);
      state = AsyncValue.data(result.cohorts);

      // Auto-purge any groups in trash > 15 days
      await repo.purgeExpiredDeletedCohorts(result.cohorts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Group> createGroup(Group group) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      throw Exception('Must be logged in or guest to create a group');
    }

    final repo = ref.read(groupRepositoryProvider);
    final result = await repo.createCohort(group, currentUser);

    final currentGroups = state.value ?? [];
    state = AsyncValue.data([result.cohort, ...currentGroups]);
    return result.cohort;
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    final repo = ref.read(groupRepositoryProvider);
    await repo.updateCohort(groupId, updates);

    final currentGroups = state.value ?? [];
    final updated = currentGroups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          name: updates['name'] as String? ?? g.name,
          description: updates['description'] as String? ?? g.description,
          category: updates['category'] as String? ?? g.category,
          customIcon: updates['custom_icon'] as String? ?? g.customIcon,
          avatarUrl: updates['avatar_url'] as String? ?? g.avatarUrl,
          bannerUrl: updates['banner_url'] as String? ?? g.bannerUrl,
          currency: updates['currency'] as String? ?? g.currency,
          createdBy: updates['created_by'] as String? ?? g.createdBy,
        );
      }
      return g;
    }).toList();
    state = AsyncValue.data(updated);
  }

  Future<Group?> joinGroupByInviteCode(String inviteCode) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      throw Exception('Must be logged in to join a group');
    }

    final repo = ref.read(groupRepositoryProvider);
    final result = await repo.joinCohortByInviteCode(inviteCode, currentUser);
    if (result == null) return null;

    final currentGroups = state.value ?? [];
    final filtered = currentGroups.where((g) => g.id != result.cohort.id).toList();
    state = AsyncValue.data([result.cohort, ...filtered]);
    return result.cohort;
  }

  Future<void> toggleArchiveGroup(String groupId) async {
    final currentGroups = state.value ?? [];
    final group = currentGroups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) return;

    final nextArchived = !group.isArchived;
    final repo = ref.read(groupRepositoryProvider);
    await repo.toggleArchiveCohort(groupId, nextArchived);

    final updated = currentGroups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          isArchived: nextArchived,
          archivedAt: nextArchived ? DateTime.now() : null,
          updatedAt: DateTime.now(),
        );
      }
      return g;
    }).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> deleteGroup(String groupId) async {
    final repo = ref.read(groupRepositoryProvider);
    await repo.deleteCohort(groupId);

    final currentGroups = state.value ?? [];
    final now = DateTime.now();
    final updated = currentGroups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isDeleted: true, deletedAt: now, updatedAt: now);
      }
      return g;
    }).toList();
    state = AsyncValue.data(updated);

    // If active group was deleted, reset active group
    final activeId = ref.read(activeGroupIdProvider);
    if (activeId == groupId) {
      ref.read(activeGroupIdProvider.notifier).setActiveGroupId(null);
    }
  }

  Future<void> restoreGroup(String groupId) async {
    final repo = ref.read(groupRepositoryProvider);
    await repo.restoreDeletedCohort(groupId);

    final currentGroups = state.value ?? [];
    final now = DateTime.now();
    final updated = currentGroups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isDeleted: false, deletedAt: null, updatedAt: now);
      }
      return g;
    }).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> deleteGroupPermanently(String groupId) async {
    final repo = ref.read(groupRepositoryProvider);
    await repo.deleteCohortPermanently(groupId);

    final currentGroups = state.value ?? [];
    state = AsyncValue.data(currentGroups.where((g) => g.id != groupId).toList());

    final activeId = ref.read(activeGroupIdProvider);
    if (activeId == groupId) {
      ref.read(activeGroupIdProvider.notifier).setActiveGroupId(null);
    }
  }

  Future<void> kickMember(String groupId, String userId) async {
    final repo = ref.read(groupRepositoryProvider);
    await repo.removeMemberFromCohort(groupId, userId);

    final currentGroups = state.value ?? [];
    final updated = currentGroups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          members: g.members.where((m) => m.userId != userId).toList(),
        );
      }
      return g;
    }).toList();
    state = AsyncValue.data(updated);
  }

  /// Handles leaving a cohort with automatic admin succession if user is admin
  Future<({bool success, String? nextAdminName})> leaveGroup(String groupId) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return (success: false, nextAdminName: null);

    final currentGroups = state.value ?? [];
    final group = currentGroups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) return (success: false, nextAdminName: null);

    final members = group.members;
    final currentMember = members.where((m) => m.userId == currentUser.id).firstOrNull;
    final isAdmin = group.createdBy == currentUser.id || currentMember?.role == 'admin';

    final remaining = members.where(
      (m) => m.userId != currentUser.id && !m.isPlaceholder,
    ).toList();

    if (remaining.isEmpty) {
      // User is the sole member, cannot leave without deleting
      return (success: false, nextAdminName: null);
    }

    final repo = ref.read(groupRepositoryProvider);

    if (isAdmin) {
      // Sort oldest member first
      remaining.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      final nextAdmin = remaining.first;
      final nextAdminName = nextAdmin.profile?.displayName ?? 'A member';

      // 1. Promote nextAdmin to admin
      await repo.updateMemberRole(groupId, nextAdmin.userId, 'admin');
      // 2. Transfer createdBy
      await repo.updateCohort(groupId, {'created_by': nextAdmin.userId});
      // 3. Remove currentUser
      await repo.removeMemberFromCohort(groupId, currentUser.id);

      // System notification comment
      final comment = TransactionComment(
        id: 'comment_sys_${DateTime.now().millisecondsSinceEpoch}',
        cohortId: groupId,
        userId: currentUser.id,
        content:
            'System: ${currentUser.displayName} left the group. $nextAdminName is now the group admin.',
        createdAt: DateTime.now(),
      );
      final cache = ref.read(localCacheServiceProvider);
      final comments = cache.getCachedComments(groupId);
      await cache.saveComments(groupId, [...comments, comment]);

      // Remove from local groups
      state = AsyncValue.data(currentGroups.where((g) => g.id != groupId).toList());
      final activeId = ref.read(activeGroupIdProvider);
      if (activeId == groupId) {
        ref.read(activeGroupIdProvider.notifier).setActiveGroupId(null);
      }

      return (success: true, nextAdminName: nextAdminName);
    } else {
      await repo.removeMemberFromCohort(groupId, currentUser.id);
      state = AsyncValue.data(currentGroups.where((g) => g.id != groupId).toList());
      final activeId = ref.read(activeGroupIdProvider);
      if (activeId == groupId) {
        ref.read(activeGroupIdProvider.notifier).setActiveGroupId(null);
      }
      return (success: true, nextAdminName: null);
    }
  }
}

final groupsProvider =
    NotifierProvider<GroupsNotifier, AsyncValue<List<Group>>>(() {
  return GroupsNotifier();
});

class ActiveGroupIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final cache = ref.watch(localCacheServiceProvider);
    return cache.getActiveGroupId();
  }

  Future<void> setActiveGroupId(String? id) async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.saveActiveGroupId(id);
    state = id;
  }
}

final activeGroupIdProvider =
    NotifierProvider<ActiveGroupIdNotifier, String?>(() {
  return ActiveGroupIdNotifier();
});

final activeGroupProvider = Provider<Group?>((ref) {
  final groups = ref.watch(groupsProvider).value ?? [];
  final activeId = ref.watch(activeGroupIdProvider);
  if (activeId == null) return groups.firstOrNull;
  return groups.where((g) => g.id == activeId).firstOrNull ?? groups.firstOrNull;
});

final groupMembersProvider =
    Provider.family<List<GroupMember>, String>((ref, groupId) {
  final groups = ref.watch(groupsProvider).value ?? [];
  final group = groups.where((g) => g.id == groupId).firstOrNull;
  if (group != null && group.members.isNotEmpty) {
    return group.members;
  }
  final cache = ref.watch(localCacheServiceProvider);
  return cache.getCachedMembers(groupId);
});
