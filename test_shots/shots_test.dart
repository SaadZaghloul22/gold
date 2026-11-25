// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_prices/app.dart';
import 'package:gold_prices/data/countries.dart';
import 'package:gold_prices/services/price_service.dart';
import 'package:gold_prices/state/alerts.dart';
import 'package:gold_prices/state/prices.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every screen with LIVE prices (CI has internet) at phone size and writes PNGs
/// to screenshots/ — used to review the UI and for the store listing (no emulator needed).
Future<void> loadFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final l = FontLoader(name);
    for (final a in assets) {
      l.addFont(rootBundle.load(a));
    }
    await l.load();
  }

  await family('Cairo', [
    'assets/fonts/Cairo_400Regular.ttf',
    'assets/fonts/Cairo_600SemiBold.ttf',
    'assets/fonts/Cairo_700Bold.ttf',
    'assets/fonts/Cairo_800ExtraBold.ttf',
  ]);
  await family('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  for (final p in ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', '/usr/share/fonts/noto/NotoColorEmoji.ttf']) {
    final f = File(p);
    if (f.existsSync()) {
      final l = FontLoader('NotoColorEmoji')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await l.load();
      break;
    }
  }
}

void main() {
  const size = Size(412, 915); // 1080 x 2400 at 2.625
  const ratio = 2.625;
  final shotKey = GlobalKey();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 400));
    await t.runAsync(() async {
      final ro = shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await ro.toImage(pixelRatio: ratio);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('screenshots/$name.png')..createSync(recursive: true);
      f.writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> settle(WidgetTester t, [int ms = 800]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('store and review screenshots', (tester) async {
    HttpOverrides.global = null; // real network for live prices
    await initializeDateFormatting('ar');
    await loadFonts();
    tester.view.physicalSize = size * ratio;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'country': 'SA', 'theme': 2});
    final prefs = await SharedPreferences.getInstance();
    final service = PriceService(prefs);
    final prices = PriceController(prefs, service, defaultCountry: 'SA');
    final alerts = AlertController(prefs);
    prices.autoRefresh = false;
    await tester.runAsync(() async {
      await prices.loadHistory();
      // shared CI IPs get rate-limited now and then: keep trying for a live quote
      for (var i = 0; i < 8; i++) {
        await prices.refresh();
        if (prices.quote != null && !prices.quote!.fromHistory) break;
        await Future<void>.delayed(const Duration(seconds: 15));
      }
    });
    debugPrint('SHOTS: xau=${prices.quote?.xau} sar24=${prices.gram(24)} hist=${prices.history.length} change=${prices.change}');
    expect(prices.gram(24), isNotNull);
    expect(prices.history, isNotEmpty);
    if (prices.quote!.fromHistory) debugPrint('SHOTS: live price unavailable, using last close');

    await tester.pumpWidget(RepaintBoundary(
      key: shotKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: prices),
          ChangeNotifierProvider.value(value: alerts),
        ],
        child: const GoldApp(),
      ),
    ));
    await settle(tester, 1500);
    await shot(tester, '01_prices_dark');

    final shell = tester.state<HomeShellState>(find.byType(HomeShell));
    await prices.setThemeMode(1);
    await settle(tester);
    await shot(tester, '02_prices_light');
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await settle(tester);
    await shot(tester, '03_prices_scrolled');
    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await settle(tester);

    await tester.tap(find.byKey(const Key('country-button')).first);
    await settle(tester);
    await shot(tester, '04_country_picker');
    Navigator.of(tester.element(find.byType(TextField).last)).pop();
    await settle(tester);

    for (final code in ['AE', 'EG', 'KW']) {
      await prices.setCountry(countryByCode(code));
      await settle(tester);
      await shot(tester, '05_prices_${code.toLowerCase()}');
    }
    await prices.setCountry(countryByCode('SA'));

    shell.go(1);
    await settle(tester);
    await shot(tester, '06_chart_month');
    await tester.tap(find.text('سنة'));
    await settle(tester);
    await shot(tester, '07_chart_year');

    shell.go(2);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('calc-grams')), '25');
    await tester.enterText(find.widgetWithText(TextField, 'المصنعية للجرام'), '30');
    await tester.tap(find.text('15%'));
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await shot(tester, '08_calc_jewelry');
    await tester.tap(find.text('زكاة الذهب'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('zakat-21')), '120');
    await tester.enterText(find.byKey(const Key('zakat-18')), '40');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await settle(tester);
    expect(find.text('الزكاة الواجبة (2.5%)'), findsOneWidget);
    await shot(tester, '09_calc_zakat');

    shell.go(3);
    await settle(tester);
    await shot(tester, '10_alerts_empty');
    await alerts.add(country: 'SA', karat: 21, above: true, target: (prices.gram(21)! * 1.02).roundToDouble());
    await alerts.add(country: 'SA', karat: 24, above: false, target: (prices.gram(24)! * .97).roundToDouble());
    await settle(tester);
    await shot(tester, '11_alerts_list');
    await tester.tap(find.byKey(const Key('add-alert')));
    await settle(tester);
    await shot(tester, '12_alert_sheet');

    prices.stop();
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
