import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gold_prices/core/format.dart';
import 'package:gold_prices/core/gold_math.dart';
import 'package:gold_prices/data/countries.dart';
import 'package:gold_prices/services/price_service.dart';
import 'package:gold_prices/state/alerts.dart';
import 'package:gold_prices/state/prices.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Quote quote({double xau = 3110.35, double? xag = 31.1035, Map<String, double>? fx, DateTime? fxAt}) => Quote(
      xau: xau,
      xag: xag,
      sourceAt: DateTime.now(),
      fetchedAt: DateTime.now(),
      fx: fx ?? const {'EGP': 50, 'KWD': 0.3, 'INR': 88},
      fxAt: fxAt ?? DateTime.now(),
    );

MockClient api({double xau = 3110.35, int status = 200, int goldStatus = 200, bool swiss = false}) => MockClient((r) async {
      final u = r.url.toString();
      if (status != 200) return http.Response('err', status);
      if (u.contains('gold-api') && goldStatus != 200) return http.Response('slow down', goldStatus);
      if (u.contains('swissquote') && swiss) {
        final mid = u.contains('XAU') ? 3110.35 : 31.1035;
        return http.Response(
            jsonEncode([
              {
                'topo': {'platform': 'x'},
                'spreadProfilePrices': [
                  {'spreadProfile': 'premium', 'bid': mid - 0.5, 'ask': mid + 0.5}
                ],
                'ts': 1795564951000,
              }
            ]),
            200);
      }
      if (u.endsWith('/XAU')) return http.Response(jsonEncode({'price': xau, 'updatedAt': '2026-11-25T08:54:45Z'}), 200);
      if (u.endsWith('/XAG')) return http.Response(jsonEncode({'price': 40.0, 'updatedAt': '2026-11-25T08:54:45Z'}), 200);
      if (u.contains('er-api')) {
        return http.Response(
            jsonEncode({'result': 'success', 'time_last_update_unix': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'rates': {'EGP': 50.0, 'KWD': 0.31}}),
            200);
      }
      if (u.contains('gold-history')) {
        return http.Response(
            jsonEncode({
              'rows': [
                {'day': '2026-11-20', 'usdGram': 100.0, 'fx': {'EGP': 49.0}},
                {'day': '2026-11-21', 'usdGram': 101.0, 'fx': {'EGP': 49.5}},
                {'day': 'bad', 'usdGram': 1},
              ]
            }),
            200);
      }
      return http.Response('not found', 404);
    });

