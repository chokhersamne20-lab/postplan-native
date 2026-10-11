import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';

// ==================================================================
// 🌙 দিন শেষ — হিসাব ফর্ম (ভিউ/এনগেজমেন্ট/ইনকাম/ফলোয়ার)
// ==================================================================
class StatsScreen extends StatefulWidget {
  final String dayKey;
  const StatsScreen({super.key, required this.dayKey});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final TextEditingController _views, _engage, _income, _followers;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().forDay(widget.dayKey).stats;
    String v(num x) => (s.ts == 0 || x == 0) ? '' : '$x';
    _views = TextEditingController(text: v(s.views));
    _engage = TextEditingController(text: v(s.engage));
    _income = TextEditingController(text: v(s.income));
    _followers = TextEditingController(text: v(s.followers));
  }

  @override
  void dispose() {
    for (final c in [_views, _engage, _income, _followers]) { c.dispose(); }
    super.dispose();
  }

  int _num(TextEditingController c) => int.tryParse(asciiDigits(c.text).trim()) ?? 0;

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    await app.saveStats(
      widget.dayKey,
      DayStats(
        views: _num(_views),
        engage: _num(_engage),
        income: double.tryParse(asciiDigits(_income.text).trim()) ?? 0,
        followers: _num(_followers),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ আজকের হিসাব সেভ হয়েছে!')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.forDay(widget.dayKey);
    final d = parseDayKey(widget.dayKey);
    final ro = b.readOnly;

    return Scaffold(
      appBar: AppBar(title: Text('🌙 হিসাব — ${fmtDateBn(d)}', style: const TextStyle(fontSize: 16))),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        if (ro)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: AppTheme.glassCard(tint: AppTheme.red),
            child: const Text('📖 অতীতের দিন — শুধু দেখা যাবে, বদলানো যাবে না'),
          ),
        // সার দিন সামারি
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(tint: AppTheme.gold),
          child: Row(children: [
            Expanded(child: _mini('📝 পোস্ট হয়েছে', '${bnDigits(b.postedCount)}/${bnDigits(b.plan?.count ?? 0)}')),
            Expanded(child: _mini('🗓️ পরিকল্পনা', b.plan == null ? 'নেই' : '${bnDigits(b.plan!.count)}টা')),
            Expanded(child: _mini('💾 জমা', b.stats.ts == 0 ? 'না' : '✅')),
          ]),
        ),
        const SizedBox(height: 18),
        _field(_views, '👁️ আজকের মোট ভিউ', 'যেমন: 12,300'),
        _field(_engage, '💬 এনগেজমেন্ট', 'যেমন: 850'),
        _field(_income, '💵 ইনকাম (USD)', 'যেমন: 1.25'),
        _field(_followers, '👥 নতুন ফলোয়ার', 'যেমন: 34'),
        const SizedBox(height: 10),
        const Text('⚠️ ফেসবুকে রাত ১২টায় দিনের ডেটা রিসেট হয় — তার আগে জমা দিন। বাংলা সংখ্যাতেও লিখতে পারবেন।',
            style: TextStyle(color: AppTheme.textDim, fontSize: 12.5, height: 1.5)),
        const SizedBox(height: 16),
        if (!ro)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Text('💾'),
              label: Text(_busy ? 'সেভ হচ্ছে…' : 'হিসাব জমা দিন'),
            ),
          ),
      ]),
    );
  }

  Widget _mini(String t, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(color: AppTheme.textDim, fontSize: 11.5)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ]);

  Widget _field(TextEditingController c, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          enabled: !context.read<AppState>().forDay(widget.dayKey).readOnly,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
}

