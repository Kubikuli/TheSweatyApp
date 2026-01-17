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

    // Request iOS permissions
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request Android permissions
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // Request notification permission (Android 13+)
      await androidImplementation?.requestNotificationsPermission();
      
      // Request exact alarm permission (Android 12+)
      await androidImplementation?.requestExactAlarmsPermission();
      
      // Create notification channel
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
  Future<void> scheduleDailyWorkoutReminder({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);

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
    );
    if (scheduledDate.isBefore(nowTz)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }


    try {
      // 1) Schedule one-shot exact notification for the next occurrence (ID 1)
      await _notificationsPlugin.zonedSchedule(
        1,
        'Time to work out!',
        'You haven\'t completed a workout yet today. Let\'s get moving!',
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
      );

      // 2) Schedule repeating daily starting tomorrow at the same time (ID 3)
      final tz.TZDateTime startTomorrow = scheduledDate.add(const Duration(days: 1));
      await _notificationsPlugin.zonedSchedule(
        3,
        'Time to work out!',
        'You haven\'t completed a workout yet today. Let\'s get moving!',
        startTomorrow,
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
    } catch (e) {
      // Ignore errors during scheduling
    }
  }

  /// Schedule a daily workout reminder using periodic (inexact) repeats
  Future<void> scheduleDailyWorkoutReminderPeriodic({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);

    // Cancel any existing exact schedules to avoid duplicates
    await _notificationsPlugin.cancel(1);
    await _notificationsPlugin.cancel(3);
    await _notificationsPlugin.cancel(4);

    try {
      await _notificationsPlugin.periodicallyShow(
        4,
        'Time to work out!',
        'You haven\'t completed a workout yet today. Let\'s get moving!',
        RepeatInterval.daily,
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
      );
    } catch (e) {
      // Ignore errors during scheduling
    }
  }

  /// Show an immediate workout reminder notification
  Future<void> showWorkoutReminder() async {
    await _notificationsPlugin.show(
      2,
      'Time to work out!',
      'You haven\'t completed a workout yet today. Let\'s get moving!',
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
    );
  }

  /// Cancel all scheduled reminders
  Future<void> cancelReminders() async {
    await _notificationsPlugin.cancel(1);
    await _notificationsPlugin.cancel(3);
    await _notificationsPlugin.cancel(4);
  }

  /// Get saved reminder time
  Future<Map<String, int>> getSavedReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt('reminder_hour') ?? 9,
      'minute': prefs.getInt('reminder_minute') ?? 0,
    };
  }
}
