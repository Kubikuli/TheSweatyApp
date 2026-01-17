import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/backup_screen.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone data
  tz.initializeTimeZones();
  // Best-effort set tz.local using device offset to avoid UTC scheduling
  final offset = DateTime.now().timeZoneOffset;
  final hours = offset.inHours;
  final name = hours == 0
      ? 'UTC'
      : (hours >= 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}');
  try {
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {
    // Fallback to UTC if mapping fails
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
  
  // Initialize notifications
  await NotificationService.instance.initialize();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'TheSweatyApp',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'GB'), // English (UK) - Monday-first week
            Locale('en', 'US'), // English (US) - fallback
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              primary: themeProvider.primaryColor,
              surface: const Color(0xFF121212),
            ),
            scaffoldBackgroundColor: const Color(0xFF0F0F0F),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF111111)),
          ),
          home: const MainScreen(),
          routes: {
            '/statistics': (context) => const StatisticsScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/backup': (context) => const BackupScreen(),
          },
        );
      },
    );
  }
}
