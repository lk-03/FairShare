import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/utils/upi_intent.dart';

void main() {
  group('UPIIntentHelper URL Builder', () {
    test('should format upi://pay URI correctly', () {
      const config = UPIPaymentConfig(
        vpaId: 'kowsic@okaxis',
        payeeName: 'Kowsic L',
        amount: 150.5,
        currency: 'INR',
        note: 'Goa Trip Settlement',
      );

      final url = UPIIntentHelper.buildUPIIntentURL(config);

      expect(
        url,
        'upi://pay?pa=kowsic@okaxis&pn=Kowsic%20L&am=150.50&cu=INR&tn=Goa%20Trip%20Settlement',
      );
    });

    test('should sanitize special characters and hyphens from transaction note', () {
      const config = UPIPaymentConfig(
        vpaId: 'test@upi',
        payeeName: 'Sam',
        amount: 27.5,
        currency: 'INR',
        note: 'FairShare Settlement - House (Cart)!',
      );

      final url = UPIIntentHelper.buildUPIIntentURL(config);

      expect(
        url,
        'upi://pay?pa=test@upi&pn=Sam&am=27.50&cu=INR&tn=FairShare%20Settlement%20House%20Cart',
      );
    });

    test('should handle empty or whitespace notes with default FairShare note', () {
      const config = UPIPaymentConfig(
        vpaId: 'test@upi',
        payeeName: 'Sam',
        amount: 100.0,
        currency: 'INR',
        note: '   ',
      );

      final url = UPIIntentHelper.buildUPIIntentURL(config);

      expect(url.contains('tn=FairShare'), true);
    });

    test('should reject invalid VPA when launching intent', () async {
      const invalidConfig = UPIPaymentConfig(
        vpaId: 'invalid-vpa-without-at',
        payeeName: 'Bob',
        amount: 50.0,
      );

      final result = await UPIIntentHelper.launchUPIIntent(invalidConfig);

      expect(result.success, false);
      expect(result.message?.contains('Invalid Payee UPI ID'), true);
    });
  });
}
