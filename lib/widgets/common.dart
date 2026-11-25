import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/gold_math.dart';
import '../data/countries.dart';
import '../state/prices.dart';

/// Tappable "🇸🇦 السعودية · ريال ▾" pill that opens the country picker.
class CountryButton extends StatelessWidget {
  const CountryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.select<PriceController, Country>((p) => p.country);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        key: const Key('country-button'),
        customBorder: const StadiumBorder(),
        onTap: () => showCountryPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(c.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(' · ${c.currency}', style: TextStyle(color: scheme.onSurface.withValues(alpha: .6), fontSize: 12)),
            const Icon(Icons.expand_more, size: 18),
          ]),
        ),
      ),
    );
  }
}

Future<void> showCountryPicker(BuildContext context) async {
  final picked = await showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CountrySheet(),
  );
  if (picked != null && context.mounted) {
    await context.read<PriceController>().setCountry(picked);
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet();
  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final current = context.read<PriceController>().country;
    final list = countries
        .where((c) => q.isEmpty || c.name.contains(q) || c.currency.toLowerCase().contains(q.toLowerCase()) || c.unit.contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const Key('country-search'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن دولة أو عملة'),
            onChanged: (v) => setState(() => q = v.trim()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                key: Key('country-${c.code}'),
                leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${c.unit} · ${c.currency}'),
                trailing: c.code == current.code ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () => Navigator.pop(context, c),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// "+0.84%" pill, green up / red down.
class ChangeBadge extends StatelessWidget {
  const ChangeBadge(this.value, {super.key, this.onDark = false});
  final double value;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    final color = value.abs() < 0.005 ? GoldColors.silver : (up ? GoldColors.up : GoldColors.down);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: onDark ? .25 : .12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: onDark ? Colors.white : color),
        const SizedBox(width: 2),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(percent(value),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: onDark ? Colors.white : color)),
        ),
      ]),
    );
  }
}

/// Grey placeholder block shown while the first prices load.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 18, this.width = double.infinity, this.radius = 10});
  final double height;
  final double width;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ?trailing,
        ]),
      );
}

const disclaimerText =
    'الأسعار استرشادية محسوبة من السعر العالمي للذهب (السبوت) وأسعار صرف العملات، ولا تشمل المصنعية أو الضريبة، '
    'وقد تختلف عن أسعار محلات الصاغة والبنوك.';

/// Full-width karat selector: 24 · 22 · 21 · 18 · 14.
class KaratPicker extends StatelessWidget {
  const KaratPicker({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Text('العيار', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<int>(
            segments: [for (final k in karats) ButtonSegment(value: k, label: Text('$k'))],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ]);
}
