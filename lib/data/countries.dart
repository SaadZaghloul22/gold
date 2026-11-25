/// Countries offered (same set as the maelumatii site), Gulf first.
class Country {
  const Country(this.code, this.name, this.flag, this.currency, this.unit, this.decimals, {this.tola = false});

  /// ISO 3166 code, used as the saved choice.
  final String code;
  final String name;
  final String flag;

  /// ISO 4217 currency code.
  final String currency;

  /// Arabic currency name shown next to prices.
  final String unit;
  final int decimals;

  /// Markets where gold is also quoted per tola (11.6638 g).
  final bool tola;
}

const countries = <Country>[
  Country('AE', 'الإمارات', '🇦🇪', 'AED', 'درهم', 2, tola: true),
  Country('SA', 'السعودية', '🇸🇦', 'SAR', 'ريال', 2),
  Country('KW', 'الكويت', '🇰🇼', 'KWD', 'دينار', 3),
  Country('QA', 'قطر', '🇶🇦', 'QAR', 'ريال', 2),
  Country('OM', 'عُمان', '🇴🇲', 'OMR', 'ريال', 3),
  Country('BH', 'البحرين', '🇧🇭', 'BHD', 'دينار', 3),
  Country('EG', 'مصر', '🇪🇬', 'EGP', 'جنيه', 0),
  Country('JO', 'الأردن', '🇯🇴', 'JOD', 'دينار', 3),
  Country('IQ', 'العراق', '🇮🇶', 'IQD', 'دينار', 0),
  Country('LB', 'لبنان', '🇱🇧', 'LBP', 'ليرة', 0),
  Country('YE', 'اليمن', '🇾🇪', 'YER', 'ريال', 0),
  Country('MA', 'المغرب', '🇲🇦', 'MAD', 'درهم', 2),
  Country('DZ', 'الجزائر', '🇩🇿', 'DZD', 'دينار', 0),
  Country('TN', 'تونس', '🇹🇳', 'TND', 'دينار', 2),
  Country('LY', 'ليبيا', '🇱🇾', 'LYD', 'دينار', 2),
  Country('TR', 'تركيا', '🇹🇷', 'TRY', 'ليرة', 0),
  Country('IN', 'الهند', '🇮🇳', 'INR', 'روبية', 0, tola: true),
  Country('PK', 'باكستان', '🇵🇰', 'PKR', 'روبية', 0, tola: true),
  Country('BD', 'بنغلاديش', '🇧🇩', 'BDT', 'تاكا', 0, tola: true),
  Country('NP', 'نيبال', '🇳🇵', 'NPR', 'روبية', 0, tola: true),
  Country('LK', 'سريلانكا', '🇱🇰', 'LKR', 'روبية', 0),
  Country('PH', 'الفلبين', '🇵🇭', 'PHP', 'بيسو', 0),
  Country('MY', 'ماليزيا', '🇲🇾', 'MYR', 'رينغيت', 2),
  Country('ID', 'إندونيسيا', '🇮🇩', 'IDR', 'روبية', 0),
  Country('SG', 'سنغافورة', '🇸🇬', 'SGD', 'دولار', 2),
  Country('TH', 'تايلاند', '🇹🇭', 'THB', 'باهت', 2),
  Country('VN', 'فيتنام', '🇻🇳', 'VND', 'دونغ', 0),
  Country('CN', 'الصين', '🇨🇳', 'CNY', 'يوان', 2),
  Country('JP', 'اليابان', '🇯🇵', 'JPY', 'ين', 0),
  Country('US', 'أمريكا', '🇺🇸', 'USD', 'دولار', 2),
  Country('CA', 'كندا', '🇨🇦', 'CAD', 'دولار', 2),
  Country('MX', 'المكسيك', '🇲🇽', 'MXN', 'بيسو', 2),
  Country('BR', 'البرازيل', '🇧🇷', 'BRL', 'ريال', 2),
  Country('GB', 'بريطانيا', '🇬🇧', 'GBP', 'إسترليني', 2),
  Country('DE', 'ألمانيا (اليورو)', '🇪🇺', 'EUR', 'يورو', 2),
  Country('CH', 'سويسرا', '🇨🇭', 'CHF', 'فرنك', 2),
  Country('AU', 'أستراليا', '🇦🇺', 'AUD', 'دولار', 2),
  Country('ZA', 'جنوب أفريقيا', '🇿🇦', 'ZAR', 'راند', 2),
  Country('NG', 'نيجيريا', '🇳🇬', 'NGN', 'نايرا', 0),
  Country('GH', 'غانا', '🇬🇭', 'GHS', 'سيدي', 2),
  Country('KE', 'كينيا', '🇰🇪', 'KES', 'شلن', 0),
];

Country countryByCode(String? code) =>
    countries.firstWhere((c) => c.code == code, orElse: () => countries.first);

/// Currencies pegged to the US dollar at an official fixed rate (same as the site).
const pegs = <String, double>{
  'USD': 1,
  'AED': 3.6725,
  'SAR': 3.75,
  'QAR': 3.64,
  'OMR': 0.3845,
  'BHD': 0.376,
  'JOD': 0.709,
};
