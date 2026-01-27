import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> initialize() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(initializationSettings);

    // Create notification channel (Android)
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'workout_reminder',
        'Workout Reminders',
        description: 'Reminders to complete your daily workout',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      await androidImplementation?.createNotificationChannel(channel);
    }
  }

  /// Schedule a daily workout reminder
  /// Uses matchDateTimeComponents for true daily repetition
  /// Returns true if scheduled successfully, false if permissions were denied
  Future<bool> scheduleDailyWorkoutReminder({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);

    // Request iOS permissions if needed
    if (Platform.isIOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      final granted =
          await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;

      if (!granted) {
        return false;
      }
    }

    // Check and request permissions on Android
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Check if notifications are already enabled
      final notificationsEnabled =
          await androidImplementation?.areNotificationsEnabled() ?? false;

      if (!notificationsEnabled) {
        // Try to request - this only works once
        final granted =
            await androidImplementation?.requestNotificationsPermission() ??
            false;
        if (!granted) {
          return false;
        }
      }

      // Check exact alarm permission
      final canSchedule =
          await androidImplementation?.canScheduleExactNotifications() ?? false;

      if (!canSchedule) {
        // Request exact alarm permission (opens settings)
        await androidImplementation?.requestExactAlarmsPermission();

        // Check again after user returns
        final canScheduleNow =
            await androidImplementation?.canScheduleExactNotifications() ??
            false;
        if (!canScheduleNow) {
          return false;
        }
      }
    }

    // Cancel existing reminder
    await _notificationsPlugin.cancel(1);

    // Schedule next instance using tz-aware time
    final tz.TZDateTime nowTz = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      nowTz.year,
      nowTz.month,
      nowTz.day,
      hour,
      minute,
      0, // seconds
      0, // milliseconds
      0, // microseconds
    );

    // If the scheduled time is in the past, schedule for tomorrow
    if (scheduledDate.isBefore(nowTz)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      // Schedule with matchDateTimeComponents for daily repetition
      await _notificationsPlugin.zonedSchedule(
        1,
        'Time to move!',
        'Have you worked out yet today? Let\'s get moving! At least a little bit...',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_reminder',
            'Workout Reminders',
            channelDescription: 'Reminders to complete your daily workout',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel all scheduled reminders
  Future<void> cancelReminders() async {
    await _notificationsPlugin.cancel(1);
  }
}