// ==================================================================
// 📊 মাসিক হিসাব ও অ্যানালিটিক্স
// ==================================================================
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<DayBundle> _days = [];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final now = DateTime.now();
    final out = <DayBundle>[];
    for (var i = 29; i >= 0; i--) {
      final k = planDayKeyOf(now.subtract(Duration(days: i)));
      final b = app.store.loadDay(k) ?? app.forDay(k);
      if (b.plan != null || b.stats.ts > 0) out.add(b);
    }
    _days = out;
  }

  int _sum(int Function(DayBundle) f, Iterable<DayBundle> l) => l.fold(0, (a, b) => a + f(b));
  double _sumD(double Function(DayBundle) f, Iterable<DayBundle> l) => l.fold(0.0, (a, b) => a + f(b));

  String _pct(double cur, double prev) {
    if (prev <= 0) return '—';
    final p = (cur - prev) / prev * 100;
    return '${p >= 0 ? '▲ +' : '▼ '}${bnDigits(p.abs().toStringAsFixed(0))}%';
  }

  Future<void> _exportCsv() async {
    final rows = <String>['date,planned,posted,views,engage,income,followers'];
    for (final b in _days) {
      rows.add('${b.dateKey},${b.plan?.count ?? 0},${b.postedCount},${b.stats.views},${b.stats.engage},${b.stats.income},${b.stats.followers}');
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/postplan_last30.csv');
    await f.writeAsString(rows.join('\n'));
    if (!mounted) return;
    await Share.shareXFiles([XFile(f.path)], text: 'PostPlan — শেষ ৩০ দিনের হিসাব');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final last7 = _days.length > 7 ? _days.sublist(_days.length - 7) : _days;
    final prev7 = _days.length > 14 ? _days.sublist(_days.length - 14, _days.length - 7) : <DayBundle>[];

    final post7 = _sum((b) => b.postedCount, last7).toDouble();
    final postP7 = _sum((b) => b.postedCount, prev7).toDouble();
    final view7 = _sum((b) => b.stats.views, last7).toDouble();
    final viewP7 = _sum((b) => b.stats.views, prev7).toDouble();
    final inc7 = _sumD((b) => b.stats.income, last7);

    DayBundle? best;
    for (final b in _days) {
      if (b.stats.ts > 0 && (best == null || b.stats.views > best!.stats.views)) best = b;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('📊 মাসিক হিসাব'), actions: [
        IconButton(icon: const Text('📤', style: TextStyle(fontSize: 20)), tooltip: 'CSV এক্সপোর্ট',
            onPressed: _days.isEmpty ? null : _exportCsv),
      ]),
      body: _days.isEmpty
          ? const _EmptyAnalytics()
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              // সামারি
              Row(children: [
                _sumCard('📝 ৩০ দিনে পোস্ট', bnDigits(_sum((b) => b.postedCount, _days))),
                _sumCard('👁️ মোট ভিউ', bnDigits(_sum((b) => b.stats.views, _days))),
                _sumCard('💵 মোট ইনকাম', '\$${_sumD((b) => b.stats.income, _days).toStringAsFixed(2)}'),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _sumCard('🔥 স্ট্রিক', '${bnDigits(app.streak)} দিন'),
                _sumCard('🗓️ প্ল্যান-দিন', bnDigits(_days.length)),
                _sumCard('📈 গড়/দিন', bnDigits((_sum((b) => b.postedCount, _days) / _days.length).round())),
              ]),
              const SizedBox(height: 16),
              // উন্নতি/অবনতি
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(tint: view7 >= viewP7 ? AppTheme.emerald : AppTheme.red),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('⚖️ এই সপ্তাহ বনাম গত সপ্তাহ', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _cmpCell('📝 পোস্ট', _pct(post7, postP7)),
                    _cmpCell('👁️ ভিউ', _pct(view7, viewP7)),
                    _cmpCell('💵 ইনকাম', prev7.isEmpty ? '—' : '\$${inc7.toStringAsFixed(2)}'),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              _chartCard('👁️ ভিউ ট্রেন্ড (দিন অনুযায়ী)',
                  _line(_days, (b) => b.stats.views.toDouble(), AppTheme.sky)),
              const SizedBox(height: 12),
              _chartCard('📝 প্রতিদিনের পোস্ট', _bars(_days)),
              const SizedBox(height: 12),
              _chartCard('💵 ইনকাম ট্রেন্ড',
                  _line(_days, (b) => b.stats.income, AppTheme.gold)),
              const SizedBox(height: 16),
              // ডেটা-ইনসাইট
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(tint: AppTheme.gold),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('🧠 আপনার ডেটা কী বলছে', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (best != null)
                    Text('🏆 সেরা দিন: ${fmtDateBn(parseDayKey(best!.dateKey))} — ভিউ ${bnDigits(best!.stats.views)}, ইনকাম \$${best!.stats.income}',
                        style: const TextStyle(color: AppTheme.textMid, height: 1.5, fontSize: 13.5)),
                  Text(
                    postP7 > 0 && post7 > postP7
                        ? '📈 গত সপ্তাহের তুলনায় বেশি পোস্ট দিচ্ছেন — ধারাবাহিকতা ধরে রাখুন!'
                        : postP7 > 0
                            ? '📉 পোস্টের গতি একটু কমেছে — কালকে শুরুতেই প্রাইম সময়ের পোস্ট দিন'
                            : 'প্রথম সপ্তাহের ডেটা জমা হচ্ছে — ১৪ দিন পর তুলনা দেখা যাবে',
                    style: const TextStyle(color: AppTheme.textMid, height: 1.5, fontSize: 13.5),
                  ),
                ]),
              ),
            ]),
    );
  }

  Widget _sumCard(String t, String v) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: AppTheme.glassCard(),
          child: Column(children: [
            Text(t, style: const TextStyle(color: AppTheme.textDim, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(v, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
          ]),
        ),
      );

  Widget _cmpCell(String t, String p) {
    final up = p.startsWith('▲');
    final down = p.startsWith('▼');
    return Column(children: [
      Text(t, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
      const SizedBox(height: 3),
      Text(p, style: TextStyle(
          fontSize: 15.5, fontWeight: FontWeight.w900,
          color: up ? AppTheme.emerald : (down ? AppTheme.red : AppTheme.textDim))),
    ]);
  }

  Widget _chartCard(String title, Widget chart) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 10),
        decoration: AppTheme.glassCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          const SizedBox(height: 12),
          SizedBox(height: 150, child: chart),
        ]),
      );

  FlTitlesData _titles(List<DayBundle> days) => FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 34,
          getTitlesWidget: (v, m) => Text(bnDigits(v.toInt()), style: const TextStyle(fontSize: 9.5, color: AppTheme.textDim)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, interval: (days.length / 5).ceilToDouble(),
          getTitlesWidget: (v, m) {
            final i = v.toInt();
            if (i < 0 || i >= days.length) return const SizedBox();
            return Text(bnDigits(parseDayKey(days[i].dateKey).day),
                style: const TextStyle(fontSize: 9.5, color: AppTheme.textDim));
          },
        )),
      );

  Widget _line(List<DayBundle> days, double Function(DayBundle) f, Color color) {
    final spots = <FlSpot>[
      for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), f(days[i]))
    ];
    if (spots.length < 2) return const Center(child: Text('আরও ১ দিনের ডেটা লাগবে', style: TextStyle(color: AppTheme.textDim)));
    return LineChart(LineChartData(
      minY: 0,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: _titles(days),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots, isCurved: true, preventCurveOverShooting: true,
          color: color, barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .12)),
        ),
      ],
    ));
  }

  Widget _bars(List<DayBundle> days) => BarChart(BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: _titles(days),
        barTouchData: const BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: days[i].postedCount.toDouble(),
                width: 7,
                borderRadius: BorderRadius.circular(3),
                color: days[i].plan != null && days[i].postedCount >= days[i].plan!.count
                    ? AppTheme.emerald
                    : AppTheme.sky,
              ),
            ]),
        ],
      ));
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Text('📊', style: TextStyle(fontSize: 56)),
            SizedBox(height: 14),
            Text('এখনো হিসাব জমা হয়নি', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('প্রতিদিন রাত ১১:৫০-এর অ্যালার্মে হিসাব জমা দিলে এখানে গ্রাফ, উন্নতি-অবনতি, ইনকাম-ট্রেন্ড সব দেখা যাবে।',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMid, height: 1.6)),
          ]),
        ),
      );
}
