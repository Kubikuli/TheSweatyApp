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

  // Try to find the actual local timezone
  try {
    final offset = DateTime.now().timeZoneOffset;
    final offsetHours = offset.inHours;

    // Map offset to timezone locations that handle DST correctly
    String locationName;

    if (offsetHours == 0) {
      locationName = 'UTC';
    } else if (offsetHours == 1) {
      // Central European Time (Winter) or Western European Time
      locationName = 'Europe/Berlin'; // Handles CET/CEST (UTC+1/+2)
    } else if (offsetHours == 2) {
      // Central European Summer Time or Eastern European Time
      locationName =
          'Europe/Berlin'; // Most likely CEST (summer time in Central Europe)
    } else if (offsetHours == 3) {
      locationName = 'Europe/Moscow'; // MSK
    } else if (offsetHours == -5) {
      locationName = 'America/New_York'; // EST/EDT
    } else if (offsetHours == -6) {
      locationName = 'America/Chicago'; // CST/CDT
    } else if (offsetHours == -7) {
      locationName = 'America/Denver'; // MST/MDT
    } else if (offsetHours == -8) {
      locationName = 'America/Los_Angeles'; // PST/PDT
    } else {
      // Fallback to Etc/GMT notation (no DST)
      locationName = offsetHours >= 0
          ? 'Etc/GMT-$offsetHours'
          : 'Etc/GMT+${-offsetHours}';
    }

    tz.setLocalLocation(tz.getLocation(locationName));
  } catch (e) {
    // Ultimate fallback to UTC
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
