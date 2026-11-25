import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/gold_math.dart';
import '../core/theme.dart';
import '../state/prices.dart';
import '../widgets/common.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});
  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  int days = 30;
  int karat = 21;
  int? touched;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceController>();
    final c = p.country;
    final data = p.series(days, karat);
    final scheme = Theme.of(context).colorScheme;
    final values = data.map((e) => e.value).toList();
    final hasData = values.length >= 2;
    final first = hasData ? values.first : 0.0;
    final last = hasData ? values.last : 0.0;
    final hi = hasData ? values.reduce(math.max) : 0.0;
    final lo = hasData ? values.reduce(math.min) : 0.0;
    final shown = touched != null && touched! < data.length ? data[touched!] : (hasData ? data.last : null);

    return Scaffold(
      appBar: AppBar(title: const Text('حركة سعر الذهب')),
      body: RefreshIndicator(
        onRefresh: () => p.loadHistory(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: CountryButton()),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('أسبوع')),
                ButtonSegment(value: 30, label: Text('شهر')),
                ButtonSegment(value: 90, label: Text('3 شهور')),
                ButtonSegment(value: 365, label: Text('سنة')),
              ],
              selected: {days},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                days = s.first;
                touched = null;
              }),
            ),
            const SizedBox(height: 10),
            KaratPicker(value: karat, onChanged: (k) => setState(() => karat = k)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (shown != null) ...[
                    Text(DateFormat('EEEE d MMMM yyyy', 'ar').format(shown.key),
                        style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .6))),
                    Row(children: [
                      Text('${money(shown.value, c.decimals)} ${c.unit}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      if (hasData) ChangeBadge(percentChange(first, shown.value)),
                    ]),
                    Text('جرام عيار $karat', style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .6))),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 220,
                    child: !hasData
                        ? Center(
                            child: p.history.isEmpty
                                ? const Text('جارٍ تحميل السجل…')
                                : const Text('لا توجد بيانات كافية لهذه الفترة'),
                          )
                        : LayoutBuilder(builder: (context, box) {
                            void hit(Offset o) {
                              final i = (o.dx / box.maxWidth * (data.length - 1)).round();
                              setState(() => touched = i.clamp(0, data.length - 1));
                            }

                            return GestureDetector(
                              onHorizontalDragUpdate: (d) => hit(d.localPosition),
                              onTapDown: (d) => hit(d.localPosition),
                              onHorizontalDragEnd: (_) => setState(() => touched = null),
                              child: CustomPaint(
                                size: Size(box.maxWidth, 220),
                                painter: _LinePainter(
                                  values,
                                  up: last >= first,
                                  touched: touched,
                                  grid: scheme.outlineVariant,
                                ),
                              ),
                            );
                          }),
                  ),
                  if (hasData)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(children: [
                          Text(DateFormat('d MMM', 'ar').format(data.first.key), style: const TextStyle(fontSize: 11)),
                          const Spacer(),
                          Text(DateFormat('d MMM', 'ar').format(data.last.key), style: const TextStyle(fontSize: 11)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
            if (hasData) ...[
              const SizedBox(height: 12),
              Row(children: [
                _Stat('أعلى سعر', money(hi, c.decimals), GoldColors.up),
                const SizedBox(width: 8),
                _Stat('أدنى سعر', money(lo, c.decimals), GoldColors.down),
                const SizedBox(width: 8),
                _Stat('التغير', percent(percentChange(first, last)), last >= first ? GoldColors.up : GoldColors.down,
                    ltr: true),
              ]),
            ],
            const SizedBox(height: 14),
            Text(
              'السجل اليومي بسعر الإغلاق، وآخر نقطة هي السعر الحالي. اسحب إصبعك على الرسم لرؤية سعر أي يوم.',
              style: TextStyle(fontSize: 12, height: 1.6, color: scheme.onSurface.withValues(alpha: .6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color, {this.ltr = false});
  final String label;
  final String value;
  final Color color;
  final bool ltr;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              FittedBox(
                child: Text(value,
                    textDirection: ltr ? TextDirection.ltr : null,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
              ),
            ]),
          ),
        ),
      );
}

/// Line chart, time running left to right as on market charts; the last point is today.
class _LinePainter extends CustomPainter {
  _LinePainter(this.values, {required this.up, required this.grid, this.touched});
  final List<double> values;
  final bool up;
  final Color grid;
  final int? touched;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    const padY = 12.0;
    Offset pt(int i) {
      final x = i / (values.length - 1) * size.width;
      final y = padY + (1 - (values[i] - lo) / span) * (size.height - 2 * padY);
      return Offset(x, y);
    }

    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = padY + k / 3 * (size.height - 2 * padY);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }

    final color = up ? GoldColors.up : GoldColors.down;
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(pt(values.length - 1).dx, size.height)
      ..lineTo(pt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    final t = touched ?? values.length - 1;
    final o = pt(t);
    if (touched != null) {
      canvas.drawLine(Offset(o.dx, 0), Offset(o.dx, size.height), gp..color = color.withValues(alpha: .5));
    }
    canvas.drawCircle(o, 5.5, Paint()..color = color);
    canvas.drawCircle(o, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.touched != touched || old.up != up || old.grid != grid;
}
