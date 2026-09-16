import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/profile.dart';
import '../../core/models/group.dart';
import '../../core/models/group_member.dart';
import '../../core/models/expense.dart';
import '../../core/models/comment.dart';
import '../../core/models/expense_shortcut.dart';
import '../../core/models/need_item.dart';
import '../../core/models/reminder_settings.dart';

/// Provides offline persistence and caching across the application via SharedPreferences
class LocalCacheService {
  final SharedPreferences _prefs;

  LocalCacheService(this._prefs);

  static const String _kCurrentUser = 'fairshare_current_user';
  static const String _kActiveGroupId = 'fairshare_active_group_id';
  static const String _kCachedGroups = 'fairshare_cached_groups';
  static const String _kMembersPrefix = 'fairshare_cached_members_';
  static const String _kExpensesPrefix = 'fairshare_cached_expenses_';
  static const String _kCommentsPrefix = 'fairshare_cached_comments_';
  static const String _kShortcutsPrefix = 'fairshare_cached_shortcuts_';
  static const String _kNeedsPrefix = 'fairshare_cached_needs_';
  static const String _kRemindersPrefix = 'fairshare_cached_reminders_';
  static const String _kOfflineQueue = 'fairshare_offline_queue';
  static const String _kOnboardingCompleted = 'fairshare_onboarding_completed';
  static const String _kAppTourSeen = 'fairshare_app_tour_seen';

  // --- Current User Profile ---

  Future<void> saveCurrentUser(UserProfile user) async {
    await _prefs.setString(_kCurrentUser, jsonEncode(user.toJson()));
  }

  UserProfile? getCurrentUser() {
    final raw = _prefs.getString(_kCurrentUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UserProfile.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearCurrentUser() async {
    await _prefs.remove(_kCurrentUser);
  }

  // --- Active Group ID ---

  Future<void> saveActiveGroupId(String? groupId) async {
    if (groupId == null) {
      await _prefs.remove(_kActiveGroupId);
    } else {
      await _prefs.setString(_kActiveGroupId, groupId);
    }
  }

  String? getActiveGroupId() {
    return _prefs.getString(_kActiveGroupId);
  }

  // --- Cached Groups ---

  Future<void> saveGroups(List<Group> groups) async {
    final encoded = jsonEncode(groups.map((g) => g.toJson()).toList());
    await _prefs.setString(_kCachedGroups, encoded);
  }

  List<Group> getCachedGroups() {
    final raw = _prefs.getString(_kCachedGroups);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((g) => Group.fromJson(g))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Cached Group Members ---

  Future<void> saveMembers(String groupId, List<GroupMember> members) async {
    final key = '$_kMembersPrefix$groupId';
    final encoded = jsonEncode(members.map((m) => m.toJson()).toList());
    await _prefs.setString(key, encoded);
  }

  List<GroupMember> getCachedMembers(String groupId) {
    final key = '$_kMembersPrefix$groupId';
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => GroupMember.fromJson(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Cached Expenses ---

  Future<void> saveExpenses(String groupId, List<Expense> expenses) async {
    final key = '$_kExpensesPrefix$groupId';
    final encoded = jsonEncode(expenses.map((e) => e.toJson()).toList());
    await _prefs.setString(key, encoded);
  }

  List<Expense> getCachedExpenses(String groupId) {
    final key = '$_kExpensesPrefix$groupId';
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => Expense.fromJson(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Cached Comments ---

  Future<void> saveComments(String expenseId, List<TransactionComment> comments) async {
    final key = '$_kCommentsPrefix$expenseId';
    final encoded = jsonEncode(comments.map((c) => c.toJson()).toList());
    await _prefs.setString(key, encoded);
  }

  List<TransactionComment> getCachedComments(String expenseId) {
    final key = '$_kCommentsPrefix$expenseId';
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((c) => TransactionComment.fromJson(c))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Cached Shortcuts ---

  Future<void> saveShortcuts(String groupId, List<ExpenseShortcut> shortcuts) async {
    final key = '$_kShortcutsPrefix$groupId';
    final encoded = jsonEncode(shortcuts.map((s) => s.toJson()).toList());
    await _prefs.setString(key, encoded);
  }

  List<ExpenseShortcut> getCachedShortcuts(String groupId) {
    final key = '$_kShortcutsPrefix$groupId';
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((s) => ExpenseShortcut.fromJson(s))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Cached Needs ---

  Future<void> saveNeeds(String groupId, List<NeedItem> items) async {
    final key = '$_kNeedsPrefix$groupId';
    final encoded = jsonEncode(items.map((n) => n.toJson()).toList());
    await _prefs.setString(key, encoded);
  }

  List<NeedItem> getCachedNeeds(String groupId) {
    final key = '$_kNeedsPrefix$groupId';
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((n) => NeedItem.fromJson(n))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Cached Reminder Settings ---

  Future<void> saveReminderSettings(String groupId, PersonalReminderSettings settings) async {
    final key = '$_kRemindersPrefix$groupId';
    final encoded = jsonEncode(settings.toJson());
    await _prefs.setString(key, encoded);
  }

  PersonalReminderSettings? getCachedReminderSettings(String groupId) {
    final key = '$_kRemindersPrefix$groupId';
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PersonalReminderSettings.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  // --- Offline Mutation Queue ---

  Future<void> addToOfflineQueue(Map<String, dynamic> mutation) async {
    final queue = getOfflineQueue();
    queue.add(mutation);
    await _prefs.setString(_kOfflineQueue, jsonEncode(queue));
  }

  List<Map<String, dynamic>> getOfflineQueue() {
    final raw = _prefs.getString(_kOfflineQueue);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> clearOfflineQueue() async {
    await _prefs.remove(_kOfflineQueue);
  }

  // --- Flags ---

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_kOnboardingCompleted, completed);
  }

  bool get hasCompletedOnboarding => _prefs.getBool(_kOnboardingCompleted) ?? false;

  Future<void> setAppTourSeen(bool seen) async {
    await _prefs.setBool(_kAppTourSeen, seen);
  }

  bool get hasSeenAppTour => _prefs.getBool(_kAppTourSeen) ?? false;

  // --- Clear All Cache ---

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
