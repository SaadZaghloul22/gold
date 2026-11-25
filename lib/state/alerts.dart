import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gold_math.dart';
import '../data/countries.dart';
import '../services/price_service.dart';

/// "Tell me when the gram of [karat] in [currency] goes above/below [target]".
@immutable
class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.country,
    required this.karat,
    required this.above,
    required this.target,
    this.enabled = true,
    this.firedAt,
    this.firedPrice,
  });

  final int id;
  final String country; // ISO code
  final int karat;
  final bool above;
  final double target;
  final bool enabled;
  final DateTime? firedAt;
  final double? firedPrice;

  Country get c => countryByCode(country);

  bool hits(double price) => above ? price >= target : price <= target;

  PriceAlert copyWith({bool? enabled, DateTime? firedAt, double? firedPrice, bool clearFired = false}) => PriceAlert(
        id: id,
        country: country,
        karat: karat,
        above: above,
        target: target,
        enabled: enabled ?? this.enabled,
        firedAt: clearFired ? null : firedAt ?? this.firedAt,
        firedPrice: clearFired ? null : firedPrice ?? this.firedPrice,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'country': country,
        'karat': karat,
        'above': above,
        'target': target,
        'enabled': enabled,
        'firedAt': firedAt?.toIso8601String(),
        'firedPrice': firedPrice,
      };

  static PriceAlert? fromJson(Object? o) {
    if (o is! Map) return null;
    final t = (o['target'] as num?)?.toDouble();
    if (t == null) return null;
    return PriceAlert(
      id: (o['id'] as num?)?.toInt() ?? 0,
      country: '${o['country'] ?? 'SA'}',
      karat: (o['karat'] as num?)?.toInt() ?? 24,
      above: o['above'] != false,
      target: t,
      enabled: o['enabled'] != false,
      firedAt: DateTime.tryParse('${o['firedAt']}'),
      firedPrice: (o['firedPrice'] as num?)?.toDouble(),
    );
  }

  String describe() {
    final cc = c;
    final dir = above ? 'يرتفع إلى' : 'ينخفض إلى';
    return 'عيار $karat ${cc.flag} $dir ${target.toStringAsFixed(cc.decimals)} ${cc.unit}';
  }
}

class AlertStore {
  AlertStore(this.prefs);
  final SharedPreferences prefs;
  static const key = 'alerts_v1';

  List<PriceAlert> load() {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map(PriceAlert.fromJson).whereType<PriceAlert>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<PriceAlert> list) =>
      prefs.setString(key, jsonEncode(list.map((a) => a.toJson()).toList()));
}

/// Pure check, used by the background worker and by the app on refresh: returns the
/// alerts that fire now (enabled ones whose condition is met) and the updated list,
/// where fired alerts are switched off so they notify only once.
({List<PriceAlert> fired, List<PriceAlert> updated}) evaluateAlerts(
  List<PriceAlert> alerts,
  Quote quote, {
  DateTime? now,
}) {
  final fired = <PriceAlert>[];
  final updated = <PriceAlert>[];
  for (final a in alerts) {
    if (!a.enabled) {
      updated.add(a);
      continue;
    }
    final r = quote.rate(a.c.currency);
    if (r == null) {
      updated.add(a);
      continue;
    }
    final p = gramPrice(usdPerOunce: quote.xau, usdToLocal: r, karat: a.karat);
    if (a.hits(p)) {
      final f = a.copyWith(enabled: false, firedAt: now ?? DateTime.now(), firedPrice: p);
      fired.add(f);
      updated.add(f);
    } else {
      updated.add(a);
    }
  }
  return (fired: fired, updated: updated);
}

class AlertController extends ChangeNotifier {
  AlertController(SharedPreferences prefs) : _store = AlertStore(prefs) {
    _alerts = _store.load();
  }

  final AlertStore _store;
  late List<PriceAlert> _alerts;

  List<PriceAlert> get alerts => List.unmodifiable(_alerts);
  bool get anyEnabled => _alerts.any((a) => a.enabled);

  /// Re-read after the background worker may have changed the list.
  Future<void> reload() async {
    await _store.prefs.reload();
    _alerts = _store.load();
    notifyListeners();
  }

  Future<void> add({required String country, required int karat, required bool above, required double target}) async {
    final id = _alerts.fold<int>(0, (m, a) => a.id > m ? a.id : m) + 1;
    _alerts = [..._alerts, PriceAlert(id: id, country: country, karat: karat, above: above, target: target)];
    await _store.save(_alerts);
    notifyListeners();
  }

  Future<void> remove(int id) async {
    _alerts = _alerts.where((a) => a.id != id).toList();
    await _store.save(_alerts);
    notifyListeners();
  }

  Future<void> toggle(int id, bool on) async {
    _alerts = [
      for (final a in _alerts) a.id == id ? a.copyWith(enabled: on, clearFired: on) : a,
    ];
    await _store.save(_alerts);
    notifyListeners();
  }

  /// Checks alerts against a fresh quote (foreground). Returns the ones that fired.
  Future<List<PriceAlert>> check(Quote q) async {
    final r = evaluateAlerts(_alerts, q);
    if (r.fired.isEmpty) return const [];
    _alerts = r.updated;
    await _store.save(_alerts);
    notifyListeners();
    return r.fired;
  }
}
