import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'constants.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/text_translate_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/live_call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // SQLite FFI needed for Windows/Linux/macOS (not needed on mobile/web)
  if (!kIsWeb) {
    _initDesktopDb();
  }

  runApp(const AIVoiceTranslatorApp());
}

void _initDesktopDb() {
  // Import dart:io lazily — this function is never called on web
  // ignore: avoid_dynamic_calls
  try {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } catch (_) {
    // On mobile (Android/iOS), sqflite works natively — no FFI needed
  }
}

class AIVoiceTranslatorApp extends StatelessWidget {
  const AIVoiceTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Voice Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: kPrimary,
          secondary: kAccent,
          surface: kSurface,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: kTextPrimary,
          error: kError,
        ),
        scaffoldBackgroundColor: kBackground,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
            color: kTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: kTextPrimary),
        ),
      ),
      home: _getHomeRoute(),
    );
  }

  Widget _getHomeRoute() {
    if (kIsWeb) {
      final room = Uri.base.queryParameters['room'];
      if (room != null && room.isNotEmpty) {
        return LiveCallScreen(initialRoom: room);
      }
    }
    return const AuthGate();
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kBackground,
            body: Center(child: CircularProgressIndicator(color: kPrimaryLight)),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }
        return const MainNavigation();
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    HomeScreen(),
    LiveCallScreen(),
    TextTranslateScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kBorder.withOpacity(0.5))),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: kPrimaryLight,
          unselectedItemColor: kTextHint,
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.mic_none_rounded), activeIcon: Icon(Icons.mic_rounded), label: 'Voice'),
            BottomNavigationBarItem(icon: Icon(Icons.call_outlined), activeIcon: Icon(Icons.call_rounded), label: 'Call'),
            BottomNavigationBarItem(icon: Icon(Icons.keyboard_outlined), activeIcon: Icon(Icons.keyboard_rounded), label: 'Text'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
