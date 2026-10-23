import 'package:url_launcher/url_launcher.dart';

/// Configuration for generating UPI payment intents
class UPIPaymentConfig {
  final String vpaId; // e.g. name@okaxis
  final String payeeName;
  final double amount;
  final String currency;
  final String note;
  final String? transactionRef;

  const UPIPaymentConfig({
    required this.vpaId,
    required this.payeeName,
    required this.amount,
    this.currency = 'INR',
    this.note = 'FairShare',
    this.transactionRef,
  });
}

/// Popular UPI payment apps on Android
enum UPIApp {
  generic('Any UPI App', null),
  gpay('Google Pay', 'com.google.android.apps.nbu.paisa.user'),
  phonepe('PhonePe', 'com.phonepe.app'),
  paytm('Paytm', 'net.one97.paytm'),
  cred('CRED', 'com.dreamplug.androidapp'),
  bhim('BHIM', 'in.org.npci.upiapp');

  final String displayName;
  final String? packageName;

  const UPIApp(this.displayName, this.packageName);
}

class UPIIntentResult {
  final bool success;
  final String? message;

  const UPIIntentResult({required this.success, this.message});
}

/// UPIIntentHelper builds and triggers standard OS-level UPI intent deep links.
class UPIIntentHelper {
  /// Builds standard OS-level UPI intent deep link URI
  /// Format: upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...
  /// The note is sanitized to alphanumeric characters and spaces only to prevent bank risk policy blocks.
  static String buildUPIIntentURL(UPIPaymentConfig config) {
    final cleanVpa = config.vpaId.trim();
    final cleanName = config.payeeName.trim().isEmpty ? 'Payee' : config.payeeName.trim();
    final encodedName = Uri.encodeComponent(cleanName);
    final formattedAmount = config.amount.toStringAsFixed(2);

    String rawNote = config.note.trim().isEmpty ? 'FairShare' : config.note;
    String cleanNote = rawNote
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanNote.isEmpty) cleanNote = 'FairShare';
    final encodedNote = Uri.encodeComponent(cleanNote);

    return 'upi://pay?pa=$cleanVpa&pn=$encodedName&am=$formattedAmount&cu=${config.currency}&tn=$encodedNote';
  }

  /// Programmatically triggers OS-level UPI intent redirection.
  /// Launches user's installed UPI app (Google Pay, PhonePe, Paytm, CRED, etc.).
  static Future<UPIIntentResult> launchUPIIntent(UPIPaymentConfig config) async {
    final vpa = config.vpaId.trim();
    if (!vpa.contains('@') || vpa.length < 3) {
      return const UPIIntentResult(
        success: false,
        message: 'Invalid Payee UPI ID (VPA). Please update profile with a valid UPI ID (e.g. name@upi).',
      );
    }

    final urlString = buildUPIIntentURL(config);
    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );

      if (launched) {
        return const UPIIntentResult(success: true);
      } else {
        return const UPIIntentResult(
          success: false,
          message: 'No supported UPI app found. Please copy the UPI ID to pay manually.',
        );
      }
    } catch (e) {
      return UPIIntentResult(
        success: false,
        message: 'Could not launch UPI payment app: $e',
      );
    }
  }
}
