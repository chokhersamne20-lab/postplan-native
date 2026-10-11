import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'alarms.dart';
import 'screens.dart';
import 'state.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const PostPlanApp(),
    ),
  );
}

/// নোটিফিকেশন ট্যাপ → সেই দিনের শিডিউল / হিসাব ফর্ম
void routePayload(String payload) {
  final parts = payload.split('|');
  final nav = navigatorKey.currentState;
  if (nav == null || parts.length < 2) return;
  if (parts[0] == 'alarm') {
    nav.push(MaterialPageRoute(builder: (_) => ScheduleScreen(dayKey: parts[1])));
  } else if (parts[0] == 'stats') {
    nav.push(MaterialPageRoute(builder: (_) => StatsScreen(dayKey: parts[1])));
  }
}

class PostPlanApp extends StatelessWidget {
  const PostPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostPlan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      navigatorKey: navigatorKey,
      home: const _Boot(),
    );
  }
}

/// শুরুতে লোকাল স্টোর লোড → প্রথমবার হলে Welcome, নইলে ক্যালেন্ডার
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().init();
    AlarmEngine.i.onRoute = routePayload;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }
    // বন্ধ অবস্থায় নোটিফিকেশনে চেপে খুলেছে কিনা — একবার চেক
    if (!_routed) {
      _routed = true;
      AlarmEngine.i.launchPayload().then((p) {
        if (p != null) routePayload(p);
      });
    }
    if (!app.store.onboardingDone) {
      return WelcomeScreen(onDone: () async {
        await app.store.setOnboardingDone();
        if (context.mounted) setState(() {});
      });
    }
    return const CalendarScreen();
  }
}
