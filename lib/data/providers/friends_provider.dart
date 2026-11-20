import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense.dart';
import '../../core/models/friend.dart';
import '../../core/models/friend_balance.dart';
import '../repositories/friend_repository.dart';
import 'auth_provider.dart';
import 'expenses_provider.dart';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(
    supabaseService: ref.watch(supabaseServiceProvider),
    profileRepository: ref.watch(profileRepositoryProvider),
    cacheService: ref.watch(localCacheServiceProvider),
  );
});

class FriendsNotifier extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    final user = ref.watch(currentUserProvider);
    final repo = ref.watch(friendRepositoryProvider);
    final uid = user?.id ?? '';
    return repo.fetchFriends(uid);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(currentUserProvider);
      final repo = ref.read(friendRepositoryProvider);
      return repo.fetchFriends(user?.id ?? '');
    });
  }

  Future<Friend?> addFriend({
    String? friendUserId,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? vpaId,
  }) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(friendRepositoryProvider);
    try {
      final friend = await repo.addFriend(
        currentUserId: user?.id ?? 'local_user',
        friendUserId: friendUserId,
        name: name,
        username: username,
        email: email,
        phone: phone,
        vpaId: vpaId,
      );

      final current = state.value ?? [];
      state = AsyncValue.data([friend, ...current.where((f) => f.id != friend.id)]);
      return friend;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> acceptRequest(String friendshipId) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(friendRepositoryProvider);
    final success = await repo.acceptFriendRequest(friendshipId, currentUserId: user?.id);
    if (success) {
      final current = state.value ?? [];
      state = AsyncValue.data(current.map((f) {
        if (f.id == friendshipId) {
          return f.copyWith(status: FriendshipStatus.accepted, updatedAt: DateTime.now());
        }
        return f;
      }).toList());
    }
    return success;
  }

  Future<bool> declineRequest(String friendshipId) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(friendRepositoryProvider);
    final success = await repo.declineFriendRequest(friendshipId, currentUserId: user?.id);
    if (success) {
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((f) => f.id != friendshipId).toList());
    }
    return success;
  }

  Future<bool> cancelRequest(String friendshipId) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(friendRepositoryProvider);
    final success = await repo.cancelFriendRequest(friendshipId, currentUserId: user?.id);
    if (success) {
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((f) => f.id != friendshipId).toList());
    }
    return success;
  }

  Future<bool> removeFriend(String friendshipId) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(friendRepositoryProvider);
    final success = await repo.removeFriend(friendshipId, currentUserId: user?.id);
    if (success) {
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((f) => f.id != friendshipId).toList());
    }
    return success;
  }
}

final friendsProvider = AsyncNotifierProvider<FriendsNotifier, List<Friend>>(() {
  return FriendsNotifier();
});

/// Exposes strictly accepted/confirmed mutual friends and local contacts
final acceptedFriendsProvider = Provider<List<Friend>>((ref) {
  final friendsAsync = ref.watch(friendsProvider);
  final all = friendsAsync.value ?? [];
  return all.where((f) => f.isAccepted || f.isLocal).toList();
});

/// Exposes incoming pending requests for the current user
final incomingFriendRequestsProvider = Provider<List<Friend>>((ref) {
  final friendsAsync = ref.watch(friendsProvider);
  final all = friendsAsync.value ?? [];
  final user = ref.watch(currentUserProvider);
  final uid = user?.id ?? '';
  return all.where((f) => f.isIncoming(uid)).toList();
});

/// Exposes outgoing pending requests sent by the current user
final outgoingFriendRequestsProvider = Provider<List<Friend>>((ref) {
  final friendsAsync = ref.watch(friendsProvider);
  final all = friendsAsync.value ?? [];
  final user = ref.watch(currentUserProvider);
  final uid = user?.id ?? '';
  return all.where((f) => f.isOutgoing(uid)).toList();
});

/// Checks if a given user is a mutual friend of the current user
final isFriendProvider = Provider.family<bool, String>((ref, targetUserId) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser != null && currentUser.id == targetUserId) return true;
  final accepted = ref.watch(acceptedFriendsProvider);
  return accepted.any((f) => f.friendUserId == targetUserId);
});

class FriendExpensesNotifier extends Notifier<AsyncValue<List<Expense>>> {
  late final String _friendshipId;

  FriendExpensesNotifier(String friendshipId) {
    _friendshipId = friendshipId;
  }

  @override
  AsyncValue<List<Expense>> build() {
    final cache = ref.watch(localCacheServiceProvider);
    final cached = cache.getCachedFriendExpenses(_friendshipId);
    return AsyncValue.data(cached.where((e) => !e.isDeleted).toList());
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final expenses = await repo.fetchExpensesForFriend(_friendshipId);
      state = AsyncValue.data(expenses.where((e) => !e.isDeleted).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Expense?> addExpense(Expense expense) async {
    final repo = ref.read(expenseRepositoryProvider);
    final effective = expense.copyWith(friendshipId: _friendshipId);
    try {
      final saved = await repo.createExpense(effective);
      final current = state.value ?? [];
      state = AsyncValue.data([saved, ...current.where((e) => e.id != saved.id)]);
      return saved;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.deleteFriendExpense(expenseId, _friendshipId);
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((e) => e.id != expenseId).toList());
  }
}

final friendExpensesProvider =
    NotifierProvider.family<FriendExpensesNotifier, AsyncValue<List<Expense>>, String>(
  (friendshipId) => FriendExpensesNotifier(friendshipId),
);

/// Calculates the bilateral net balance between current user and a specific friend
final friendBalanceProvider = Provider.family<FriendBalance, Friend>((ref, friend) {
  final expensesAsync = ref.watch(friendExpensesProvider(friend.id));
  final expenses = expensesAsync.value ?? [];
  final currentUser = ref.watch(currentUserProvider);
  final myUserId = currentUser?.id ?? 'local_user';

  double net = 0.0;
  double totalShared = 0.0;
  DateTime? lastActivity;

  for (final exp in expenses) {
    if (exp.isDeleted) continue;
    totalShared += exp.totalAmount;
    if (lastActivity == null || exp.createdAt.isAfter(lastActivity)) {
      lastActivity = exp.createdAt;
    }

    final myPaid = exp.userPaid(myUserId);
    final myShare = exp.userShare(myUserId);

    if (exp.splits.isNotEmpty) {
      net += (myPaid - myShare);
    } else {
      final half = exp.totalAmount / 2.0;
      if (exp.paidByUserId == myUserId) {
        net += half;
      } else {
        net -= half;
      }
    }
  }

  return FriendBalance(
    friend: friend,
    netAmount: net,
    totalSharedAmount: totalShared,
    expenseCount: expenses.where((e) => !e.isDeleted).length,
    lastActivityAt: lastActivity,
  );
});

/// Aggregates all direct 1-on-1 balances across all friends
final friendsAggregateBalanceProvider =
    Provider<({double youOwe, double youAreOwed, double net})>((ref) {
  final friends = ref.watch(acceptedFriendsProvider);

  double totalOwe = 0.0;
  double totalOwed = 0.0;

  for (final f in friends) {
    final bal = ref.watch(friendBalanceProvider(f));
    if (bal.netAmount > 0.01) {
      totalOwed += bal.netAmount;
    } else if (bal.netAmount < -0.01) {
      totalOwe += bal.netAmount.abs();
    }
  }

  return (
    youOwe: totalOwe,
    youAreOwed: totalOwed,
    net: totalOwed - totalOwe,
  );
});
