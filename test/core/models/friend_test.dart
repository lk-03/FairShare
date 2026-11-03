import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/models/friend.dart';
import 'package:fairshare/core/models/friend_balance.dart';
import 'package:fairshare/core/models/profile.dart';

void main() {
  group('Friend model', () {
    final now = DateTime.now();
    final profile = UserProfile(
      id: 'friend_user_1',
      fullName: 'Aarav Patel',
      username: 'aarav_p',
      email: 'aarav@example.com',
      vpaId: 'aarav@okhdfcbank',
      createdAt: now,
    );

    final friend = Friend(
      id: 'fs_123',
      friendUserId: 'friend_user_1',
      profile: profile,
      status: FriendshipStatus.accepted,
      createdBy: 'user_current',
      isLocal: false,
      createdAt: now,
      updatedAt: now,
    );

    test('getters return profile attributes correctly', () {
      expect(friend.displayName, 'Aarav Patel');
      expect(friend.initials, 'AP');
      expect(friend.email, 'aarav@example.com');
      expect(friend.username, 'aarav_p');
      expect(friend.vpaId, 'aarav@okhdfcbank');
      expect(friend.upiId, 'aarav@okhdfcbank');
      expect(friend.isLocalContact, isFalse);
      expect(friend.emailOrHandle, 'aarav@example.com');
    });

    test('emailOrHandle falls back to username when email is absent', () {
      final noEmailProfile = UserProfile(
        id: 'user_2',
        fullName: 'Diya Sharma',
        username: 'diya_s',
        createdAt: now,
      );
      final f2 = Friend(
        id: 'fs_456',
        friendUserId: 'user_2',
        profile: noEmailProfile,
        createdAt: now,
        updatedAt: now,
      );
      expect(f2.emailOrHandle, '@diya_s');
    });

    test('FriendshipStatus.fromString parses correctly', () {
      expect(FriendshipStatus.fromString('pending'), FriendshipStatus.pending);
      expect(FriendshipStatus.fromString('declined'), FriendshipStatus.declined);
      expect(FriendshipStatus.fromString('blocked'), FriendshipStatus.blocked);
      expect(FriendshipStatus.fromString('accepted'), FriendshipStatus.accepted);
      expect(FriendshipStatus.fromString('unknown'), FriendshipStatus.accepted);
      expect(FriendshipStatus.fromString(null), FriendshipStatus.accepted);
    });

    test('toJson and fromJson serialize symmetrically', () {
      final json = friend.toJson();
      expect(json['id'], 'fs_123');
      expect(json['friend_user_id'], 'friend_user_1');
      expect(json['status'], 'accepted');
      expect(json['is_local'], isFalse);

      final restored = Friend.fromJson(json);
      expect(restored.id, friend.id);
      expect(restored.friendUserId, friend.friendUserId);
      expect(restored.displayName, friend.displayName);
      expect(restored.status, FriendshipStatus.accepted);
    });
  });

  group('FriendBalance model', () {
    final now = DateTime.now();
    final profile = UserProfile(
      id: 'friend_user_1',
      fullName: 'Aarav Patel',
      createdAt: now,
    );
    final friend = Friend(
      id: 'fs_123',
      friendUserId: 'friend_user_1',
      profile: profile,
      createdAt: now,
      updatedAt: now,
    );

    test('balance indicates settled when net is ~0', () {
      final bal = FriendBalance(
        friend: friend,
        netAmount: 0.0,
        totalSharedAmount: 1500.0,
      );
      expect(bal.isSettled, isTrue);
      expect(bal.owesYou, isFalse);
      expect(bal.youOwe, isFalse);
      expect(bal.absoluteAmount, 0.0);
      expect(bal.totalVolume, 1500.0);
    });

    test('balance indicates friend owes user when net > 0', () {
      final bal = FriendBalance(
        friend: friend,
        netAmount: 450.50,
        totalSharedAmount: 901.0,
      );
      expect(bal.isSettled, isFalse);
      expect(bal.owesYou, isTrue);
      expect(bal.friendOwesUser, isTrue);
      expect(bal.youOwe, isFalse);
      expect(bal.userOwesFriend, isFalse);
      expect(bal.absoluteAmount, 450.50);
    });

    test('balance indicates user owes friend when net < 0', () {
      final bal = FriendBalance(
        friend: friend,
        netAmount: -250.0,
        totalSharedAmount: 500.0,
      );
      expect(bal.isSettled, isFalse);
      expect(bal.owesYou, isFalse);
      expect(bal.youOwe, isTrue);
      expect(bal.userOwesFriend, isTrue);
      expect(bal.absoluteAmount, 250.0);
    });
  });
}
