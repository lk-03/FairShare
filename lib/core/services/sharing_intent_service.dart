import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Global service that intercepts shared CSV files and text from external apps
/// (e.g., Splitwise "Export as CSV" via the OS Share Sheet).
class SharingIntentService {
  SharingIntentService._();
  static final SharingIntentService instance = SharingIntentService._();

  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  /// Holds pending shared CSV raw text awaiting import by the UI.
  final ValueNotifier<String?> pendingCsvNotifier = ValueNotifier<String?>(null);

  /// Initializes listeners for incoming shared files from other apps.
  void initialize() {
    // Only supported on Android and iOS
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      // 1. Listen to shared media while app is running in memory
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        _handleSharedFiles,
        onError: (err) {
          debugPrint('SharingIntentService getMediaStream error: $err');
        },
      );

      // 2. Check if the app was launched cold by tapping FairShare in the share sheet
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        if (files.isNotEmpty) {
          _handleSharedFiles(files);
          ReceiveSharingIntent.instance.reset();
        }
      }).catchError((err) {
        debugPrint('SharingIntentService getInitialMedia error: $err');
      });
    } catch (e) {
      debugPrint('SharingIntentService init error: $e');
    }
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    for (final file in files) {
      final path = file.path;
      if (path.isEmpty) continue;

      try {
        final f = File(path);
        if (await f.exists()) {
          final content = await f.readAsString();
          if (_isCsvContent(content)) {
            pendingCsvNotifier.value = content;
            break;
          }
        }
      } catch (e) {
        debugPrint('Error reading shared file $path: $e');
      }
    }
  }

  /// Checks if the content matches typical CSV exports (e.g. Splitwise headers).
  bool _isCsvContent(String content) {
    final lower = content.toLowerCase();
    return lower.contains('date') &&
        lower.contains('description') &&
        lower.contains('cost');
  }

  /// Consumes and clears the pending CSV text.
  String? consumePendingCsv() {
    final val = pendingCsvNotifier.value;
    pendingCsvNotifier.value = null;
    return val;
  }

  void dispose() {
    _intentSub?.cancel();
    pendingCsvNotifier.dispose();
  }
}
