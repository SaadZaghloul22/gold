import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../state/prices.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceController>();
    final c = p.country;
    final scheme = Theme.of(context).colorScheme;
    final rows = p.rows;
    return Scaffold(
      appBar: AppBar(
        title: const Text('أسعار الذهب اليوم'),
        actions: [
          IconButton(
            tooltip: 'مشاركة الأسعار',
            icon: const Icon(Icons.share_outlined),
            onPressed: rows.isEmpty ? null : () => SharePlus.instance.share(ShareParams(text: shareText(p))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'about') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
              } else {
                p.setThemeMode(int.parse(v));
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: '0', checked: p.themeMode == 0, child: const Text('مظهر النظام')),
              CheckedPopupMenuItem(value: '1', checked: p.themeMode == 1, child: const Text('فاتح')),
              CheckedPopupMenuItem(value: '2', checked: p.themeMode == 2, child: const Text('داكن')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'about', child: Text('عن التطبيق ومصادر الأسعار')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => p.refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: CountryButton()),
            const SizedBox(height: 12),
            if (p.error != null) _Banner(p.error!),
            if (p.quote != null && p.rate == null)
              const _Banner('سعر صرف هذه العملة غير متاح الآن. اسحب للتحديث بعد الاتصال بالإنترنت.'),
            _Hero(p: p),
            const SectionTitle('سعر الجرام حسب العيار'),
            if (rows.isEmpty)
              for (var i = 0; i < 5; i++)
                const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 56, radius: 16))
            else
              Card(
                child: Column(children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                    _Row(rows[i], c.decimals, c.unit, highlight: rows[i].label == 'عيار 21'),
                  ],
                ]),
              ),
            const SectionTitle('الفضة'),
            Card(
              child: Column(children: [
                _Row(PriceRow('فضة 999', p.silverGram(.999) ?? 0, sub: 'للجرام'), c.decimals == 0 ? 1 : c.decimals, c.unit,
                    silver: true, missing: p.silverGram(.999) == null),
                Divider(height: 1, color: scheme.outlineVariant),
                _Row(PriceRow('فضة 925', p.silverGram(.925) ?? 0, sub: 'استرليني — للجرام'), c.decimals == 0 ? 1 : c.decimals,
                    c.unit,
                    silver: true, missing: p.silverGram(.925) == null),
              ]),
            ),
            const SizedBox(height: 16),
            Text(disclaimerText,
                style: TextStyle(fontSize: 12, height: 1.6, color: scheme.onSurface.withValues(alpha: .6))),
          ],
        ),
      ),
    );
  }

  static String shareText(PriceController p) {
    final c = p.country;
    final b = StringBuffer('أسعار الذهب اليوم في ${c.name} ${c.flag}\n');
    final d = DateFormat('EEEE d MMMM yyyy', 'ar').format(DateTime.now());
    b.writeln(d);
    for (final r in p.rows.take(5)) {
      b.writeln('• ${r.label}: ${moneyIn(r.value, c)}');
    }
    final o = p.ounce;
    if (o != null) b.writeln('• الأونصة: ${moneyIn(o, c)}');
    b.writeln('\nمن تطبيق «أسعار الذهب اليوم»');
    return b.toString();
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GoldColors.down.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off, size: 18, color: GoldColors.down),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.p});
  final PriceController p;

  @override
  Widget build(BuildContext context) {
    final c = p.country;
    final g24 = p.gram(24);
    final q = p.quote;
    final ch = p.change;
    final prev = p.previousClose;
    const ink = Color(0xFF2A1F00);
    return Container(
      key: const Key('hero'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFFF2D98A), GoldColors.gold, Color(0xFFB8891F)],
        ),
        boxShadow: [BoxShadow(color: GoldColors.gold.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('جرام الذهب عيار 24', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (ch != null) ChangeBadge(ch, onDark: false),
        ]),
        const SizedBox(height: 4),
        if (g24 == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Skeleton(height: 40, width: 200))
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: money(g24, c.decimals), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
                TextSpan(text: '  ${c.unit}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              style: const TextStyle(color: ink, height: 1.2),
            ),
          ),
        const SizedBox(height: 6),
        if (q != null)
          Wrap(spacing: 14, runSpacing: 4, children: [
            Text('الأونصة عالمياً: \$${money(q.xau, 2)}', style: const TextStyle(color: ink, fontSize: 13)),
            Text('آخر تحديث: ${timeAgo(q.sourceAt)}', style: const TextStyle(color: ink, fontSize: 13)),
          ]),
        if (ch != null && prev != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('التغير مقارنة بإغلاق ${DateFormat('d MMMM', 'ar').format(prev.day)}',
                style: TextStyle(color: ink.withValues(alpha: .7), fontSize: 12)),
          ),
        if (q != null && q.stale)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('السوق العالمي مغلق أو السعر لم يتحدث منذ فترة — يُعرض آخر سعر.',
                style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.row, this.decimals, this.unit, {this.highlight = false, this.silver = false, this.missing = false});
  final PriceRow row;
  final int decimals;
  final String unit;
  final bool highlight;
  final bool silver;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = silver ? GoldColors.silver : GoldColors.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: dot.withValues(alpha: .16), shape: BoxShape.circle),
          child: Text(
            RegExp(r'\d+').firstMatch(row.label)?.group(0) ?? '•',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: silver ? scheme.onSurface : GoldColors.goldDeep),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.label, style: TextStyle(fontWeight: highlight ? FontWeight.w800 : FontWeight.w700, fontSize: 15)),
            if (row.sub != null)
              Text(row.sub!, style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .55))),
          ]),
        ),
        if (missing)
          Text('—', style: TextStyle(color: scheme.onSurface.withValues(alpha: .5)))
        else
          Text.rich(
            TextSpan(children: [
              TextSpan(text: money(row.value, decimals), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              TextSpan(text: ' $unit', style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .6))),
            ]),
          ),
      ]),
    );
  }
}
