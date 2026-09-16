import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/core/models/comment.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/expense_shortcut.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/need_item.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/reminder_settings.dart';
import 'package:fairshare/core/models/split.dart';
import 'package:fairshare/data/local/local_cache_service.dart';

void main() {
  late LocalCacheService cacheService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheService = LocalCacheService(prefs);
  });

  group('LocalCacheService', () {
    test('saveCurrentUser and getCurrentUser handles serialization correctly', () async {
      expect(cacheService.getCurrentUser(), isNull);

      final user = UserProfile(
        id: 'u_123',
        email: 'alice@example.com',
        fullName: 'Alice Walker',
        nickname: 'Alice',
        vpaId: 'alice@okhdfcbank',
        isGuest: false,
        createdAt: DateTime(2025, 1, 1),
      );

      await cacheService.saveCurrentUser(user);
      final retrieved = cacheService.getCurrentUser();

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('u_123'));
      expect(retrieved.email, equals('alice@example.com'));
      expect(retrieved.fullName, equals('Alice Walker'));
      expect(retrieved.displayName, equals('Alice'));
      expect(retrieved.vpaId, equals('alice@okhdfcbank'));
      expect(retrieved.isGuest, isFalse);

      await cacheService.clearCurrentUser();
      expect(cacheService.getCurrentUser(), isNull);
    });

    test('activeGroupId persistence', () async {
      expect(cacheService.getActiveGroupId(), isNull);

      await cacheService.saveActiveGroupId('cohort_456');
      expect(cacheService.getActiveGroupId(), equals('cohort_456'));

      await cacheService.saveActiveGroupId(null);
      expect(cacheService.getActiveGroupId(), isNull);
    });

    test('saveGroups and getCachedGroups', () async {
      expect(cacheService.getCachedGroups(), isEmpty);

      final group1 = Group(
        id: 'g_1',
        name: 'Goa Trip 2026',
        category: 'trip',
        createdBy: 'u_1',
        inviteCode: 'GOA2026',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
      final group2 = Group(
        id: 'g_2',
        name: 'Flat 402',
        category: 'house',
        createdBy: 'u_2',
        inviteCode: 'FLAT402',
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 2),
      );

      await cacheService.saveGroups([group1, group2]);
      final cached = cacheService.getCachedGroups();

      expect(cached.length, equals(2));
      expect(cached[0].id, equals('g_1'));
      expect(cached[0].name, equals('Goa Trip 2026'));
      expect(cached[1].id, equals('g_2'));
      expect(cached[1].inviteCode, equals('FLAT402'));
    });

    test('saveMembers and getCachedMembers', () async {
      final member = GroupMember(
        id: 'm_1',
        cohortId: 'g_1',
        userId: 'u_1',
        role: 'admin',
        joinedAt: DateTime(2026, 1, 1),
      );

      await cacheService.saveMembers('g_1', [member]);
      final retrieved = cacheService.getCachedMembers('g_1');

      expect(retrieved.length, equals(1));
      expect(retrieved.first.userId, equals('u_1'));
      expect(retrieved.first.role, equals('admin'));
    });

    test('saveExpenses and getCachedExpenses with splits', () async {
      final expense = Expense(
        id: 'exp_1',
        cohortId: 'g_1',
        title: 'Dinner at Britto\'s',
        totalAmount: 1500.0,
        paidByUserId: 'u_1',
        splits: [
          const ExpenseSplit(userId: 'u_1', amount: 750.0),
          const ExpenseSplit(userId: 'u_2', amount: 750.0),
        ],
        createdAt: DateTime(2026, 1, 3),
        updatedAt: DateTime(2026, 1, 3),
      );

      await cacheService.saveExpenses('g_1', [expense]);
      final retrieved = cacheService.getCachedExpenses('g_1');

      expect(retrieved.length, equals(1));
      expect(retrieved.first.title, equals('Dinner at Britto\'s'));
      expect(retrieved.first.totalAmount, equals(1500.0));
      expect(retrieved.first.splits.length, equals(2));
      expect(retrieved.first.userShare('u_2'), equals(750.0));
      expect(retrieved.first.userNetBalance('u_1'), equals(750.0));
    });

    test('comments and shortcuts caching', () async {
      final comment = TransactionComment(
        id: 'c_1',
        expenseId: 'exp_1',
        userId: 'u_1',
        content: 'Paid via GPay',
        createdAt: DateTime(2026, 1, 3),
      );
      await cacheService.saveComments('exp_1', [comment]);
      final retrievedComments = cacheService.getCachedComments('exp_1');
      expect(retrievedComments.length, equals(1));
      expect(retrievedComments.first.content, equals('Paid via GPay'));

      final shortcut = ExpenseShortcut(
        id: 'sc_1',
        cohortId: 'g_1',
        title: 'Chai & Snacks',
        amount: 80.0,
        createdAt: DateTime(2026, 1, 1),
      );
      await cacheService.saveShortcuts('g_1', [shortcut]);
      final retrievedShortcuts = cacheService.getCachedShortcuts('g_1');
      expect(retrievedShortcuts.length, equals(1));
      expect(retrievedShortcuts.first.title, equals('Chai & Snacks'));
    });

    test('needs checklist and reminder settings', () async {
      final need = NeedItem(
        id: 'n_1',
        cohortId: 'g_1',
        title: 'Water cans',
        addedByUserId: 'u_1',
        createdAt: DateTime(2026, 1, 1),
      );
      await cacheService.saveNeeds('g_1', [need]);
      final retrievedNeeds = cacheService.getCachedNeeds('g_1');
      expect(retrievedNeeds.length, equals(1));
      expect(retrievedNeeds.first.title, equals('Water cans'));

      final reminder = const PersonalReminderSettings(
        cohortId: 'g_1',
        isEnabled: true,
        reminderFrequency: 'weekly',
        reminderTime: '10:00',
        settlementThreshold: 500.0,
      );
      await cacheService.saveReminderSettings('g_1', reminder);
      final retrievedReminder = cacheService.getCachedReminderSettings('g_1');
      expect(retrievedReminder, isNotNull);
      expect(retrievedReminder!.isEnabled, isTrue);
      expect(retrievedReminder.reminderTime, equals('10:00'));
    });

    test('offline mutation queue and onboarding flags', () async {
      expect(cacheService.getOfflineQueue(), isEmpty);
      await cacheService.addToOfflineQueue({'action': 'create_expense', 'id': 'exp_9'});
      expect(cacheService.getOfflineQueue().length, equals(1));
      await cacheService.clearOfflineQueue();
      expect(cacheService.getOfflineQueue(), isEmpty);

      expect(cacheService.hasCompletedOnboarding, isFalse);
      await cacheService.setOnboardingCompleted(true);
      expect(cacheService.hasCompletedOnboarding, isTrue);

      expect(cacheService.hasSeenAppTour, isFalse);
      await cacheService.setAppTourSeen(true);
      expect(cacheService.hasSeenAppTour, isTrue);

      await cacheService.clearAll();
      expect(cacheService.hasCompletedOnboarding, isFalse);
      expect(cacheService.hasSeenAppTour, isFalse);
    });
  });
}
