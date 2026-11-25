import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/alerts_screen.dart';
import 'screens/calculator_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/prices_screen.dart';
import 'services/alert_service.dart';
import 'state/alerts.dart';
import 'state/prices.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class GoldApp extends StatelessWidget {
  const GoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<PriceController, int>((p) => p.themeMode);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'أسعار الذهب اليوم',
      debugShowCheckedModeBanner: false,
      theme: GoldTheme.light(),
      darkTheme: GoldTheme.dark(),
      themeMode: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark][mode.clamp(0, 2)],
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  late final PriceController _prices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prices = context.read<PriceController>();
    _prices.addListener(_checkAlerts);
    // start after the first frame: refreshing notifies listeners, which must not happen during build
    WidgetsBinding.instance.addPostFrameCallback((_) => _prices.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prices.removeListener(_checkAlerts);
    _prices.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prices = _prices;
    if (state == AppLifecycleState.resumed) {
      prices.start();
      context.read<AlertController>().reload();
    } else if (state == AppLifecycleState.paused) {
      prices.stop();
    }
  }

  DateTime? _checkedFor;

  /// While the app is open, alerts are checked on every fresh quote.
  Future<void> _checkAlerts() async {
    final q = _prices.quote;
    if (q == null || q.fromHistory || q.fetchedAt == _checkedFor) return;
    _checkedFor = q.fetchedAt;
    if (!mounted) return;
    final alerts = context.read<AlertController>();
    final fired = await alerts.check(q);
    for (final a in fired) {
      await Notifier.instance.showFired(a);
    }
    if (fired.isNotEmpty) await syncAlertWork(alerts.anyEnabled);
  }

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    const pages = [PricesScreen(), ChartScreen(), CalculatorScreen(), AlertsScreen()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'الأسعار'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'الرسم البياني'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'الحاسبة'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'التنبيهات'),
        ],
      ),
    );
  }
}
