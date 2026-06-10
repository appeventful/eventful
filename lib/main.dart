import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth_wrapper.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/onboarding_screen.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Uygulama sadece dikey modda çalışsın
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Initialize date formatting
    await initializeDateFormatting('tr_TR', null);

    // Firebase'i başlat
    debugPrint("Firebase starting...");
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // App Check'i başlat
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );

      debugPrint("Firebase initialized!");
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
    }

    // Firestore Önbellek Ayarları
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Görüntü Önbelleğini Artır (Daha akıcı kaydırma için)
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;

    // Initialize notification service
    await NotificationService.initialize();

    // Device ID (Debug için)
    AuthService().getDeviceId().then((id) => debugPrint("DEVICE_ID: $id")).catchError((e) => debugPrint("Device ID Error: $e"));

    // Misafir girişini arka planda başlat (Hız kazandırmak için)
    if (FirebaseAuth.instance.currentUser == null) {
      AuthService().signInAnonymously().catchError((e) {
        debugPrint("Anonymous Sign-In Error: $e");
        return null;
      });
    }

    bool showOnboarding = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      showOnboarding = prefs.getBool('onboarding_completed') != true;
    } catch (e) {
      debugPrint("SharedPreferences Error: $e");
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: MyApp(showOnboarding: showOnboarding),
      ),
    );
  } catch (e, stack) {
    debugPrint("CRITICAL ERROR: $e");
    debugPrint(stack.toString());
    
    // Hata olsa bile uygulamayı başlatmaya çalış (En azından hata ekranı veya boş bir ekran görünebilsin)
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MyApp(showOnboarding: true),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Eventful',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.orange,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.orange,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr', 'TR'),
          ],
          locale: const Locale('tr', 'TR'),
          routes: {
            '/admin_panel': (context) => const AdminPanelScreen(),
          },
          home: showOnboarding ? const OnboardingScreen() : const AuthWrapper(),
        );
      },
    );
  }
}
