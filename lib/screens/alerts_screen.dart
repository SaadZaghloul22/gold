import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/gold_math.dart';
import '../core/theme.dart';
import '../services/alert_service.dart';
import '../state/alerts.dart';
import '../state/prices.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AlertController>();
    final p = context.watch<PriceController>();
    final scheme = Theme.of(context).colorScheme;
    final list = a.alerts.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('تنبيهات السعر')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-alert'),
        onPressed: () => showAddAlert(context),
        icon: const Icon(Icons.add_alert),
        label: const Text('تنبيه جديد', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notifications_active_outlined, size: 64, color: GoldColors.gold.withValues(alpha: .7)),
                  const SizedBox(height: 12),
                  const Text('لا توجد تنبيهات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'حدد السعر الذي تنتظره، وسنرسل لك إشعاراً عندما يصل إليه جرام الذهب — حتى والتطبيق مغلق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.6, color: scheme.onSurface.withValues(alpha: .65)),
                  ),
                ]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return Text(
                    'يتم فحص السعر تقريباً كل 30 دقيقة في الخلفية، وكل دقيقتين والتطبيق مفتوح. '
                    'التنبيه يعمل مرة واحدة ثم يتوقف، ويمكنك إعادة تفعيله.',
                    style: TextStyle(fontSize: 12, height: 1.6, color: scheme.onSurface.withValues(alpha: .6)),
                  );
                }
                final x = list[i];
                final c = x.c;
                final q = p.quote;
                final r = q?.rate(c.currency);
                final now = q == null || r == null ? null : gramPrice(usdPerOunce: q.xau, usdToLocal: r, karat: x.karat);
                return Dismissible(
                  key: ValueKey(x.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: GoldColors.down, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await a.remove(x.id);
                    await syncAlertWork(a.anyEnabled);
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      child: Row(children: [
                        Icon(x.above ? Icons.trending_up : Icons.trending_down,
                            color: x.above ? GoldColors.up : GoldColors.down),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              '${c.flag} عيار ${x.karat} ${x.above ? 'فوق' : 'تحت'} ${moneyIn(x.target, c)}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            if (x.firedAt != null)
                              Text(
                                'تحقق ${DateFormat('d MMM h:mm a', 'ar').format(x.firedAt!)}'
                                '${x.firedPrice == null ? '' : ' عند ${money(x.firedPrice!, c.decimals)}'}',
                                style: const TextStyle(fontSize: 12, color: GoldColors.up, fontWeight: FontWeight.w700),
                              )
                            else if (now != null)
                              Text('السعر الآن ${moneyIn(now, c)}',
                                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .6))),
                          ]),
                        ),
                        Switch(
                          value: x.enabled,
                          onChanged: (on) async {
                            await a.toggle(x.id, on);
                            await syncAlertWork(a.anyEnabled);
                          },
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await a.remove(x.id);
                            await syncAlertWork(a.anyEnabled);
                          },
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> showAddAlert(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddAlertSheet(),
  );
  if (ok == true && context.mounted) {
    final granted = await Notifier.instance.requestPermission();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فعّل إشعارات التطبيق من إعدادات الهاتف حتى يصلك التنبيه.')),
      );
    }
  }
}

class _AddAlertSheet extends StatefulWidget {
  const _AddAlertSheet();
  @override
  State<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends State<_AddAlertSheet> {
  int karat = 21;
  bool above = true;
  final target = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = context.read<PriceController>();
    final now = p.gram(karat);
    if (now != null) target.text = (now * 1.01).toStringAsFixed(p.country.decimals);
  }

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PriceController>();
    final c = p.country;
    final now = p.gram(karat);
    final t = parseNum(target.text);
    String? hint;
    if (t != null && now != null) {
      if (above && t <= now) hint = 'السعر الحالي أعلى من هذا بالفعل — سيصلك التنبيه فوراً.';
      if (!above && t >= now) hint = 'السعر الحالي أقل من هذا بالفعل — سيصلك التنبيه فوراً.';
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('تنبيه سعر — ${c.flag} ${c.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final k in karats)
            ChoiceChip(
              label: Text('عيار $k'),
              selected: karat == k,
              onSelected: (_) => setState(() {
                karat = k;
                final n = p.gram(k);
                if (n != null) target.text = (n * (above ? 1.01 : .99)).toStringAsFixed(c.decimals);
              }),
            ),
        ]),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('عندما يرتفع إلى'), icon: Icon(Icons.trending_up)),
            ButtonSegment(value: false, label: Text('عندما ينخفض إلى'), icon: Icon(Icons.trending_down)),
          ],
          selected: {above},
          onSelectionChanged: (s) => setState(() {
            above = s.first;
            final n = p.gram(karat);
            if (n != null) target.text = (n * (above ? 1.01 : .99)).toStringAsFixed(c.decimals);
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('alert-target'),
          controller: target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: 'سعر الجرام المستهدف', suffixText: c.unit),
        ),
        if (now != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('السعر الحالي: ${moneyIn(now, c)}', style: const TextStyle(fontSize: 13)),
          ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hint, style: const TextStyle(fontSize: 12, color: GoldColors.goldDeep)),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('save-alert'),
          onPressed: t == null || t <= 0
              ? null
              : () async {
                  final a = context.read<AlertController>();
                  await a.add(country: c.code, karat: karat, above: above, target: t);
                  await syncAlertWork(true);
                  if (context.mounted) Navigator.pop(context, true);
                },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('حفظ التنبيه', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ]),
    );
  }
}
