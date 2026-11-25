import 'package:flutter/material.dart';

import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: .7);
    TextStyle body() => TextStyle(height: 1.7, color: muted);
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('أسعار الذهب اليوم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('الإصدار 1.0.0 — بدون إعلانات وبدون تسجيل.', style: body()),
          const SectionTitle('كيف تُحسب الأسعار؟'),
          Text(
            'نأخذ السعر العالمي لأونصة الذهب بالدولار (السبوت) ونقسمه على 31.1035 جرام، ثم نحوّله '
            'لعملة دولتك بالسعر الرسمي الثابت (مثل 3.75 ريال سعودي و3.6725 درهم إماراتي) أو بسعر الصرف اليومي '
            'للعملات غير المربوطة بالدولار. سعر العيار = سعر عيار 24 × (العيار ÷ 24)؛ فعيار 21 = 87.5% من عيار 24.',
            style: body(),
          ),
          const SectionTitle('مصادر البيانات'),
          Text(
            '• سعر الذهب والفضة: gold-api.com (واحتياطياً Swissquote)\n'
            '• أسعار صرف العملات: open.er-api.com (ExchangeRate-API)\n'
            '• السجل اليومي للرسم البياني: سجل يومي مفتوح لسعر الجرام وأسعار الصرف.',
            style: body(),
          ),
          const SectionTitle('تنبيه مهم'),
          Text(disclaimerText, style: body()),
          const SectionTitle('الخصوصية'),
          Text(
            'لا نجمع أي بيانات شخصية. اختيار الدولة والتنبيهات تُحفظ على جهازك فقط، والتطبيق يتصل بالإنترنت '
            'لجلب الأسعار فقط.',
            style: body(),
          ),
          const SectionTitle('الزكاة'),
          Text(
            'حاسبة الزكاة تعتمد نصاب الذهب 85 جرام من الذهب الخالص (عيار 24) ونسبة 2.5% إذا حال عليه الحول. '
            'للحالات الخاصة (الحلي المستعمل، الديون…) يُرجى سؤال أهل العلم.',
            style: body(),
          ),
        ],
      ),
    );
  }
}
