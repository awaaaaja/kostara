import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../util/payment_schedule.dart';

/// Pengingat jatuh tempo via local scheduled notification (FR-PAY-03,
/// FR-NOT-01, ADR-006 lokal-first): tanpa push server, tanpa exact-alarm
/// (AndroidScheduleMode.inexact — cukup presisi harian).
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _zone = 'Asia/Jakarta';
  static const _payloadPrefix = 'tenancy:';
  bool _inited = false;

  static const channel = AndroidNotificationDetails(
    'payment_reminder',
    'Pengingat pembayaran',
    channelDescription: 'Pengingat jatuh tempo sewa kos',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const details = NotificationDetails(
    android: channel,
    iOS: DarwinNotificationDetails(),
  );

  tz.Location get _jakarta => tz.getLocation(_zone);

  /// Init sekali per proses: zona waktu WIB + handler notifikasi.
  Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_jakarta);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _inited = true;
  }

  /// Izin notifikasi diminta hanya saat user menyimpan pengingat (JIT).
  /// true bila diberikan / tidak perlu (Android <13).
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = ios == null
        ? null
        : await ios.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? iosGranted ?? true;
  }

  /// Jadwalkan satu pengingat. Lewat waktu → dilewati (bukan error).
  Future<void> schedule({
    required String tenancyId,
    required DateTime dueDate,
    required int offsetDays,
    required String title,
    required String body,
  }) async {
    await init();
    final fire = tz.TZDateTime.from(
      reminderFireUtc(dueDate, offsetDays),
      _jakarta,
    );
    if (!fire.isAfter(tz.TZDateTime.now(_jakarta))) return;
    await _plugin.zonedSchedule(
      id: reminderNotificationId(tenancyId, dueDate, offsetDays),
      scheduledDate: fire,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      title: title,
      body: body,
      payload: '$_payloadPrefix$tenancyId',
    );
  }

  /// Batalkan semua notifikasi milik satu tenancy — dipakai sebelum
  /// resync sehingga tidak ada pengingat ganda (AC-PAY-05).
  Future<void> cancelForTenancy(String tenancyId) async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    for (final r in pending) {
      if (r.payload == '$_payloadPrefix$tenancyId') {
        await _plugin.cancel(id: r.id);
      }
    }
  }
}
