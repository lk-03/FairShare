import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/services/supabase_service.dart';
import 'package:fairshare/data/repositories/profile_repository.dart';
import 'package:fairshare/data/repositories/friend_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalCacheService cacheService;
  late SupabaseService supabaseService;
  late ProfileRepository profileRepository;
  late FriendRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cacheService = LocalCacheService(prefs);
    supabaseService = SupabaseService();
    profileRepository = ProfileRepository(
      supabaseService: supabaseService,
      cacheService: cacheService,
    );
    repository = FriendRepository(
      supabaseService: supabaseService,
      profileRepository: profileRepository,
      cacheService: cacheService,
    );
  });

  group('FriendRepository offline/local features', () {
    test('addFriend with local contact caches and returns offline friend', () async {
      final result = await repository.addFriend(
        currentUserId: 'me_1',
        name: 'Pooja Iyer',
        vpaId: 'pooja@upi',
      );

      expect(result.isLocal, isTrue);
      expect(result.displayName, 'Pooja Iyer');
      expect(result.vpaId, 'pooja@upi');

      // Verify cached
      final cached = await repository.fetchFriends('me_1');
      expect(cached.any((f) => f.id == result.id), isTrue);
      expect(cached.first.displayName, 'Pooja Iyer');
    });

    test('removeFriend removes contact from cache', () async {
      final friend = await repository.addFriend(
        currentUserId: 'me_1',
        name: 'Karan Mehra',
      );

      var list = await repository.fetchFriends('me_1');
      expect(list.length, 1);

      await repository.removeFriend(friend.id, currentUserId: 'me_1');
      list = await repository.fetchFriends('me_1');
      expect(list.isEmpty, isTrue);
    });

    test('searchProfiles returns empty list gracefully when unconfigured', () async {
      final profiles = await repository.searchProfiles('alice');
      expect(profiles, isEmpty);
    });
  });
}
