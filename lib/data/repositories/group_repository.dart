import 'dart:math';
import '../../core/models/group.dart';
import '../../core/models/group_member.dart';
import '../../core/models/profile.dart';
import '../local/local_cache_service.dart';
import '../services/supabase_service.dart';
import 'profile_repository.dart';

String generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random();
  return List.generate(6, (index) => chars[rnd.nextInt(chars.length)]).join();
}

class GroupRepository {
  final SupabaseService supabaseService;
  final ProfileRepository profileRepository;
  final LocalCacheService cacheService;

  GroupRepository({
    required this.supabaseService,
    required this.profileRepository,
    required this.cacheService,
  });

  /// Fetches all cohorts that the user belongs to along with member rosters
  Future<({List<Group> cohorts, Map<String, List<GroupMember>> members})>
      fetchUserCohorts(String userId) async {
    if (!supabaseService.isConfigured || !isUuid(userId)) {
      final cachedCohorts = cacheService.getCachedGroups();
      final Map<String, List<GroupMember>> cachedMembers = {};
      for (final c in cachedCohorts) {
        cachedMembers[c.id] = cacheService.getCachedMembers(c.id);
      }
      return (cohorts: cachedCohorts, members: cachedMembers);
    }

    try {
      // 1. Get all cohort IDs the user is a member of
      final memberRows = await supabaseService.client
          .from('group_members')
          .select('cohort_id')
          .eq('user_id', userId);

      final cohortIds = (memberRows as List)
          .map((r) => r['cohort_id'] as String?)
          .whereType<String>()
          .toList();

      if (cohortIds.isEmpty) {
        return (cohorts: <Group>[], members: <String, List<GroupMember>>{});
      }

      // 2. Fetch cohort details
      final cohortRows = await supabaseService.client
          .from('cohorts')
          .select('*')
          .inFilter('id', cohortIds)
          .order('created_at', ascending: false);

      // 3. Fetch all members across these cohorts with user profiles
      final allMembersRows = await supabaseService.client
          .from('group_members')
          .select('*, profiles:user_id(*)')
          .inFilter('cohort_id', cohortIds);

      final Map<String, List<GroupMember>> membersMap = {};
      for (final cid in cohortIds) {
        membersMap[cid] = [];
      }

      for (final m in (allMembersRows as List)) {
        final member = GroupMember.fromJson(m as Map<String, dynamic>);
        membersMap[member.cohortId]?.add(member);
      }

      final List<Group> cohorts = (cohortRows as List).map((c) {
        final raw = c as Map<String, dynamic>;
        final group = Group.fromJson(raw);
        final roster = membersMap[group.id] ?? [];
        return group.copyWith(members: roster);
      }).toList();

      // Persist to local cache
      await cacheService.saveGroups(cohorts);
      for (final entry in membersMap.entries) {
        await cacheService.saveMembers(entry.key, entry.value);
      }

      return (cohorts: cohorts, members: membersMap);
    } catch (_) {
      final cachedCohorts = cacheService.getCachedGroups();
      final Map<String, List<GroupMember>> cachedMembers = {};
      for (final c in cachedCohorts) {
        cachedMembers[c.id] = cacheService.getCachedMembers(c.id);
      }
      return (cohorts: cachedCohorts, members: cachedMembers);
    }
  }

