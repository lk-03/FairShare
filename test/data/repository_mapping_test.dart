import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/need_item.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/repositories/group_repository.dart';
import 'package:fairshare/data/repositories/expense_repository.dart';
import 'package:fairshare/data/repositories/needs_repository.dart';
import 'package:fairshare/data/repositories/profile_repository.dart';
import 'package:fairshare/data/services/supabase_service.dart';

void main() {
  late SharedPreferences prefs;
  late LocalCacheService cacheService;
  late SupabaseService supabaseService;
  late ProfileRepository profileRepo;
  late GroupRepository groupRepo;
  late ExpenseRepository expenseRepo;
  late NeedsRepository needsRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheService = LocalCacheService(prefs);
    supabaseService = SupabaseService();
    profileRepo = ProfileRepository(
      supabaseService: supabaseService,
      cacheService: cacheService,
    );
    groupRepo = GroupRepository(
      supabaseService: supabaseService,
      profileRepository: profileRepo,
      cacheService: cacheService,
    );
    expenseRepo = ExpenseRepository(
      supabaseService: supabaseService,
      profileRepository: profileRepo,
      cacheService: cacheService,
    );
    needsRepo = NeedsRepository(
      supabaseService: supabaseService,
      profileRepository: profileRepo,
      cacheService: cacheService,
    );
  });

  group('Domain & Utility Functions', () {
    test('isUuid validates standard RFC 4122 UUID strings', () {
      expect(isUuid('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'), isTrue);
      expect(isUuid('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11'), isTrue);
      expect(isUuid('not-a-uuid'), isFalse);
      expect(isUuid(''), isFalse);
      expect(isUuid(null), isFalse);
    });

    test('generateInviteCode produces 6-character uppercase alphanumeric code', () {
      final code = generateInviteCode();
      expect(code.length, equals(6));
      expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(code), isTrue);
    });

    test('Group daysUntilPermanentDeletion calculates 15-day window accurately', () {
      final now = DateTime.now();
      final groupActive = Group(
        id: 'g_act',
        name: 'Active',
        createdBy: 'u_1',
        inviteCode: 'ACT123',
        createdAt: now,
        updatedAt: now,
      );
      expect(groupActive.daysUntilPermanentDeletion, equals(15));

      final groupDeleted3DaysAgo = groupActive.copyWith(
        isDeleted: true,
        deletedAt: now.subtract(const Duration(days: 3)),
      );
      expect(groupDeleted3DaysAgo.daysUntilPermanentDeletion, inInclusiveRange(11, 12));

      final groupExpired = groupActive.copyWith(
        isDeleted: true,
        deletedAt: now.subtract(const Duration(days: 16)),
      );
      expect(groupExpired.daysUntilPermanentDeletion, equals(0));
    });

    test('NeedItem isStale detects items unfulfilled for 5 or more days', () {
      final now = DateTime.now();
      final freshItem = NeedItem(
        id: 'n_fresh',
        cohortId: 'g_1',
        title: 'Milk',
        addedByUserId: 'u_1',
        createdAt: now.subtract(const Duration(days: 2)),
      );
      expect(freshItem.isStale, isFalse);

      final staleItem = NeedItem(
        id: 'n_stale',
        cohortId: 'g_1',
        title: 'Dish soap',
        addedByUserId: 'u_1',
        createdAt: now.subtract(const Duration(days: 6)),
      );
      expect(staleItem.isStale, isTrue);

      final completedOldItem = staleItem.copyWith(
        isCompleted: true,
        completedAt: now,
      );
      expect(completedOldItem.isStale, isFalse);
    });
  });

  group('Offline Repositories Integration', () {
    test('ProfileRepository updates and fetches local profile gracefully', () async {
      final profile = await profileRepo.updateProfile(
        'u_test',
        fullName: 'Bob Builder',
        vpaId: 'bob@upi',
      );
      expect(profile.fullName, equals('Bob Builder'));
      expect(profile.vpaId, equals('bob@upi'));

      final fetched = await profileRepo.fetchProfile('u_test');
      expect(fetched?.fullName, equals('Bob Builder'));
    });

    test('GroupRepository creates and updates cohorts locally', () async {
      final creator = UserProfile(
        id: 'u_owner',
        fullName: 'Group Owner',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      final newGroup = Group(
        id: 'cohort_101',
        name: 'Weekend Trip',
        category: 'trip',
        createdBy: creator.id,
        inviteCode: 'WKND26',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res = await groupRepo.createCohort(newGroup, creator);
      expect(res.cohort.name, equals('Weekend Trip'));
      expect(res.member.role, equals('admin'));

      // Check fetch
      final userCohorts = await groupRepo.fetchUserCohorts(creator.id);
      expect(userCohorts.cohorts.length, equals(1));
      expect(userCohorts.cohorts.first.id, equals('cohort_101'));

      // Archive toggle
      await groupRepo.toggleArchiveCohort('cohort_101', true);
      final afterArchive = await groupRepo.fetchUserCohorts(creator.id);
      expect(afterArchive.cohorts.first.isArchived, isTrue);

      // Soft delete
      await groupRepo.deleteCohort('cohort_101');
      final afterDelete = await groupRepo.fetchUserCohorts(creator.id);
      expect(afterDelete.cohorts.first.isDeleted, isTrue);

      // Restore
      await groupRepo.restoreDeletedCohort('cohort_101');
      final afterRestore = await groupRepo.fetchUserCohorts(creator.id);
      expect(afterRestore.cohorts.first.isDeleted, isFalse);
    });

    test('ExpenseRepository creates and fetches expenses locally', () async {
      final expense = Expense(
        id: 'exp_55',
        cohortId: 'cohort_101',
        title: 'Fuel',
        totalAmount: 2400.0,
        paidByUserId: 'u_owner',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await expenseRepo.createExpense(expense);
      expect(saved.title, equals('Fuel'));

      final expenses = await expenseRepo.fetchExpensesForCohort('cohort_101');
      expect(expenses.length, equals(1));
      expect(expenses.first.totalAmount, equals(2400.0));

      await expenseRepo.deleteExpense('exp_55', 'cohort_101');
      final afterDelete = await expenseRepo.fetchExpensesForCohort('cohort_101');
      expect(afterDelete, isEmpty);
    });

    test('NeedsRepository creates, toggles and deletes checklist items locally', () async {
      final item = NeedItem(
        id: 'need_77',
        cohortId: 'cohort_101',
        title: 'Snacks',
        addedByUserId: 'u_owner',
        createdAt: DateTime.now(),
      );

      final saved = await needsRepo.createSharedListItem(item);
      expect(saved.title, equals('Snacks'));
      expect(saved.isCompleted, isFalse);

      await needsRepo.toggleSharedListItem('need_77', 'cohort_101', true);
      final items = await needsRepo.fetchSharedListItems('cohort_101');
      expect(items.first.isCompleted, isTrue);

      await needsRepo.deleteSharedListItem('need_77', 'cohort_101');
      final afterDelete = await needsRepo.fetchSharedListItems('cohort_101');
      expect(afterDelete, isEmpty);
    });
  });
}
