// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Prints what candidate live gold-price sources answer from CI (diagnostics only).
void main() {
  test('probe sources', () async {
    HttpOverrides.global = null;
    const urls = [
      'https://api.gold-api.com/price/XAU',
      'https://data-asg.goldprice.org/dbXRates/USD',
      'https://forex-data-feed.swissquote.com/public-quotes/bboquotes/instrument/XAU/USD',
      'https://query1.finance.yahoo.com/v8/finance/chart/XAUUSD=X?range=1d&interval=1d',
    ];
    for (final u in urls) {
      try {
        final r = await http.get(Uri.parse(u), headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) GoldPrices/1.0'})
            .timeout(const Duration(seconds: 15));
        final b = r.body.length > 300 ? r.body.substring(0, 300) : r.body;
        print('PROBE $u -> ${r.statusCode} $b');
      } catch (e) {
        print('PROBE $u -> $e');
      }
    }
  });
}