  /// Creates a new cohort and adds the creator as admin
  Future<({Group cohort, GroupMember member})> createCohort(
    Group cohort,
    UserProfile creator,
  ) async {
    UserProfile effectiveCreator = creator;
    if (!isUuid(effectiveCreator.id)) {
      effectiveCreator = await profileRepository.getCurrentProfile();
    }

    final inviteCode =
        cohort.inviteCode.isNotEmpty ? cohort.inviteCode : generateInviteCode();

    final fallbackMember = GroupMember(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      cohortId: cohort.id,
      userId: effectiveCreator.id,
      role: 'admin',
      joinedAt: DateTime.now(),
      profile: effectiveCreator,
    );

    final updatedCohort = cohort.copyWith(
      inviteCode: inviteCode,
      createdBy: effectiveCreator.id,
      members: [fallbackMember],
    );

    if (!supabaseService.isConfigured || !isUuid(effectiveCreator.id)) {
      final groups = cacheService.getCachedGroups();
      await cacheService.saveGroups([updatedCohort, ...groups]);
      await cacheService.saveMembers(updatedCohort.id, [fallbackMember]);
      return (cohort: updatedCohort, member: fallbackMember);
    }

    try {
      final insertData = <String, dynamic>{
        if (isUuid(cohort.id)) 'id': cohort.id,
        'name': cohort.name,
        'description': cohort.description,
        'category': cohort.category,
        'custom_icon': cohort.customIcon,
        'avatar_url': cohort.avatarUrl ?? cohort.bannerUrl,
        'banner_url': cohort.bannerUrl ?? cohort.avatarUrl,
        'currency': cohort.currency,
        'invite_code': inviteCode,
        'created_by': effectiveCreator.id,
      };

      final cohortRow = await supabaseService.client
          .from('cohorts')
          .insert(insertData)
          .select()
          .single();

      final savedCohort = Group.fromJson(cohortRow);

      // Insert creator into group_members
      final memberRow = await supabaseService.client
          .from('group_members')
          .insert({
            'cohort_id': savedCohort.id,
            'user_id': effectiveCreator.id,
            'role': 'admin',
          })
          .select('*, profiles:user_id(*)')
          .single();

      final savedMember = GroupMember.fromJson(memberRow);
      final finalCohort = savedCohort.copyWith(members: [savedMember]);

      // Update cache
      final groups = cacheService.getCachedGroups();
      await cacheService.saveGroups([finalCohort, ...groups]);
      await cacheService.saveMembers(finalCohort.id, [savedMember]);

      return (cohort: finalCohort, member: savedMember);
    } catch (_) {
      final groups = cacheService.getCachedGroups();
      await cacheService.saveGroups([updatedCohort, ...groups]);
      await cacheService.saveMembers(updatedCohort.id, [fallbackMember]);
      return (cohort: updatedCohort, member: fallbackMember);
    }
  }

