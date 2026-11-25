import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/gold_math.dart';
import '../core/theme.dart';
import '../data/countries.dart';
import '../state/prices.dart';
import '../widgets/common.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحاسبة'),
          bottom: const TabBar(
            labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15),
            tabs: [Tab(text: 'قيمة المشغولات'), Tab(text: 'زكاة الذهب')],
          ),
        ),
        body: const TabBarView(children: [_JewelryCalc(), _ZakatCalc()]),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.controller, this.suffix, this.onChanged, this.fieldKey});
  final String label;
  final TextEditingController controller;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );
}

class _ResultLine extends StatelessWidget {
  const _ResultLine(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: bold ? 18 : 15)),
        ]),
      );
}

class _JewelryCalc extends StatefulWidget {
  const _JewelryCalc();
  @override
  State<_JewelryCalc> createState() => _JewelryCalcState();
}

class _JewelryCalcState extends State<_JewelryCalc> with AutomaticKeepAliveClientMixin {
  final weight = TextEditingController();
  final work = TextEditingController();
  final vat = TextEditingController(text: '0');
  int karat = 21;
  bool perGram = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    weight.dispose();
    work.dispose();
    vat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.watch<PriceController>();
    final Country c = p.country;
    final price = p.gram(karat);
    final g = parseNum(weight.text) ?? 0;
    final w = parseNum(work.text) ?? 0;
    final v = parseNum(vat.text) ?? 0;
    final r = price == null
        ? null
        : purchase(
            grams: g,
            pricePerGram: price,
            workmanshipPerGram: perGram ? w : 0,
            workmanshipTotal: perGram ? 0 : w,
            vatPercent: v,
          );
    final scheme = Theme.of(context).colorScheme;
    void upd(String _) => setState(() {});

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Align(alignment: AlignmentDirectional.centerStart, child: CountryButton()),
        const SizedBox(height: 12),
        KaratPicker(value: karat, onChanged: (k) => setState(() => karat = k)),
        const SizedBox(height: 4),
        if (price != null)
          Text('سعر جرام عيار $karat الآن: ${moneyIn(price, c)}',
              style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: .7))),
        const SizedBox(height: 12),
        _NumField(label: 'الوزن', suffix: 'جرام', controller: weight, onChanged: upd, fieldKey: const Key('calc-grams')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _NumField(
              label: perGram ? 'المصنعية للجرام' : 'المصنعية الإجمالية',
              suffix: c.unit,
              controller: work,
              onChanged: upd,
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('للجرام')), ButtonSegment(value: false, label: Text('إجمالي'))],
            selected: {perGram},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => perGram = s.first),
          ),
        ]),
        const SizedBox(height: 12),
        _NumField(label: 'ضريبة القيمة المضافة (اختياري)', suffix: '%', controller: vat, onChanged: upd),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final x in const ['0', '5', '10', '14', '15'])
            ActionChip(
              label: Text('$x%'),
              onPressed: () => setState(() => vat.text = x),
            ),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: r == null
                ? const Text('في انتظار الأسعار…')
                : Column(children: [
                    _ResultLine('قيمة الذهب (${grams(g)})', moneyIn(r.gold, c)),
                    _ResultLine('المصنعية', moneyIn(r.workmanship, c)),
                    _ResultLine('الضريبة', moneyIn(r.vat, c)),
                    const Divider(height: 18),
                    _ResultLine('الإجمالي التقريبي', moneyIn(r.total, c), bold: true),
                  ]),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'قيمة الذهب وحدها تقريبية لسعر البيع للمحل (قد يخصم المحل نسبة عند الشراء منك). '
          'المصنعية والضريبة تختلف حسب المحل والدولة؛ أدخلها كما يذكرها البائع.',
          style: TextStyle(fontSize: 12, height: 1.6, color: scheme.onSurface.withValues(alpha: .6)),
        ),
      ],
    );
  }
}

class _ZakatCalc extends StatefulWidget {
  const _ZakatCalc();
  @override
  State<_ZakatCalc> createState() => _ZakatCalcState();
}

class _ZakatCalcState extends State<_ZakatCalc> with AutomaticKeepAliveClientMixin {
  final fields = {for (final k in const [24, 22, 21, 18]) k: TextEditingController()};

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.watch<PriceController>();
    final c = p.country;
    final p24 = p.gram(24);
    final held = {for (final e in fields.entries) e.key: parseNum(e.value.text) ?? 0.0};
    final z = p24 == null ? null : zakat(gramsByKarat: held, price24PerGram: p24);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Align(alignment: AlignmentDirectional.centerStart, child: CountryButton()),
        const SizedBox(height: 12),
        Text('أدخل وزن ما تملكه من ذهب لكل عيار:', style: TextStyle(color: scheme.onSurface.withValues(alpha: .75))),
        const SizedBox(height: 10),
        for (final e in fields.entries) ...[
          _NumField(
            label: 'ذهب عيار ${e.key}',
            suffix: 'جرام',
            controller: e.value,
            onChanged: (_) => setState(() {}),
            fieldKey: Key('zakat-${e.key}'),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: z == null
                ? const Text('في انتظار الأسعار…')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _ResultLine('الذهب الخالص (عيار 24)', grams(z.pureGrams)),
                    _ResultLine('قيمته الآن', moneyIn(z.value, c)),
                    _ResultLine('النصاب (85 جم عيار 24)', moneyIn(nisabGrams * p24!, c)),
                    const Divider(height: 18),
                    if (z.reachesNisab)
                      _ResultLine('الزكاة الواجبة (2.5%)', moneyIn(z.due, c), bold: true)
                    else
                      Row(children: [
                        const Icon(Icons.info_outline, size: 18, color: GoldColors.goldDeep),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            z.pureGrams == 0
                                ? 'أدخل الأوزان لحساب الزكاة.'
                                : 'لم يبلغ النصاب — ينقصه ${grams(z.missingGrams)} من الذهب الخالص، فلا زكاة فيه.',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                  ]),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'تجب الزكاة إذا بلغ الذهب النصاب وحال عليه الحول (سنة هجرية). يُحسب الذهب الخالص بضرب الوزن في '
          '(العيار ÷ 24). في زكاة الحلي المعدّ للاستعمال خلاف بين العلماء؛ فاسأل من تثق بعلمه.',
          style: TextStyle(fontSize: 12, height: 1.6, color: scheme.onSurface.withValues(alpha: .6)),
        ),
      ],
    );
  }
}
