/// Pure price arithmetic (no I/O), shared by the UI, the alert worker and tests.
/// Same method as the maelumatii site: spot price per troy ounce in USD,
/// divided by 31.1035 g, converted with the official peg or the daily rate.
library;

const troyOunceGrams = 31.1035;
const tolaGrams = 11.6638;
const nisabGrams = 85.0; // gold nisab, in pure (24K) grams
const zakatRate = 0.025;

const karats = [24, 22, 21, 18, 14];

/// Purity of a karat (21K = 21/24 = 0.875).
double purity(int karat) => karat / 24;

/// Price of one gram of [karat] gold in the local currency.
double gramPrice({required double usdPerOunce, required double usdToLocal, int karat = 24}) =>
    usdPerOunce / troyOunceGrams * usdToLocal * purity(karat);

/// Percent change from [from] to [to] (e.g. 1.25 means +1.25%).
double percentChange(double from, double to) => from == 0 ? 0 : (to - from) / from * 100;

/// A jewellery purchase: gold value + workmanship (per gram or total) + VAT on both.
class Purchase {
  const Purchase({
    required this.gold,
    required this.workmanship,
    required this.vat,
  });
  final double gold;
  final double workmanship;
  final double vat;
  double get total => gold + workmanship + vat;
}

Purchase purchase({
  required double grams,
  required double pricePerGram,
  double workmanshipPerGram = 0,
  double workmanshipTotal = 0,
  double vatPercent = 0,
}) {
  final gold = grams * pricePerGram;
  final work = grams * workmanshipPerGram + workmanshipTotal;
  final vat = (gold + work) * vatPercent / 100;
  return Purchase(gold: gold, workmanship: work, vat: vat);
}

/// Zakat on gold: holdings per karat are converted to pure 24K grams; zakat is due
/// (2.5% of the value) when the pure weight reaches the nisab of 85 g.
class ZakatResult {
  const ZakatResult({required this.pureGrams, required this.value, required this.due});
  final double pureGrams;
  final double value;
  final double due; // 0 below nisab
  bool get reachesNisab => pureGrams >= nisabGrams;
  double get missingGrams => reachesNisab ? 0 : nisabGrams - pureGrams;
}

ZakatResult zakat({required Map<int, double> gramsByKarat, required double price24PerGram}) {
  var pure = 0.0;
  gramsByKarat.forEach((k, g) => pure += g * purity(k));
  final value = pure * price24PerGram;
  return ZakatResult(pureGrams: pure, value: value, due: pure >= nisabGrams ? value * zakatRate : 0);
}
