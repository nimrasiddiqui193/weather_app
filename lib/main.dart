import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _themeKey = 'weatherly_dark_mode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final isDark = preferences.getBool(_themeKey) ?? false;

      if (!mounted) return;

      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        _themeLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _themeLoaded = true);
    }
  }

  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

    setState(() => _themeMode = newMode);

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_themeKey, newMode == ThemeMode.dark);
    } catch (_) {
      // The selected theme still works for the current session.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weatherly',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF246BFD),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F6FF),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF75B8FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101827),
        useMaterial3: true,
      ),
      home:
          _themeLoaded
              ? HomeScreen(
                isDarkMode: _themeMode == ThemeMode.dark,
                onThemeToggle: toggleTheme,
              )
              : const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
    );
  }
}
