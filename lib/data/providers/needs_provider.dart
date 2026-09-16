import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/need_item.dart';
import '../repositories/needs_repository.dart';
import 'auth_provider.dart';

final needsRepositoryProvider = Provider<NeedsRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final cache = ref.watch(localCacheServiceProvider);
  return NeedsRepository(
    supabaseService: supabase,
    profileRepository: profileRepo,
    cacheService: cache,
  );
});

class GroupNeedsNotifier extends Notifier<AsyncValue<List<NeedItem>>> {
  late final String _cohortId;

  GroupNeedsNotifier(String cohortId) {
    _cohortId = cohortId;
  }

  @override
  AsyncValue<List<NeedItem>> build() {
    final cache = ref.watch(localCacheServiceProvider);
    return AsyncValue.data(cache.getCachedNeeds(_cohortId));
  }

  Future<void> loadNeeds() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(needsRepositoryProvider);
      final items = await repo.fetchSharedListItems(_cohortId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<NeedItem> addNeed(String title) async {
    final currentUser = ref.read(currentUserProvider);
    final repo = ref.read(needsRepositoryProvider);

    final item = NeedItem(
      id: 'need_${DateTime.now().millisecondsSinceEpoch}',
      cohortId: _cohortId,
      title: title.trim(),
      addedByUserId: currentUser?.id ?? '',
      createdAt: DateTime.now(),
      addedByName: currentUser?.displayName,
    );

    final saved = await repo.createSharedListItem(item);
    final current = state.value ?? [];
    state = AsyncValue.data([saved, ...current.where((n) => n.id != saved.id)]);
    return saved;
  }

  Future<void> toggleNeed(String itemId) async {
    final current = state.value ?? [];
    final target = current.where((n) => n.id == itemId).firstOrNull;
    if (target == null) return;

    final nextCompleted = !target.isCompleted;
    final now = DateTime.now();
    final updated = current.map((n) {
      if (n.id == itemId) {
        return n.copyWith(
          isCompleted: nextCompleted,
          completedAt: nextCompleted ? now : null,
        );
      }
      return n;
    }).toList();
    state = AsyncValue.data(updated);

    final repo = ref.read(needsRepositoryProvider);
    await repo.toggleSharedListItem(itemId, _cohortId, nextCompleted);
  }

  Future<void> deleteNeed(String itemId) async {
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((n) => n.id != itemId).toList());

    final repo = ref.read(needsRepositoryProvider);
    await repo.deleteSharedListItem(itemId, _cohortId);
  }
}

final groupNeedsProvider =
    NotifierProvider.family<GroupNeedsNotifier, AsyncValue<List<NeedItem>>, String>(
  (cohortId) => GroupNeedsNotifier(cohortId),
);

/// Count of items in this group that have been unfulfilled for >= 5 days
final staleNeedsCountProvider =
    Provider.family<int, String>((ref, cohortId) {
  final items = ref.watch(groupNeedsProvider(cohortId)).value ?? [];
  return items.where((i) => i.isStale).length;
});
