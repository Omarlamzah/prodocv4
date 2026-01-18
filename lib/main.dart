// lib/main.dart - Updated with intl initialization and edge-to-edge support
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // Add this import for locale support
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'providers/locale_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (optional - only if google-services.json is configured)
  try {
    await Firebase.initializeApp();
    debugPrint('[Main] Firebase initialized successfully');

    // Initialize FCM service for push notifications (only if Firebase is available)
    await FCMService().initialize();
  } catch (e) {
    debugPrint('[Main] Firebase not configured or initialization error: $e');
    debugPrint(
      '[Main] Local notifications will still work, but FCM push notifications when app is closed require Firebase setup',
    );
    debugPrint(
      '[Main] To enable FCM: Configure google-services.json (see FCM_BACKEND_INTEGRATION.md)',
    );
  }

  // Initialize notification service (always works, even without Firebase)
  await NotificationService().initialize();

  // Configure system UI for edge-to-edge display (Android 15+ compatibility)
  // This ensures proper handling of system bars and insets
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // Status bar configuration
      statusBarColor:
          Colors.transparent, // Transparent status bar for edge-to-edge
      statusBarIconBrightness: Brightness.dark, // Dark icons (light background)
      statusBarBrightness: Brightness.light, // For iOS
      // Navigation bar configuration
      systemNavigationBarColor:
          Colors.transparent, // Transparent navigation bar
      systemNavigationBarIconBrightness:
          Brightness.dark, // Dark navigation icons
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Enable edge-to-edge mode
  // This allows content to extend behind system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize date formatting for English, French, and Arabic
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('ar_SA', null);

  // Wrap app with DevicePreview (only in debug mode)
  runApp(
    DevicePreview(
      enabled: kDebugMode, // Only enable in debug mode
      builder: (context) => const ProviderScope(child: MyApp()),
    ),
  );
}

// Global navigator key for showing dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeProvider);
    // Only use DevicePreview locale in debug mode if user hasn't explicitly set a locale
    // Prioritize user's selected locale over DevicePreview
    final devicePreviewLocale =
        kDebugMode ? DevicePreview.locale(context) : null;
    // User's selected locale takes priority over DevicePreview
    final currentLocale = localeState.locale;

    debugPrint('[MyApp] build() called');
    debugPrint(
        '[MyApp] localeState.locale: ${localeState.locale.languageCode}_${localeState.locale.countryCode}');
    debugPrint('[MyApp] devicePreviewLocale: $devicePreviewLocale');
    debugPrint(
        '[MyApp] currentLocale (final - user selected): ${currentLocale.languageCode}_${currentLocale.countryCode}');
    debugPrint(
        '[MyApp] MaterialApp key will be: app_locale_${currentLocale.languageCode}_${currentLocale.countryCode}');

    return MaterialApp(
      // Global navigator key for showing dialogs
      navigatorKey: navigatorKey,
      // Key changes with locale to force AppLocalizations to update
      // This ensures all widgets get the new locale immediately
      key: ValueKey(
          'app_locale_${currentLocale.languageCode}_${currentLocale.countryCode}'),
      // DevicePreview integration
      builder: DevicePreview.appBuilder,
      locale: currentLocale,

      title: 'NextPital Mobile App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('fr', 'FR'),
        Locale('ar', 'SA'),
      ],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
