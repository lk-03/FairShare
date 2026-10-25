import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/models/need_item.dart';
import 'package:fairshare/core/utils/cart_matching_helper.dart';

void main() {
  group('CartMatchingHelper', () {
    final sampleDate = DateTime(2026, 10, 12);

    NeedItem createNeed({
      required String id,
      required String title,
      bool isCompleted = false,
      String? addedByName,
    }) {
      return NeedItem(
        id: id,
        cohortId: 'cohort_1',
        title: title,
        addedByUserId: 'user_1',
        isCompleted: isCompleted,
        createdAt: sampleDate,
        addedByName: addedByName ?? 'Alice',
      );
    }

    test('matches exact single word ignoring case', () {
      final need = createNeed(id: '1', title: 'Banana');
      final matches = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: 'banana',
        uncompletedCartItems: [need],
      );
      expect(matches.length, 1);
      expect(matches.first.id, '1');
    });

    test('matches plural when cart has singular, and vice versa', () {
      final needSingular = createNeed(id: '1', title: 'Banana');
      final needPlural = createNeed(id: '2', title: 'Apples');

      final matches1 = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: 'Bought 3 Bananas',
        uncompletedCartItems: [needSingular, needPlural],
      );
      expect(matches1.map((m) => m.id), contains('1'));

      final matches2 = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: 'Fresh Apple',
        uncompletedCartItems: [needSingular, needPlural],
      );
      expect(matches2.map((m) => m.id), contains('2'));
    });

    test('strips quantities and unit measurements from match candidates', () {
      final need = createNeed(id: '1', title: '1kg Bananas');
      final matches = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: 'Bananas',
        uncompletedCartItems: [need],
      );
      expect(matches.length, 1);
      expect(matches.first.id, '1');
    });

    test('does NOT false-positive match substrings within other words', () {
      final needIce = createNeed(id: '1', title: 'Ice');
      final matches = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: 'Basmati Rice and Orange Juice',
        uncompletedCartItems: [needIce],
      );
      expect(matches, isEmpty);
    });

    test('matches multi-word cart items', () {
      final needBread = createNeed(id: '1', title: 'Brown Bread');
      final matches = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: 'Supermarket - Fresh Brown Bread',
        uncompletedCartItems: [needBread],
      );
      expect(matches.length, 1);
      expect(matches.first.id, '1');
    });

    test('matches against receipt item names when expense title is general merchant', () {
      final needMilk = createNeed(id: '1', title: 'Milk');
      final needEggs = createNeed(id: '2', title: 'Eggs');
      final needCereal = createNeed(id: '3', title: 'Cereal');

      final matches = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: "Trader Joe's",
        itemNames: ['Organic Whole Milk 1 Gallon', 'Dozen Grade A Eggs', 'Coffee Beans'],
        uncompletedCartItems: [needMilk, needEggs, needCereal],
      );

      final matchedIds = matches.map((m) => m.id).toSet();
      expect(matchedIds, contains('1'));
      expect(matchedIds, contains('2'));
      expect(matchedIds.contains('3'), isFalse);
    });

    test('ignores already completed cart items', () {
      final needCompleted = createNeed(id: '1', title: 'Bananas', isCompleted: true);
      final matches = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: 'Bananas',
        uncompletedCartItems: [needCompleted],
      );
      expect(matches, isEmpty);
    });

    test('handles empty titles safely without crashing', () {
      final need = createNeed(id: '1', title: '');
      final matches = CartMatchingHelper.findMatchingCartItems(
        expenseTitle: '',
        uncompletedCartItems: [need],
      );
      expect(matches, isEmpty);
    });
  });
}
