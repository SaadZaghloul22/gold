import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/countries.dart';
import 'services/alert_service.dart';
import 'services/price_service.dart';
import 'state/alerts.dart';
import 'state/prices.dart';

/// Picks the starting country from the phone's region (Saudi Arabia otherwise).
String guessCountry() {
  final region = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
  final match = countries.where((c) => c.code == region);
  if (match.isNotEmpty) return match.first.code;
  if (region != null && const {'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'IE', 'PT', 'FI', 'GR'}.contains(region)) return 'DE';
  return 'SA';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final prices = PriceController(prefs, PriceService(prefs), defaultCountry: guessCountry());
  final alerts = AlertController(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: prices),
        ChangeNotifierProvider.value(value: alerts),
      ],
      child: const GoldApp(),
    ),
  );

  Future(() async {
    await Notifier.instance.init();
    await syncAlertWork(alerts.anyEnabled);
  });
}
