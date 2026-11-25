import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gold_math.dart';
import '../data/countries.dart';

/// A snapshot of the spot prices (USD per troy ounce) and exchange rates.
@immutable
class Quote {
  const Quote({
    required this.xau,
    required this.xag,
    required this.sourceAt,
    required this.fetchedAt,
    required this.fx,
    this.fxAt,
    this.fromHistory = false,
  });

  /// True for the daily-close fallback (never cached).
  final bool fromHistory;

  final double xau;
  final double? xag;
  final DateTime sourceAt;
  final DateTime fetchedAt;

  /// USD -> currency, from open.er-api.com (pegged currencies use [pegs]).
  final Map<String, double> fx;
  final DateTime? fxAt;

  /// USD -> [currency]: official peg first, then the daily rate (if not older than 4 days).
  double? rate(String currency) {
    final p = pegs[currency];
    if (p != null) return p;
    final at = fxAt;
    if (at == null || DateTime.now().difference(at) > const Duration(days: 4)) return null;
    return fx[currency];
  }

  /// Older than 30 minutes at the source: shown with a "may be outdated" note.
  bool get stale => DateTime.now().difference(sourceAt) > const Duration(minutes: 30);

  /// Last daily close, used only when no live or cached price is available.
  factory Quote.fromHistory(HistoryDay d) => Quote(
        xau: d.usdGram * troyOunceGrams,
        xag: null,
        sourceAt: DateTime(d.day.year, d.day.month, d.day.day, 23, 59),
        fetchedAt: DateTime.now(),
        fx: d.fx,
        fxAt: DateTime(d.day.year, d.day.month, d.day.day, 23, 59),
        fromHistory: true,
      );

  Map<String, dynamic> toJson() => {
        'xau': xau,
        'xag': xag,
        'sourceAt': sourceAt.toIso8601String(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'fx': fx,
        'fxAt': fxAt?.toIso8601String(),
      };

  static Quote? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final xau = _num(j['xau']);
    final at = DateTime.tryParse('${j['sourceAt']}');
    if (xau == null || at == null) return null;
    return Quote(
      xau: xau,
      xag: _num(j['xag']),
      sourceAt: at,
      fetchedAt: DateTime.tryParse('${j['fetchedAt']}') ?? at,
      fx: _rates(j['fx']),
      fxAt: DateTime.tryParse('${j['fxAt']}'),
    );
  }
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

/// Currency -> rate map, skipping anything that is not a number.
Map<String, double> _rates(Object? m) {
  final out = <String, double>{};
  if (m is Map) {
    m.forEach((k, v) {
      if (v is num) out['$k'] = v.toDouble();
    });
  }
  return out;
}

/// One day of history: USD per gram of 24K and that day's exchange rates.
@immutable
class HistoryDay {
  const HistoryDay(this.day, this.usdGram, this.fx);
  final DateTime day;
  final double usdGram;
  final Map<String, double> fx;

  double? local(String currency) {
    final r = pegs[currency] ?? fx[currency];
    return r == null ? null : usdGram * r;
  }
}

class PriceService {
  PriceService(this._prefs, {http.Client? client}) : _http = client ?? http.Client();

  final SharedPreferences _prefs;
  final http.Client _http;

  static const _quoteKey = 'quote_v1';
  static const _historyKey = 'history_v1';
  static const _historyAtKey = 'history_at_v1';
  static const historyUrl =
      'https://raw.githubusercontent.com/mahmoedrabso8-png/gold-site/main/data/gold-history.json';

  Quote? get cached {
    try {
      final s = _prefs.getString(_quoteKey);
      return s == null ? null : Quote.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// GET JSON, retrying a couple of times on rate limiting (429) or server errors.
  Future<Map<String, dynamic>> _getJson(String url, {int attempts = 3}) async {
    for (var i = 1;; i++) {
      final r = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      final retry = r.statusCode == 429 || r.statusCode >= 500;
      if (!retry || i >= attempts) throw Exception('HTTP ${r.statusCode} for $url');
      await Future<void>.delayed(Duration(milliseconds: 1500 * i * i));
    }
  }

  /// Live quote; falls back to the cached one when offline. FX is refreshed at most
  /// every 6 hours (rates are daily).
  Future<Quote> fetch({bool needFx = true}) async {
    final old = cached;
    final gold = await _getJson('https://api.gold-api.com/price/XAU');
    final xau = _num(gold['price']);
    if (xau == null || xau < 500) throw Exception('bad gold price');
    final sourceAt = DateTime.tryParse('${gold['updatedAt']}')?.toLocal() ?? DateTime.now();

    double? xag = old?.xag;
    try {
      final silver = await _getJson('https://api.gold-api.com/price/XAG', attempts: 2);
      final v = _num(silver['price']);
      if (v != null && v > 1) xag = v;
    } catch (e) {
      debugPrint('silver: $e');
    }

    var fx = old?.fx ?? const <String, double>{};
    var fxAt = old?.fxAt;
    final fxOld = fxAt == null || DateTime.now().difference(fxAt) > const Duration(hours: 6);
    if (needFx && fxOld) {
      try {
        final j = await _getJson('https://open.er-api.com/v6/latest/USD', attempts: 2);
        final rates = _rates(j['rates']);
        final t = _num(j['time_last_update_unix'])?.toInt();
        if (rates.isNotEmpty) {
          fx = rates;
          fxAt = t != null ? DateTime.fromMillisecondsSinceEpoch(t * 1000) : DateTime.now();
        }
      } catch (e) {
        debugPrint('fx: $e');
      }
    }
    final q = Quote(xau: xau, xag: xag, sourceAt: sourceAt, fetchedAt: DateTime.now(), fx: fx, fxAt: fxAt);
    await _prefs.setString(_quoteKey, jsonEncode(q.toJson()));
    return q;
  }

  static List<HistoryDay> parseHistory(Map<String, dynamic> j) {
    final rows = (j['rows'] as List?) ?? const [];
    final out = <HistoryDay>[];
    for (final r in rows) {
      if (r is! Map) continue;
      final day = DateTime.tryParse('${r['day']}');
      final g = _num(r['usdGram']);
      if (day == null || g == null || g <= 0) continue;
      final fx = _rates(r['fx']);
      out.add(HistoryDay(day, g, fx));
    }
    out.sort((a, b) => a.day.compareTo(b.day));
    return out;
  }

  /// Daily history for the chart (cached for 6 hours).
  Future<List<HistoryDay>> history({bool force = false}) async {
    final at = DateTime.tryParse(_prefs.getString(_historyAtKey) ?? '');
    final raw = _prefs.getString(_historyKey);
    final fresh = at != null && DateTime.now().difference(at) < const Duration(hours: 6);
    if (raw != null && fresh && !force) {
      return compute(_parse, raw);
    }
    try {
      final r = await _http.get(Uri.parse(historyUrl)).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final list = await compute(_parse, r.body);
      if (list.isNotEmpty) {
        await _prefs.setString(_historyKey, r.body);
        await _prefs.setString(_historyAtKey, DateTime.now().toIso8601String());
      }
      return list;
    } catch (e) {
      debugPrint('history: $e');
      return raw == null ? const [] : compute(_parse, raw);
    }
  }

  static List<HistoryDay> _parse(String body) => parseHistory(jsonDecode(body) as Map<String, dynamic>);
}
