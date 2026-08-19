import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/chat_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/force_change_credentials_screen.dart';
import 'services/session.dart';
import 'services/socket_service.dart';
import 'services/call_listener.dart';
import 'services/notification_service.dart';
import 'services/offline_queue.dart';
import 'config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore dynamic API config and saved login
  await ApiConfig.load();
  await Session.load();

  if (Session.isLoggedIn) {
    SocketService.instance.connect();
  }
  CallListener.init();

  // Restore saved theme
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  // Restore saved language (Arabic / English)
  final localeProvider = LocaleProvider();
  await localeProvider.load();

  // Notifications must render titles/bodies in the chosen language.
  localeProvider.addListener(() {
    NotificationService.locale =
        localeProvider.locale ?? const Locale('en');
  });

  // Offline message queue + notifications.
  await OfflineQueue.instance.init();
  await NotificationService.init();
  MessageNotificationListener.instance.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => themeProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => localeProvider,
        ),

        ChangeNotifierProvider(
          create: (_) => ProfileProvider(),
        ),
      ],
      child: const ChatApp(),
    ),
  );
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      navigatorKey: CallListener.navigatorKey,
      debugShowCheckedModeBanner: false,

      themeMode: themeProvider.themeMode,

      locale: localeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ================= LIGHT THEME =================
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: const ColorScheme.light(
          primary: Color(0xFF075E54),
          secondary: Color(0xFF25D366),
          surface: Colors.white,
        ),

        scaffoldBackgroundColor: Colors.white,

        cardColor: Colors.white,

        dividerColor: Color(0xFFE0E0E0),

        hintColor: Colors.black54,

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF075E54),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),


        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F2F2),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Color(0xFF25D366),
              width: 2,
            ),
          ),
        ),

        iconTheme: const IconThemeData(
          color: Color(0xFF075E54),
        ),

        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF075E54),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF075E54),
          selectionColor: Color(0x5525D366),
          selectionHandleColor: Color(0xFF25D366),
        ),

        floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF25D366),
          foregroundColor: Colors.white,
        ),

        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),

        searchBarTheme: SearchBarThemeData(
          backgroundColor: WidgetStatePropertyAll(
            Colors.grey.shade200,
          ),
          hintStyle: const WidgetStatePropertyAll(
            TextStyle(color: Colors.black54),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(color: Colors.black87),
          ),
        ),
      ),

      // ================= DARK THEME =================
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF075E54),
          secondary: Color(0xFF25D366),
          surface: Color(0xFF1E1E1E),
        ),

        scaffoldBackgroundColor: const Color(0xFF121212),
        canvasColor: const Color(0xFF1E1E1E),


        dividerColor: Colors.white24,

        hintColor: Colors.white60,

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),

        cardColor: const Color(0xFF1E1E1E),

        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),

        searchBarTheme: const SearchBarThemeData(
          backgroundColor: WidgetStatePropertyAll(
            Color(0xFF2A2A2A),
          ),
          hintStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.white54),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.white),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Color(0xFF25D366),
              width: 2,
            ),
          ),
        ),

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),

        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF25D366),
          selectionColor: Color(0x5525D366),
          selectionHandleColor: Color(0xFF25D366),
        ),

        floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF25D366),
          foregroundColor: Colors.white,
        ),

        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),

      // ================= START SCREEN =================
      home: Session.isLoggedIn
          ? (Session.isAdmin
              ? (Session.mustChangeCredentials
                  ? const ForceChangeCredentialsScreen()
                  : const AdminDashboardScreen())
              : const ChatListScreen())
          : const LoginScreen(),
    );
  }
}