import 'package:intl/intl.dart';

import '../data/countries.dart';

final _fmtCache = <int, NumberFormat>{};

/// Money in the country's usual precision, with thousands separators (Western digits,
/// as used on price boards across the Gulf).
String money(double v, int decimals) {
  final f = _fmtCache.putIfAbsent(decimals, () {
    final p = decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    return NumberFormat(p, 'en_US');
  });
  return f.format(v);
}

String moneyIn(double v, Country c) => '${money(v, c.decimals)} ${c.unit}';

String percent(double v) {
  final s = v.abs().toStringAsFixed(2);
  return '${v > 0 ? '+' : v < 0 ? '−' : ''}$s%';
}

String grams(double g) {
  if (g == g.roundToDouble()) return '${g.toStringAsFixed(0)} جم';
  return '${g.toStringAsFixed(2)} جم';
}

/// Parse a user-entered number, accepting Arabic-Indic digits and the Arabic decimal mark.
double? parseNum(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch == '٬' || ch == ',' || ch == ' ') {
      // thousands separator
    } else {
      b.write(ch);
    }
  }
  return double.tryParse(b.toString());
}

String timeAgo(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return 'الآن';
  if (d.inMinutes < 60) return 'منذ ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'منذ ${d.inHours} ساعة';
  return DateFormat('d MMM، h:mm a', 'ar').format(t);
}
