import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_prices/app.dart';
import 'package:gold_prices/main.dart' as app;
import 'package:gold_prices/state/alerts.dart';
import 'package:gold_prices/state/prices.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks through every screen on the emulator with live prices, checks they work,
/// and captures screenshots (for review and the store listing).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text).hitTestable().evaluate().isNotEmpty ? find.text(text).hitTestable().first : find.text(text).first;
    await t.ensureVisible(f);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(f, warnIfMissed: false);
  }

  testWidgets('screens render with live prices', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('country', 'SA');
    await prefs.setInt('theme', 2);

    app.main();
    await settle(tester, 1500);
    await binding.convertFlutterSurfaceToImage();
    // wait for live prices (up to 40 s)
    for (var i = 0; i < 40 && find.textContaining('آخر تحديث').evaluate().isEmpty; i++) {
      await settle(tester, 1000);
    }
    await settle(tester, 3000);
    final ctx = tester.element(find.byType(HomeShell));
    final prices = ctx.read<PriceController>();
    debugPrint('GOLD: xau=${prices.quote?.xau} sar24=${prices.gram(24)} change=${prices.change} hist=${prices.history.length}');
    expect(prices.gram(24), isNotNull);
    expect(find.text('عيار 21'), findsWidgets);
    await binding.takeScreenshot('01_prices_dark');

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await settle(tester);
    await binding.takeScreenshot('02_prices_scrolled');
    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await settle(tester);

    // Country picker -> UAE (tola row) -> Egypt (gold pound row)
    await tester.tap(find.byKey(const Key('country-button')).first);
    await settle(tester);
    await binding.takeScreenshot('03_country_picker');
    await tester.enterText(find.byKey(const Key('country-search')), 'مصر');
    await settle(tester);
    await tester.tap(find.byKey(const Key('country-EG')));
    await settle(tester, 2000);
    expect(prices.country.code, 'EG');
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await settle(tester);
    expect(find.text('الجنيه الذهب'), findsOneWidget);
    await binding.takeScreenshot('04_prices_egypt');

    await tester.tap(find.byKey(const Key('country-button')).first);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('country-search')), 'الإمارات');
    await settle(tester);
    await tester.tap(find.byKey(const Key('country-AE')));
    await settle(tester, 2000);
    expect(find.text('التولة'), findsOneWidget);
    await binding.takeScreenshot('05_prices_uae');

    // Light theme for store shots
    await prices.setThemeMode(1);
    await settle(tester, 1500);
    await tester.drag(find.byType(ListView).first, const Offset(0, 800));
    await settle(tester);
    await binding.takeScreenshot('06_prices_light');

    // Chart
    await tapText(tester, 'الرسم البياني');
    await settle(tester, 4000);
    for (var i = 0; i < 20 && prices.history.isEmpty; i++) {
      await settle(tester, 1000);
    }
    expect(prices.history, isNotEmpty);
    expect(find.text('أعلى سعر'), findsOneWidget);
    await binding.takeScreenshot('07_chart_month');
    await tapText(tester, 'سنة');
    await settle(tester, 2000);
    await binding.takeScreenshot('08_chart_year');

    // Calculator
    await tapText(tester, 'الحاسبة');
    await settle(tester);
    await tester.enterText(find.byKey(const Key('calc-grams')), '25');
    await settle(tester, 500);
    await tester.enterText(find.widgetWithText(TextField, 'المصنعية للجرام'), '30');
    await settle(tester, 500);
    await tapText(tester, '5%');
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    expect(find.text('الإجمالي التقريبي'), findsOneWidget);
    await binding.takeScreenshot('09_calc_jewelry');
    await tapText(tester, 'زكاة الذهب');
    await settle(tester);
    await tester.enterText(find.byKey(const Key('zakat-21')), '120');
    await tester.enterText(find.byKey(const Key('zakat-18')), '40');
    await settle(tester, 500);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await settle(tester);
    expect(find.text('الزكاة الواجبة (2.5%)'), findsOneWidget);
    await binding.takeScreenshot('10_calc_zakat');

    // Alerts: empty state, then one that must fire right away (target below the price).
    await tapText(tester, 'التنبيهات');
    await settle(tester);
    await binding.takeScreenshot('11_alerts_empty');
    await tester.tap(find.byKey(const Key('add-alert')));
    await settle(tester);
    await binding.takeScreenshot('12_alert_sheet');
    final now = prices.gram(21)!;
    await tester.enterText(find.byKey(const Key('alert-target')), (now * .5).toStringAsFixed(0));
    await settle(tester, 500);
    await tester.tap(find.byKey(const Key('save-alert')));
    await settle(tester, 3000);
    final alerts = ctx.read<AlertController>();
    expect(alerts.alerts.length, 1);
    await alerts.add(country: 'AE', karat: 24, above: false, target: (prices.gram(24)! * .97).roundToDouble());
    await prices.refresh(); // fresh quote -> foreground alert check -> notification
    await settle(tester, 4000);
    debugPrint('GOLD_ALERTS: ${alerts.alerts.map((a) => '${a.id}:${a.enabled}:${a.firedPrice}').join(',')}');
    expect(alerts.alerts.first.firedAt, isNotNull);
    expect(alerts.alerts.last.enabled, isTrue);
    await binding.takeScreenshot('13_alerts_list');
    await settle(tester, 8000); // let the watcher see the notification
  });
}
