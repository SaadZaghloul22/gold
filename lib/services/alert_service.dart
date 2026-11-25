import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/format.dart';
import '../state/alerts.dart';
import 'price_service.dart';

const alertTask = 'gold.price_alerts';

/// Shows price-alert notifications.
class Notifier {
  Notifier._();
  static final instance = Notifier._();
  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'price_alerts',
    'تنبيهات الأسعار',
    channelDescription: 'تنبيه عند وصول سعر الذهب إلى السعر الذي حددته',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFFD4A537),
  );

  Future<void> init() async {
    if (_ready) return;
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_gold')),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> showFired(PriceAlert a) async {
    await init();
    final c = a.c;
    final price = a.firedPrice == null ? '' : ' — السعر الآن ${moneyIn(a.firedPrice!, c)}';
    await plugin.show(
      id: 1000 + a.id,
      title: a.above ? 'ارتفع سعر الذهب ${c.flag}' : 'انخفض سعر الذهب ${c.flag}',
      body: 'جرام عيار ${a.karat} وصل إلى السعر الذي حددته (${money(a.target, c.decimals)} ${c.unit})$price',
      notificationDetails: const NotificationDetails(android: _channel),
    );
  }
}

/// Background check (WorkManager, about every 30 minutes when there are active alerts).
@pragma('vm:entry-point')
void alertDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final store = AlertStore(prefs);
      final alerts = store.load();
      if (!alerts.any((a) => a.enabled)) return true;
      final quote = await PriceService(prefs).fetch();
      final r = evaluateAlerts(alerts, quote);
      if (r.fired.isEmpty) return true;
      await store.save(r.updated);
      for (final a in r.fired) {
        await Notifier.instance.showFired(a);
      }
      return true;
    } catch (e) {
      debugPrint('alert worker: $e');
      return true; // try again on the next period, not with backoff
    }
  });
}

/// Keeps the periodic job registered only while at least one alert is on.
Future<void> syncAlertWork(bool anyEnabled) async {
  try {
    await Workmanager().initialize(alertDispatcher);
    if (anyEnabled) {
      await Workmanager().registerPeriodicTask(
        alertTask,
        alertTask,
        frequency: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      await Workmanager().cancelByUniqueName(alertTask);
    }
  } catch (e) {
    debugPrint('syncAlertWork: $e');
  }
}