void main() {
  group('math', () {
    test('gram price uses troy ounce and purity', () {
      expect(gramPrice(usdPerOunce: 3110.35, usdToLocal: 1), closeTo(100, 1e-9));
      expect(gramPrice(usdPerOunce: 3110.35, usdToLocal: 3.75, karat: 21), closeTo(328.125, 1e-9));
      expect(purity(18), .75);
    });

    test('percent change', () {
      expect(percentChange(100, 101), closeTo(1, 1e-9));
      expect(percentChange(0, 5), 0);
    });

    test('jewellery purchase adds workmanship then VAT on both', () {
      final r = purchase(grams: 10, pricePerGram: 300, workmanshipPerGram: 20, vatPercent: 15);
      expect(r.gold, 3000);
      expect(r.workmanship, 200);
      expect(r.vat, closeTo(480, 1e-9));
      expect(r.total, closeTo(3680, 1e-9));
      final t = purchase(grams: 10, pricePerGram: 300, workmanshipTotal: 150);
      expect(t.total, 3150);
    });

    test('zakat: nisab is 85 g pure', () {
      final below = zakat(gramsByKarat: {21: 90}, price24PerGram: 100); // 78.75 g pure
      expect(below.reachesNisab, isFalse);
      expect(below.due, 0);
      expect(below.missingGrams, closeTo(6.25, 1e-9));
      final above = zakat(gramsByKarat: {24: 50, 18: 60}, price24PerGram: 100); // 50 + 45 = 95 g
      expect(above.pureGrams, closeTo(95, 1e-9));
      expect(above.due, closeTo(95 * 100 * .025, 1e-9));
    });
  });

  group('countries and rates', () {
    test('41 unique countries/currencies with valid decimals', () {
      expect(countries.length, 41);
      expect(countries.map((c) => c.code).toSet().length, 41);
      expect(countries.map((c) => c.currency).toSet().length, 41);
      for (final c in countries) {
        expect([0, 2, 3], contains(c.decimals), reason: c.code);
      }
      expect(countryByCode('XX').code, 'AE');
      expect(countryByCode('KW').decimals, 3);
    });

    test('pegs win over market rate; stale fx is ignored', () {
      final q = quote(fx: {'SAR': 3.7, 'EGP': 50});
      expect(q.rate('SAR'), 3.75);
      expect(q.rate('EGP'), 50);
      expect(q.rate('ZZZ'), isNull);
      final old = quote(fxAt: DateTime.now().subtract(const Duration(days: 5)));
      expect(old.rate('EGP'), isNull);
      expect(old.rate('AED'), 3.6725);
    });

    test('quote json round trip', () {
      final q = quote();
      final back = Quote.fromJson(jsonDecode(jsonEncode(q.toJson())) as Map<String, dynamic>)!;
      expect(back.xau, q.xau);
      expect(back.fx['EGP'], 50);
      expect(Quote.fromJson({'xau': 'x'}), isNull);
    });
  });

  group('service', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('fetch caches; offline keeps cache', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = PriceService(prefs, client: api());
      final q = await s.fetch();
      expect(q.xau, 3110.35);
      expect(q.xag, 40);
      expect(q.rate('EGP'), 50);
      expect(s.cached!.xau, 3110.35);
      final off = PriceService(prefs, client: api(status: 500));
      await expectLater(off.fetch(), throwsException);
      expect(off.cached!.xau, 3110.35);
    });

    test('rejects nonsense price', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(PriceService(prefs, client: api(xau: 3)).fetch(), throwsException);
    });

    test('history parse skips bad rows and sorts', () {
      final h = PriceService.parseHistory({
        'rows': [
          {'day': '2026-11-21', 'usdGram': 101, 'fx': {'EGP': 49.5}},
          {'day': '2026-11-20', 'usdGram': 100, 'fx': {}},
          {'day': 'x', 'usdGram': 1},
          {'day': '2026-11-19', 'usdGram': -1},
        ]
      });
      expect(h.length, 2);
      expect(h.first.day, DateTime(2026, 11, 20));
      expect(h.last.local('EGP'), closeTo(4999.5, 1e-9));
      expect(h.first.local('SAR'), 375); // peg
      expect(h.first.local('EGP'), isNull);
    });

    test('controller: rows, change vs previous close, series', () async {
      final prefs = await SharedPreferences.getInstance();
      final p = PriceController(prefs, PriceService(prefs, client: api()), defaultCountry: 'EG');
      await p.refresh();
      await p.loadHistory();
      expect(p.country.code, 'EG');
      expect(p.gram(24), closeTo(5000, 1e-6));
      expect(p.rows.map((r) => r.label), contains('الجنيه الذهب'));
      expect(p.rows.map((r) => r.label), isNot(contains('التولة')));
      expect(p.previousClose!.day, DateTime(2026, 11, 21));
      expect(p.change, closeTo((5000 - 4999.5) / 4999.5 * 100, 1e-6));
      final s = p.series(365, 24);
      expect(s.length, 3); // two days + today live
      expect(s.last.value, closeTo(5000, 1e-6));
      await p.setCountry(countryByCode('AE'));
      expect(p.rows.map((r) => r.label), contains('التولة'));
      p.dispose();
    });
  });

  test('backup live source when the main one is rate-limited', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final q = await PriceService(prefs, client: api(goldStatus: 429, swiss: true)).fetch();
    expect(q.xau, closeTo(3110.35, 1e-9));
    expect(q.xag, closeTo(31.1035, 1e-9));
    expect(q.fromHistory, isFalse);
  });

  test('rate-limited live price falls back to the last daily close', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final p = PriceController(prefs, PriceService(prefs, client: api(goldStatus: 429)), defaultCountry: 'SA');
    await p.refresh();
    expect(p.quote!.fromHistory, isTrue);
    expect(p.quote!.xau, closeTo(101 * troyOunceGrams, 1e-6));
    expect(p.gram(24), closeTo(101 * 3.75, 1e-6));
    expect(p.error, contains('آخر إغلاق'));
    expect(prefs.getString('quote_v1'), isNull); // never cached
    p.dispose();
  });

  group('alerts', () {
    test('fire once, then disabled', () {
      final alerts = [
        const PriceAlert(id: 1, country: 'SA', karat: 24, above: true, target: 370),
        const PriceAlert(id: 2, country: 'SA', karat: 24, above: false, target: 370),
        const PriceAlert(id: 3, country: 'SA', karat: 24, above: true, target: 380),
        const PriceAlert(id: 4, country: 'SA', karat: 24, above: true, target: 1, enabled: false),
        const PriceAlert(id: 5, country: 'XX', karat: 24, above: true, target: 1), // falls back to AE, pegged
      ];
      final r = evaluateAlerts(alerts, quote()); // 24K = 375 SAR
      expect(r.fired.map((a) => a.id), [1, 5]);
      final one = r.updated.firstWhere((a) => a.id == 1);
      expect(one.enabled, isFalse);
      expect(one.firedPrice, closeTo(375, 1e-9));
      expect(evaluateAlerts(r.updated, quote()).fired, isEmpty);
    });

    test('store survives bad json; controller add/toggle/remove', () async {
      SharedPreferences.setMockInitialValues({'alerts_v1': 'not json'});
      final prefs = await SharedPreferences.getInstance();
      final c = AlertController(prefs);
      expect(c.alerts, isEmpty);
      await c.add(country: 'KW', karat: 21, above: false, target: 25.5);
      await c.add(country: 'KW', karat: 22, above: true, target: 30);
      expect(c.alerts.map((a) => a.id), [1, 2]);
      expect(AlertController(prefs).alerts.length, 2);
      await c.toggle(1, false);
      expect(c.anyEnabled, isTrue);
      await c.remove(2);
      expect(c.anyEnabled, isFalse);
    });
  });

  group('format', () {
    test('money and parse', () {
      expect(money(1234.5, 2), '1,234.50');
      expect(money(1234.5, 0), '1,235');
      expect(money(0.3115, 3), '0.312');
      expect(parseNum('١٢٫٥'), 12.5);
      expect(parseNum('1,250'), 1250);
      expect(parseNum(''), isNull);
      expect(percent(1.234), '+1.23%');
      expect(percent(-0.5), '−0.50%');
    });
  });
}