  /// Updates cohort metadata
  Future<void> updateCohort(String cohortId, Map<String, dynamic> updates) async {
    // Update local cache first
    final groups = cacheService.getCachedGroups();
    final updatedGroups = groups.map((g) {
      if (g.id == cohortId) {
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
    await cacheService.saveGroups(updatedGroups);

    if (!supabaseService.isConfigured || !isUuid(cohortId)) return;

    try {
      final dbPayload = <String, dynamic>{
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabaseService.client
          .from('cohorts')
          .update(dbPayload)
          .eq('id', cohortId);
    } catch (_) {}
  }

  /// Joins a cohort by invite code
  Future<({Group cohort, GroupMember member, List<GroupMember> members})?>
      joinCohortByInviteCode(String rawInviteCode, UserProfile user) async {
    final cleanCode = rawInviteCode
        .replaceAll(RegExp(r'^(fairshare://join/|https?://[^/]+/join/)', caseSensitive: false), '')
        .trim()
        .toUpperCase();

    UserProfile effectiveUser = user;
    if (!isUuid(effectiveUser.id)) {
      effectiveUser = await profileRepository.getCurrentProfile();
    }

    if (!supabaseService.isConfigured || !isUuid(effectiveUser.id)) {
      final cached = cacheService.getCachedGroups().where(
            (c) => c.inviteCode.toUpperCase() == cleanCode,
          );
      if (cached.isNotEmpty) {
        final cohort = cached.first;
        final member = GroupMember(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}',
          cohortId: cohort.id,
          userId: effectiveUser.id,
          role: 'member',
          joinedAt: DateTime.now(),
          profile: effectiveUser,
        );
        final members = [...cacheService.getCachedMembers(cohort.id), member];
        await cacheService.saveMembers(cohort.id, members);
        return (cohort: cohort, member: member, members: members);
      }
      return null;
    }

    try {
      // 1. Find cohort by invite_code or fallback by ID if UUID
      var query = supabaseService.client
          .from('cohorts')
          .select('*')
          .ilike('invite_code', cleanCode);

      var cohortRow = await query.maybeSingle();

      if (cohortRow == null && isUuid(cleanCode)) {
        cohortRow = await supabaseService.client
            .from('cohorts')
            .select('*')
            .eq('id', cleanCode)
            .maybeSingle();
      }

      if (cohortRow == null) return null;

      final cohort = Group.fromJson(cohortRow);

      // 2. Ensure user profile is registered before foreign key insertion
      await supabaseService.client.from('profiles').upsert({
        'id': effectiveUser.id,
        'email': effectiveUser.email,
        'full_name': effectiveUser.displayName,
        'avatar_url': effectiveUser.avatarUrl,
        'nickname': effectiveUser.nickname,
        'vpa_id': effectiveUser.vpaId,
        'is_guest': false,
        'auth_provider': effectiveUser.authProvider ?? 'email',
      });

      // 3. Upsert into group_members
      final memberRow = await supabaseService.client
          .from('group_members')
          .upsert(
            {
              'cohort_id': cohort.id,
              'user_id': effectiveUser.id,
              'role': 'member',
            },
            onConflict: 'cohort_id,user_id',
          )
          .select('*, profiles:user_id(*)')
          .single();

      final member = GroupMember.fromJson(memberRow);

      // 4. Fetch all active members in this cohort
      final allMembersData = await supabaseService.client
          .from('group_members')
          .select('*, profiles:user_id(*)')
          .eq('cohort_id', cohort.id);

      final membersList = (allMembersData as List)
          .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
          .toList();

      final finalCohort = cohort.copyWith(members: membersList);

      // Update cache
      final groups = cacheService.getCachedGroups();
      if (!groups.any((g) => g.id == finalCohort.id)) {
        await cacheService.saveGroups([finalCohort, ...groups]);
      }
      await cacheService.saveMembers(finalCohort.id, membersList);

      return (cohort: finalCohort, member: member, members: membersList);
    } catch (_) {
      return null;
    }
  }

  /// Adds or updates multiple members (for CSV/contacts import)
  Future<List<GroupMember>> addMembersToCohort(
    String cohortId,
    List<GroupMember> newMembers,
  ) async {
    if (newMembers.isEmpty) return [];

    final currentMembers = cacheService.getCachedMembers(cohortId);
    final merged = [...currentMembers];
    for (final nm in newMembers) {
      if (!merged.any((m) => m.userId == nm.userId)) {
        merged.add(nm);
      }
    }
    await cacheService.saveMembers(cohortId, merged);

    if (!supabaseService.isConfigured || !isUuid(cohortId)) {
      return newMembers;
    }

    try {
      final payload = newMembers
          .where((m) => isUuid(m.userId))
          .map((m) => {
                'cohort_id': cohortId,
                'user_id': m.userId,
                'role': m.role,
                'is_placeholder': m.isPlaceholder,
                'original_csv_name': m.originalCsvName,
              })
          .toList();

      if (payload.isEmpty) return newMembers;

      final data = await supabaseService.client
          .from('group_members')
          .upsert(payload, onConflict: 'cohort_id,user_id')
          .select('*, profiles:user_id(*)');

      final saved = (data as List)
          .map((r) => GroupMember.fromJson(r as Map<String, dynamic>))
          .toList();

      return saved;
    } catch (_) {
      return newMembers;
    }
  }

  /// Removes a member from a cohort
  Future<bool> removeMemberFromCohort(String cohortId, String userId) async {
    final currentMembers = cacheService.getCachedMembers(cohortId);
    final updatedMembers =
        currentMembers.where((m) => m.userId != userId).toList();
    await cacheService.saveMembers(cohortId, updatedMembers);

    if (!supabaseService.isConfigured || !isUuid(cohortId) || !isUuid(userId)) {
      return true;
    }

    try {
      await supabaseService.client
          .from('group_members')
          .delete()
          .eq('cohort_id', cohortId)
          .eq('user_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Updates a member's role (admin / member)
  Future<bool> updateMemberRole(
    String cohortId,
    String userId,
    String role,
  ) async {
    final currentMembers = cacheService.getCachedMembers(cohortId);
    final updatedMembers = currentMembers.map((m) {
      if (m.userId == userId) {
        return m.copyWith(role: role);
      }
      return m;
    }).toList();
    await cacheService.saveMembers(cohortId, updatedMembers);

    if (!supabaseService.isConfigured || !isUuid(cohortId) || !isUuid(userId)) {
      return true;
    }

    try {
      await supabaseService.client
          .from('group_members')
          .update({'role': role})
          .eq('cohort_id', cohortId)
          .eq('user_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggles archive status for a cohort
  Future<bool> toggleArchiveCohort(String cohortId, bool isArchived) async {
    final groups = cacheService.getCachedGroups();
    final updated = groups.map((g) {
      if (g.id == cohortId) {
        return g.copyWith(
          isArchived: isArchived,
          archivedAt: isArchived ? DateTime.now() : null,
          updatedAt: DateTime.now(),
        );
      }
      return g;
    }).toList();
    await cacheService.saveGroups(updated);

    if (!supabaseService.isConfigured || !isUuid(cohortId)) return true;

    try {
      await supabaseService.client.from('cohorts').update({
        'is_archived': isArchived,
        'archived_at': isArchived ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', cohortId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Soft deletes a cohort (moves to trash for 15-day recovery)
  Future<bool> deleteCohort(String cohortId) async {
    final groups = cacheService.getCachedGroups();
    final now = DateTime.now();
    final updated = groups.map((g) {
      if (g.id == cohortId) {
        return g.copyWith(isDeleted: true, deletedAt: now, updatedAt: now);
      }
      return g;
    }).toList();
    await cacheService.saveGroups(updated);

    if (!supabaseService.isConfigured || !isUuid(cohortId)) return true;

    try {
      await supabaseService.client.from('cohorts').update({
        'is_deleted': true,
        'deleted_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', cohortId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restores a deleted cohort back from trash
  Future<bool> restoreDeletedCohort(String cohortId) async {
    final groups = cacheService.getCachedGroups();
    final now = DateTime.now();
    final updated = groups.map((g) {
      if (g.id == cohortId) {
        return g.copyWith(isDeleted: false, deletedAt: null, updatedAt: now);
      }
      return g;
    }).toList();
    await cacheService.saveGroups(updated);

    if (!supabaseService.isConfigured || !isUuid(cohortId)) return true;

    try {
      await supabaseService.client.from('cohorts').update({
        'is_deleted': false,
        'deleted_at': null,
        'updated_at': now.toIso8601String(),
      }).eq('id', cohortId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Permanently deletes a cohort and all related records from DB & cache
  Future<bool> deleteCohortPermanently(String cohortId) async {
    final groups = cacheService.getCachedGroups();
    await cacheService.saveGroups(groups.where((g) => g.id != cohortId).toList());
    await cacheService.saveMembers(cohortId, []);
    await cacheService.saveExpenses(cohortId, []);
    await cacheService.saveNeeds(cohortId, []);
    await cacheService.saveShortcuts(cohortId, []);

    if (!supabaseService.isConfigured || !isUuid(cohortId)) return true;

    try {
      await supabaseService.client.from('expenses').delete().eq('cohort_id', cohortId);
      await supabaseService.client.from('shared_list_items').delete().eq('cohort_id', cohortId);
      await supabaseService.client.from('expense_shortcuts').delete().eq('cohort_id', cohortId);
      await supabaseService.client.from('group_members').delete().eq('cohort_id', cohortId);
      await supabaseService.client.from('cohorts').delete().eq('id', cohortId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Automatically purges cohorts that have been in trash for > 15 days
  Future<List<String>> purgeExpiredDeletedCohorts(List<Group> cohorts) async {
    const fifteenDays = Duration(days: 15);
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final c in cohorts) {
      if (c.isDeleted && c.deletedAt != null) {
        if (now.difference(c.deletedAt!) >= fifteenDays) {
          expiredIds.add(c.id);
          await deleteCohortPermanently(c.id);
        }
      }
    }
    return expiredIds;
  }
}
