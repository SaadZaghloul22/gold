import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gold_math.dart';
import '../data/countries.dart';
import '../services/price_service.dart';

/// One row of the price board.
class PriceRow {
  const PriceRow(this.label, this.value, {this.sub});
  final String label;
  final double value;
  final String? sub;
}

class PriceController extends ChangeNotifier {
  PriceController(this._prefs, this.service, {String? defaultCountry})
      : _country = countryByCode(_prefs.getString(_countryKey) ?? defaultCountry),
        _quote = service.cached;

  final SharedPreferences _prefs;
  final PriceService service;
  static const _countryKey = 'country';
  static const _themeKey = 'theme';

  Country _country;
  Quote? _quote;
  List<HistoryDay> _history = const [];
  bool _loading = false;
  String? _error;
  Timer? _timer;
  DateTime? _historyAt;

  Country get country => _country;
  Quote? get quote => _quote;
  List<HistoryDay> get history => _history;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasCountry => _prefs.getString(_countryKey) != null;

  /// 0 = system, 1 = light, 2 = dark.
  int get themeMode => _prefs.getInt(_themeKey) ?? 0;
  Future<void> setThemeMode(int m) async {
    await _prefs.setInt(_themeKey, m);
    notifyListeners();
  }

  Future<void> setCountry(Country c) async {
    _country = c;
    await _prefs.setString(_countryKey, c.code);
    notifyListeners();
  }

  /// USD -> local rate for the selected country (null when unknown/outdated).
  double? get rate => _quote?.rate(_country.currency);

  double? gram(int karat) {
    final q = _quote, r = rate;
    if (q == null || r == null) return null;
    return gramPrice(usdPerOunce: q.xau, usdToLocal: r, karat: karat);
  }

  double? get ounce => _quote == null || rate == null ? null : _quote!.xau * rate!;

  double? silverGram(double fineness) {
    final q = _quote, r = rate;
    if (q?.xag == null || r == null) return null;
    return q!.xag! / troyOunceGrams * r * fineness;
  }

  /// Rows shown under the hero card.
  List<PriceRow> get rows {
    final out = <PriceRow>[];
    for (final k in karats) {
      final v = gram(k);
      if (v != null) out.add(PriceRow('عيار $k', v, sub: 'للجرام'));
    }
    final o = ounce;
    if (o != null) out.add(PriceRow('الأونصة', o, sub: '31.10 جم عيار 24'));
    final g24 = gram(24);
    if (g24 != null && _country.tola) {
      out.add(PriceRow('التولة', g24 * tolaGrams, sub: '11.66 جم عيار 24'));
    }
    final g21 = gram(21);
    if (g21 != null && _country.code == 'EG') {
      out.add(PriceRow('الجنيه الذهب', g21 * 8, sub: '8 جم عيار 21'));
    }
    if (g24 != null) out.add(PriceRow('الكيلو', g24 * 1000, sub: 'سبيكة عيار 24'));
    return out;
  }

  /// Latest history day strictly before today (the previous close for the change badge).
  HistoryDay? get previousClose {
    if (_history.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = _history.length - 1; i >= 0; i--) {
      final d = _history[i];
      if (d.day.isBefore(today)) return d;
    }
    return null;
  }

  /// Change of the 24K gram vs. the previous close, in the local currency (%).
  double? get change {
    final prev = previousClose?.local(_country.currency);
    final now = gram(24);
    if (prev == null || now == null) return null;
    return percentChange(prev, now);
  }

  /// History series for the selected country and karat over the last [days] days.
  List<MapEntry<DateTime, double>> series(int days, int karat) {
    if (_history.isEmpty) return const [];
    final from = _history.last.day.subtract(Duration(days: days));
    final out = <MapEntry<DateTime, double>>[];
    for (final d in _history) {
      if (d.day.isBefore(from)) continue;
      final v = d.local(_country.currency);
      if (v != null) out.add(MapEntry(d.day, v * purity(karat)));
    }
    final live = gram(karat);
    if (live != null && out.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (out.last.key.isBefore(today)) out.add(MapEntry(today, live));
    }
    return out;
  }

  Future<void> refresh({bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    if (!silent) _error = null;
    notifyListeners();
    try {
      _quote = await service.fetch();
      _error = null;
    } catch (e) {
      debugPrint('refresh: $e');
      if (_quote == null || _quote!.fromHistory) {
        if (_history.isEmpty) await loadHistory();
        if (_history.isNotEmpty) _quote = Quote.fromHistory(_history.last);
      }
      _error = _quote == null
          ? 'تعذّر جلب الأسعار. تأكد من اتصالك بالإنترنت ثم اسحب للتحديث.'
          : _quote!.fromHistory
              ? 'تعذّر جلب السعر اللحظي الآن — يُعرض سعر آخر إغلاق. اسحب للتحديث بعد قليل.'
              : 'تعذّر التحديث الآن — تُعرض آخر أسعار محفوظة.';
    } finally {
      _loading = false;
      notifyListeners();
    }
    final h = _historyAt;
    if (h == null || DateTime.now().difference(h) > const Duration(hours: 1)) unawaited(loadHistory());
  }

  Future<void> loadHistory({bool force = false}) async {
    _historyAt = DateTime.now();
    final h = await service.history(force: force);
    if (h.isNotEmpty) {
      _history = h;
      notifyListeners();
    }
  }

  /// Auto refresh every 2 minutes while the app is in the foreground.
  /// Off in screenshot tests, where data is loaded once up front.
  bool autoRefresh = true;

  void start() {
    if (!autoRefresh) return;
    unawaited(refresh());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => refresh(silent: true));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
