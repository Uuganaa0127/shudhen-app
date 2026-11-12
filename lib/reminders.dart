import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Reminders {
  final plugin = FlutterLocalNotificationsPlugin();
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<bool> initialize(VoidCallback onTap) async {
    if (!supported) return false;
    tzdata.initializeTimeZones();
    await plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false)),
        onDidReceiveNotificationResponse: (_) => onTap());
    return (await plugin.getNotificationAppLaunchDetails())
            ?.didNotificationLaunchApp ??
        false;
  }

  Future<bool> schedule(List<Map<String, dynamic>> reminders) async {
    if (!supported) return false;
    final active = reminders.where((r) => r['enabled'] == true).toList();
    if (active.isEmpty) {
      await plugin.cancelAll();
      return true;
    }
    bool allowed = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      allowed = await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } else {
      allowed = await plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (!allowed) return false;
    await plugin.cancelAll();
    // Schedule individual local dates so DST changes retain the chosen wall time.
    final now = DateTime.now();
    final dates = <DateTime>[];
    for (int day = 0; day <= 30; day++) {
      for (final r in active) {
        final date = DateTime(now.year, now.month, now.day + day,
            r['hour'] as int, r['minute'] as int);
        if (date.isAfter(now)) dates.add(date);
      }
    }
    dates.sort();
    for (int id = 0; id < dates.length && id < 60; id++) {
      final date = dates[id];
      await plugin.zonedSchedule(
          id,
          'Инээмсэглэлээ гэрэлтүүлэх цаг боллоо! ✨',
          'Шүдээ угаах цаг боллоо. Шүдхэн найзтайгаа уулзаарай.',
          tz.TZDateTime.from(date, tz.UTC),
          const NotificationDetails(
              android: AndroidNotificationDetails('brush', 'Угаах сануулга',
                  channelDescription: 'Өдөр тутмын шүд угаах цаг',
                  importance: Importance.high,
                  priority: Priority.high),
              iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
    }
    return true;
  }
}
