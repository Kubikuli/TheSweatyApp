import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TheSweatyApp',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurple,
          surface: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF111111)),
      ),
      home: const MainScreen(),
      routes: {
        '/statistics': (context) => const StatisticsScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
