import '../../core/models/need_item.dart';
import '../../core/models/reminder_settings.dart';
import '../local/local_cache_service.dart';
import '../services/supabase_service.dart';
import 'profile_repository.dart';

class NeedsRepository {
  final SupabaseService supabaseService;
  final ProfileRepository profileRepository;
  final LocalCacheService cacheService;

  NeedsRepository({
    required this.supabaseService,
    required this.profileRepository,
    required this.cacheService,
  });

  /// Fetches all shared list items (house cart / needs checklist) for a cohort
  Future<List<NeedItem>> fetchSharedListItems(String cohortId) async {
    if (!supabaseService.isConfigured || !isUuid(cohortId)) {
      return cacheService.getCachedNeeds(cohortId);
    }

    try {
      final rows = await supabaseService.client
          .from('shared_list_items')
          .select('*')
          .eq('cohort_id', cohortId)
          .order('created_at', ascending: false);

      final items = (rows as List)
          .map((r) => NeedItem.fromJson(r as Map<String, dynamic>))
          .toList();

      await cacheService.saveNeeds(cohortId, items);
      return items;
    } catch (_) {
      return cacheService.getCachedNeeds(cohortId);
    }
  }

  /// Creates a new need item in a cohort
  Future<NeedItem> createSharedListItem(NeedItem item) async {
    String addedByUserId = item.addedByUserId;
    if (!isUuid(addedByUserId)) {
      final profile = await profileRepository.getCurrentProfile();
      addedByUserId = profile.id;
    }

    final effectiveItem = item.copyWith(addedByUserId: addedByUserId);

    final currentNeeds = cacheService.getCachedNeeds(item.cohortId);
    await cacheService.saveNeeds(item.cohortId, [effectiveItem, ...currentNeeds]);

    if (!supabaseService.isConfigured || !isUuid(item.cohortId)) {
      return effectiveItem;
    }

    try {
      final row = await supabaseService.client
          .from('shared_list_items')
          .insert({
            if (isUuid(item.id)) 'id': item.id,
            'cohort_id': item.cohortId,
            'title': item.title,
            'added_by_user_id': addedByUserId,
            'is_completed': item.isCompleted,
            'completed_at': item.completedAt?.toIso8601String(),
          })
          .select()
          .single();

      final saved = NeedItem.fromJson(row);
      final updated = currentNeeds.where((n) => n.id != item.id).toList();
      await cacheService.saveNeeds(item.cohortId, [saved, ...updated]);
      return saved;
    } catch (_) {
      return effectiveItem;
    }
  }

  /// Toggles the completion state of an item
  Future<void> toggleSharedListItem(
    String itemId,
    String cohortId,
    bool isCompleted,
  ) async {
    final now = DateTime.now();
    final currentNeeds = cacheService.getCachedNeeds(cohortId);
    final updated = currentNeeds.map((n) {
      if (n.id == itemId) {
        return n.copyWith(
          isCompleted: isCompleted,
          completedAt: isCompleted ? now : null,
        );
      }
      return n;
    }).toList();
    await cacheService.saveNeeds(cohortId, updated);

    if (!supabaseService.isConfigured || !isUuid(itemId)) return;

    try {
      await supabaseService.client.from('shared_list_items').update({
        'is_completed': isCompleted,
        'completed_at': isCompleted ? now.toIso8601String() : null,
      }).eq('id', itemId);
    } catch (_) {}
  }

  /// Deletes a need item
  Future<void> deleteSharedListItem(String itemId, String cohortId) async {
    final currentNeeds = cacheService.getCachedNeeds(cohortId);
    final updated = currentNeeds.where((n) => n.id != itemId).toList();
    await cacheService.saveNeeds(cohortId, updated);

    if (!supabaseService.isConfigured || !isUuid(itemId)) return;

    try {
      await supabaseService.client
          .from('shared_list_items')
          .delete()
          .eq('id', itemId);
    } catch (_) {}
  }

  /// Retrieves reminder settings for a cohort
  PersonalReminderSettings getReminderSettings(String cohortId) {
    return cacheService.getCachedReminderSettings(cohortId) ??
        PersonalReminderSettings(cohortId: cohortId);
  }

  /// Saves reminder settings for a cohort
  Future<void> saveReminderSettings(PersonalReminderSettings settings) async {
    await cacheService.saveReminderSettings(settings.cohortId, settings);
  }
}
