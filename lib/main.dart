import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/routes/app_router.dart';
import 'config/theme/theme_provider.dart';
import 'core/config/app_config.dart';
import 'core/services/update_check_service.dart';
import 'core/widgets/update_available_dialog.dart';
import 'data/providers/auth_provider.dart';
import 'data/services/push_notification_service.dart';
import 'data/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  final prefs = await SharedPreferences.getInstance();
  await SupabaseService.initialize();
  await PushNotificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FairShareApp(),
    ),
  );
}

class FairShareApp extends ConsumerStatefulWidget {
  const FairShareApp({super.key});

  @override
  ConsumerState<FairShareApp> createState() => _FairShareAppState();
}

class _FairShareAppState extends ConsumerState<FairShareApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesSilently();
    });
  }

  Future<void> _checkForUpdatesSilently() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final service = ref.read(updateCheckServiceProvider);
      final update = await service.checkForUpdate();
      if (update != null && update.hasUpdate) {
        final navContext = rootNavigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          UpdateAvailableDialog.show(navContext, update);
        }
      }
    } catch (_) {
      // Non-blocking background check
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(themeStyleProvider);
    final themeNotifier = ref.watch(themeModeProvider.notifier);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FairShare',
      debugShowCheckedModeBanner: false,
      theme: themeNotifier.lightTheme,
      darkTheme: themeNotifier.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final mediaQuery = MediaQuery.of(context);
        final isWide = mediaQuery.size.width > 600;
        final responsiveMediaQuery = isWide
            ? mediaQuery.copyWith(
                size: Size(600, mediaQuery.size.height),
              )
            : mediaQuery;

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: MediaQuery(
              data: responsiveMediaQuery,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
