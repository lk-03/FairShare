import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/utils/category_detector.dart';

void main() {
  group('CategoryDetector', () {
    test('detects dining category correctly', () {
      expect(CategoryDetector.detectCategory('Swiggy order with friends'), 'dining');
      expect(CategoryDetector.detectCategory('Late night Zomato pizza'), 'dining');
      expect(CategoryDetector.detectCategory('Coffee at Starbucks'), 'dining');
      expect(CategoryDetector.detectCategory('Team lunch buffet'), 'dining');
      expect(CategoryDetector.detectCategory('Chai and snacks'), 'dining');
    });

    test('detects transport category correctly', () {
      expect(CategoryDetector.detectCategory('Uber to airport'), 'transport');
      expect(CategoryDetector.detectCategory('Ola cab to office'), 'transport');
      expect(CategoryDetector.detectCategory('Metro commuter card'), 'transport');
      expect(CategoryDetector.detectCategory('Petrol for car'), 'transport');
      expect(CategoryDetector.detectCategory('Rapido ride commute'), 'transport');
    });

    test('detects house / groceries category correctly', () {
      expect(CategoryDetector.detectCategory('Blinkit grocery order'), 'house');
      expect(CategoryDetector.detectCategory('Zepto vegetables & milk'), 'house');
      expect(CategoryDetector.detectCategory('Instamart veggies and bread'), 'house');
      expect(CategoryDetector.detectCategory('Apartment rent payment'), 'house');
    });

    test('detects event category correctly', () {
      expect(CategoryDetector.detectCategory('Movie tickets at PVR'), 'event');
      expect(CategoryDetector.detectCategory('Concert tickets pass'), 'event');
      expect(CategoryDetector.detectCategory('Clubbing night party'), 'event');
    });

    test('detects utilities category correctly', () {
      expect(CategoryDetector.detectCategory('Electricity bill payment'), 'utilities');
      expect(CategoryDetector.detectCategory('WiFi recharge broadband'), 'utilities');
      expect(CategoryDetector.detectCategory('Bescom power utility'), 'utilities');
    });

    test('resolves multi-category conflicts to custom (Miscellaneous)', () {
      // Swiggy (dining) + Uber (transit) -> multiple matches -> custom
      expect(CategoryDetector.detectCategory('Swiggy dinner and Uber ride'), 'custom');
      // Netflix (entertainment) + Groceries (groceries) -> custom
      expect(CategoryDetector.detectCategory('Netflix and grocery shopping'), 'custom');
    });

    test('returns null when no keywords match or empty string', () {
      expect(CategoryDetector.detectCategory(''), isNull);
      expect(CategoryDetector.detectCategory('   '), isNull);
      expect(CategoryDetector.detectCategory('Random note 123 xyz'), isNull);
    });
  });
}
