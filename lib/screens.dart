import 'dart:async';
import 'dart:math' show pi;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'alarms.dart';
import 'models.dart';
import 'planner.dart';
import 'state.dart';
import 'theme.dart';
import 'util.dart';

export 'pages_stats.dart' show StatsScreen, AnalyticsScreen;

// ==================================================================
// ✨ Welcome — প্রথমবার: অ্যানিমেটেড স্বাগতম
// ==================================================================
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomeScreen({super.key, required this.onDone});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();

  Animation<double> _fade(double a, double b) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: Curves.easeOut));
  Animation<Offset> _slide(double a, double b) =>
      Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(parent: _c, curve: Interval(a, b, curve: Curves.easeOutCubic)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF111C33), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                ScaleTransition(
                  scale: CurvedAnimation(parent: _c, curve: const Interval(0, .45, curve: Curves.elasticOut)),
                  child: Container(
                    width: 110, height: 110,
                    decoration: AppTheme.glassCard(tint: AppTheme.gold, radius: 28),
                    child: const Center(child: Text('🗓️', style: TextStyle(fontSize: 52))),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _fade(.25, .55),
                  child: SlideTransition(
                    position: _slide(.25, .55),
                    child: const Text('PostPlan',
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppTheme.textHi, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _fade(.45, .7),
                  child: SlideTransition(
                    position: _slide(.45, .7),
                    child: const Text('আপনার ফেসবুক পোস্টের স্মার্ট শিডিউলার',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, color: AppTheme.textMid, height: 1.5)),
                  ),
                ),
                const SizedBox(height: 30),
                FadeTransition(
                  opacity: _fade(.6, .85),
                  child: SlideTransition(
                    position: _slide(.6, .85),
                    child: const Wrap(
                      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                      children: [
                        _Pill('📅 ৩০ দিন আগের প্ল্যান'),
                        _Pill('🔢 যেকোনো সংখ্যার পোস্ট'),
                        _Pill('⏰ স্মার্ট অ্যালার্ম'),
                        _Pill('📊 মাসিক অ্যানালিটিক্স'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _fade(.8, 1),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onDone,
                      icon: const Text('🚀'),
                      label: const Text('শুরু করুন'),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: AppTheme.glassCard(radius: 30),
        child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppTheme.textHi, fontWeight: FontWeight.w600)),
      );
}

// ==================================================================
// ➕ কুইক-অ্যাড: + বাটন → আগামী ৩০ দিনের যেকোনো দিন বেছে সিডিউল
// ==================================================================
void openDayFlow(BuildContext context, DateTime day) {
  final app = context.read<AppState>();
  final d = DateTime(day.year, day.month, day.day);
  final key = dateKeyOf(d);
  final today = app.todayKey;
  final nowD = parseDayKey(today);
  final ahead = d.difference(nowD).inDays;

  if (key.compareTo(today) < 0 || app.hasPlan(key)) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen(dayKey: key)));
  } else if (ahead <= 30) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DaySetupScreen(dayKey: key)));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ সর্বোচ্চ ১ মাস (৩০ দিন) আগ পর্যন্ত প্ল্যান করা যায়')));
  }
}

Future<void> showQuickAdd(BuildContext context) {
  final app = context.read<AppState>();
  final todayD = parseDayKey(app.todayKey);
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: BoxDecoration(color: AppTheme.bgSoft, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.glassBorder)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 44, height: 4,
            decoration: BoxDecoration(color: AppTheme.textDim, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 16),
        const Text('➕ কোন দিনের সিডিউল বানাবেন?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const Text('আগামী ১ মাস (৩০ দিন) — দিন বেছে নিন', style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: GridView.count(
            crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05,
            children: [for (var i = 0; i < 30; i++) _dayChip(ctx, app, todayD.add(Duration(days: i)), i)],
          ),
        ),
      ]),
    ),
  );
}

Widget _dayChip(BuildContext ctx, AppState app, DateTime day, int i) {
  final key = dateKeyOf(day);
  final planned = app.hasPlan(key);
  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () {
      Navigator.pop(ctx);
      openDayFlow(ctx, day);
    },
    child: Container(
      decoration: AppTheme.glassCard(tint: i == 0 ? AppTheme.gold : (planned ? AppTheme.emerald : null), radius: 16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(i == 0 ? 'আজ' : weekdayShortBn(day),
            style: TextStyle(fontSize: 11.5, color: i == 0 ? AppTheme.gold : AppTheme.textDim, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(bnDigits(day.day), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        if (planned) const Text('●', style: TextStyle(fontSize: 8, color: AppTheme.emerald)),
      ]),
    ),
  );
}

// ==================================================================
// 📅 ক্যালেন্ডার হোম
// ==================================================================
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final todayD = parseDayKey(app.todayKey);
    final postedToday = app.postedOf(app.todayKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PostPlan'),
        actions: [
          Center(child: Text('🔥 ${bnDigits(app.streak)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(icon: const Text('📊', style: TextStyle(fontSize: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
          IconButton(icon: const Text('⚙️', style: TextStyle(fontSize: 20)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.gold,
        foregroundColor: const Color(0xFF1A1206),
        onPressed: () => showQuickAdd(context),
        icon: const Icon(Icons.add, size: 26),
        label: const Text('সিডিউল', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // আজকের চিপ
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openDayFlow(context, todayD),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.glassCard(tint: AppTheme.gold),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('📍 আজকের দিন', style: TextStyle(color: AppTheme.textDim, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(fmtDateBn(todayD), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('পোস্ট হয়েছে: ${bnDigits(postedToday)}টা', style: const TextStyle(color: AppTheme.emerald, fontSize: 13.5)),
                ])),
                const Icon(Icons.chevron_right, color: AppTheme.textDim, size: 30),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // মাস-হেডার
          Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
              setState(() => _focused = DateTime(_focused.year, _focused.month - 1, 1));
            }),
            Expanded(child: Center(child: Text('${monthBn(_focused.month)} ${bnDigits(_focused.year)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
              final n = DateTime(_focused.year, _focused.month + 1, 1);
              if (!n.isAfter(todayD.add(const Duration(days: 31)))) setState(() => _focused = n);
            }),
          ]),
          // ক্যালেন্ডার
          Container(
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.glassCard(),
            child: TableCalendar<void>(
              firstDay: todayD.subtract(const Duration(days: 365)),
              lastDay: todayD.add(const Duration(days: 31)),
              focusedDay: _focused,
              startingDayOfWeek: StartingDayOfWeek.saturday,
              headerVisible: false,
              daysOfWeekHeight: 34,
              rowHeight: 52,
              onDaySelected: (sel, foc) { setState(() => _focused = foc); openDayFlow(context, sel); },
              onPageChanged: (foc) => setState(() => _focused = foc),
              calendarBuilders: CalendarBuilders(
                dowBuilder: (ctx, day) => Center(child: Text(weekdayShortBn(day),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.w700))),
                defaultBuilder: (ctx, day, foc) => _dayCell(app, day, todayD, false),
                todayBuilder: (ctx, day, foc) => _dayCell(app, day, todayD, true),
                outsideBuilder: (ctx, day, foc) => _dayCell(app, day, todayD, false, outside: true),
                selectedBuilder: (ctx, day, foc) => _dayCell(app, day, todayD, false),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('● ', style: TextStyle(color: AppTheme.emerald, fontSize: 10)),
            Text('প্ল্যান আছে   ', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
            Text('● ', style: TextStyle(color: AppTheme.gold, fontSize: 10)),
            Text('আজ   ', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
            Text('🏖️ ', style: TextStyle(fontSize: 10)),
            Text('ছুটির দিন', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _dayCell(AppState app, DateTime day, DateTime todayD, bool isToday, {bool outside = false}) {
    final key = dateKeyOf(day);
    final planned = app.hasPlan(key);
    final off = app.isOffDay(key);
    final dim = outside ? AppTheme.textDim.withValues(alpha: .4) : null;
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isToday ? AppTheme.gold.withValues(alpha: .16) : AppTheme.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday ? AppTheme.gold : AppTheme.glassBorder.withValues(alpha: .5)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(bnDigits(day.day), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dim ?? AppTheme.textHi)),
        const SizedBox(height: 1),
        Text(off ? '🏖️' : (planned ? '●' : ''),
            style: TextStyle(fontSize: 8, color: planned ? AppTheme.emerald : AppTheme.textDim)),
      ]),
    );
  }
}

// ==================================================================
// 🧙 দিনের সেটআপ — ৪ ধাপ
// ==================================================================
class DaySetupScreen extends StatefulWidget {
  final String dayKey;
  const DaySetupScreen({super.key, required this.dayKey});
  @override
  State<DaySetupScreen> createState() => _DaySetupScreenState();
}

class _DaySetupScreenState extends State<DaySetupScreen> {
  int _step = 0;
  final _countC = TextEditingController(text: '30');
  final Map<Segment, TextEditingController> _segCountC = {}, _segGapC = {};
  late AlarmPrefs _alarm;
  List<SlotItem> _preview = [];
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _alarm = context.read<AppState>().alarmPrefs.copy();
    final split = suggestSplit(30);
    for (final s in kSegments) {
      _segCountC[s.seg] = TextEditingController(text: '${split[s.seg]}');
      _segGapC[s.seg] = TextEditingController(text: '${suggestGap(s.seg)}');
    }
  }

  @override
  void dispose() {
    _countC.dispose();
    for (final c in _segCountC.values) { c.dispose(); }
    for (final c in _segGapC.values) { c.dispose(); }
    super.dispose();
  }

  int get _count => int.tryParse(_countC.text) ?? 0;
  Map<Segment, int> get _segCounts => {for (final s in kSegments) s.seg: int.tryParse(_segCountC[s.seg]!.text) ?? 0};
  Map<Segment, int> get _segGaps => {for (final s in kSegments) s.seg: int.tryParse(_segGapC[s.seg]!.text) ?? suggestGap(s.seg)};
  int get _segSum => _segCounts.values.fold(0, (a, b) => a + b);

  void _suggestSplitAgain() {
    final split = suggestSplit(_count);
    for (final s in kSegments) { _segCountC[s.seg]!.text = '${split[s.seg]}'; }
    setState(() {});
  }

  void _regen() {
    setState(() {
      _seed = DateTime.now().microsecondsSinceEpoch;
      _preview = generateTimes(_segCounts, _segGaps, seed: _seed);
    });
  }

  Future<void> _finish() async {
    final app = context.read<AppState>();
    HapticFeedback.mediumImpact();
    await app.generateAndSave(widget.dayKey, _count, _segCounts, _segGaps, _alarm);
    await app.saveAlarmPrefs(_alarm);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ScheduleScreen(dayKey: widget.dayKey)));
  }

  bool get _stepOk => switch (_step) {
        0 => _count >= 1 && _count <= kMaxPostsPerDay,
        1 => _segSum == _count,
        2 => true,
        _ => _preview.length == _count,
      };

  @override
  Widget build(BuildContext context) {
    final d = parseDayKey(widget.dayKey);
    return Scaffold(
      appBar: AppBar(title: Text(fmtDateBn(d))),
      body: Column(children: [
        // ধাপ-বার
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(child: Container(
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= _step ? AppTheme.gold : AppTheme.glass,
                  borderRadius: BorderRadius.circular(4)),
              )),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
          child: _step == 0 ? _stepCount() : _step == 1 ? _stepSegments() : _step == 2 ? _stepAlarm() : _stepPreview(),
        )),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          child: Row(children: [
            if (_step > 0) TextButton.icon(onPressed: () => setState(() => _step--),
                icon: const Icon(Icons.chevron_left), label: const Text('আগে')),
            const Spacer(),
            ElevatedButton(
              onPressed: _stepOk ? () {
                if (_step == 1) { _regen(); }
                if (_step < 3) { setState(() => _step++); } else { _finish(); }
              } : null,
              child: Text(_step < 3 ? 'পরের ধাপ →' : '✅ প্ল্যান তৈরি'),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _stepCount() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepTitle('১', 'আজ কয়টা পোস্ট করতে চান?'),
        const SizedBox(height: 14),
        TextField(
          controller: _countC,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'যেমন: ৩০',
            helperText: _count > kMaxPostsPerDay ? '⚠️ এক দিনে সর্বোচ্চ ${bnDigits(kMaxPostsPerDay)}টা' : '${bnDigits(_count)}টা পোস্ট',
            helperStyle: TextStyle(color: _count > kMaxPostsPerDay ? AppTheme.red : AppTheme.textDim, fontSize: 15),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, children: [
          for (final n in [10, 20, 30, 45, 60, 90])
            ActionChip(
              label: Text(bnDigits(n), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              onPressed: () { _countC.text = '$n'; setState(() {}); },
            ),
        ]),
      ]);

  Widget _stepSegments() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepTitle('২', '৩ ভাগে বণ্টন + গ্যাপ', trailing: TextButton.icon(
          onPressed: _suggestSplitAgain,
          icon: const Text('✨'), label: const Text('নিজে ভাগ করো'))),
        const SizedBox(height: 6),
        Text(_segSum == _count
            ? '✅ মিলে গেছে: মোট ${bnDigits(_segSum)}টা'
            : '⚠️ তিন ভাগের যোগফল ${bnDigits(_segSum)} — মোট ${bnDigits(_count)} হতে হবে',
          style: TextStyle(color: _segSum == _count ? AppTheme.emerald : AppTheme.red, fontSize: 13.5)),
        const SizedBox(height: 12),
        for (final s in kSegments) _segCard(s),
      ]);

  Widget _segCard(SegmentDef s) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.emoji} ${s.label}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          Text('${fmtMinOfDay(s.startMin)} → ${fmtMinOfDay(s.endMin)}',
              style: const TextStyle(color: AppTheme.textDim, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              controller: _segCountC[s.seg],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'কয়টা পোস্ট', isDense: true),
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _segGapC[s.seg],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'গ্যাপ (মিনিট)', isDense: true),
              onChanged: (_) => setState(() {}),
            )),
          ]),
        ]),
      );

  Widget _stepAlarm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepTitle('৩', '⏰ অ্যালার্ম কেমন চান?'),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _alarm.master,
          onChanged: (v) async {
            setState(() => _alarm.master = v);
            if (v && mounted) {
              final msg = await context.read<AppState>().alarms.ensurePermissions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            }
          },
          title: const Text('অ্যালার্মের সব সুবিধা চালু', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('নোটিফিকেশন, ভয়েস, ফ্ল্যাশ, ভাইব্রেশন'),
        ),
        if (_alarm.master) ...[
          const SizedBox(height: 8),
          const Text('কত মিনিট আগে বাজবে', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final m in [1, 2, 3, 5, 10])
              ChoiceChip(label: Text('${bnDigits(m)} মিনিট'), selected: _alarm.leadMin == m,
                  onSelected: (_) => setState(() => _alarm.leadMin = m)),
          ]),
          const SizedBox(height: 14),
          const Text('কতক্ষণ বাজবে', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('টিক না দেওয়া পর্যন্ত'), selected: _alarm.ring == RingMode.untilTick,
                onSelected: (_) => setState(() => _alarm.ring = RingMode.untilTick)),
            ChoiceChip(label: const Text('১ মিনিট'), selected: _alarm.ring == RingMode.min1,
                onSelected: (_) => setState(() => _alarm.ring = RingMode.min1)),
            ChoiceChip(label: const Text('৩ মিনিট'), selected: _alarm.ring == RingMode.min3,
                onSelected: (_) => setState(() => _alarm.ring = RingMode.min3)),
          ]),
          const SizedBox(height: 10),
          SwitchListTile(value: _alarm.voice, dense: true,
              title: const Text('🗣️ বাংলা ভয়েস ঘোষণা'), onChanged: (v) => setState(() => _alarm.voice = v)),
          SwitchListTile(value: _alarm.flash, dense: true,
              title: const Text('🔦 ফ্ল্যাশলাইট জ্বলা-নেভা'), onChanged: (v) => setState(() => _alarm.flash = v)),
          SwitchListTile(value: _alarm.vibrate, dense: true,
              title: const Text('📳 ভাইব্রেশন'), onChanged: (v) => setState(() => _alarm.vibrate = v)),
          SwitchListTile(value: _alarm.statsAlarm, dense: true,
              title: const Text('📊 রাত ১১:৫০-এ হিসাব-অ্যালার্ম'),
              onChanged: (v) => setState(() => _alarm.statsAlarm = v)),
        ],
      ]);

  Widget _stepPreview() {
    if (_preview.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _preview.isEmpty) _regen();
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepTitle('৪', '🎲 র‍্যান্ডম সময় প্রিভিউ', trailing: TextButton.icon(
          onPressed: _regen, icon: const Text('🔄'), label: const Text('আবার বানাও'))),
      const SizedBox(height: 10),
      for (final def in kSegments)
        if ((_segCounts[def.seg] ?? 0) > 0) ...[
          Text('${def.emoji} ${def.label} (${bnDigits(_segCounts[def.seg]!)}টা)',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in _preview.where((x) => x.segment == def.seg))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: AppTheme.glassCard(tint: _qColor(s.quality), radius: 10),
                child: Text(fmtMinOfDay(s.minuteOfDay),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _qColor(s.quality))),
              ),
          ]),
          const SizedBox(height: 14),
        ],
    ]);
  }
}

Color _qColor(TimeQuality q) => switch (q) {
      TimeQuality.best => AppTheme.gold,
      TimeQuality.great => AppTheme.sky,
      TimeQuality.good => AppTheme.emerald,
      TimeQuality.ok => AppTheme.textMid,
      TimeQuality.bad => AppTheme.red,
    };

class _StepTitle extends StatelessWidget {
  final String n, title;
  final Widget? trailing;
  const _StepTitle(this.n, this.title, {this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(11)),
          child: Center(child: Text(bnDigits(n), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1A1206)))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (trailing != null) trailing!,
      ]);
}

// ==================================================================
// 🗂️ শিডিউল পেজ (প্রিমিয়াম)
// ==================================================================
class ScheduleScreen extends StatefulWidget {
  final String dayKey;
  const ScheduleScreen({super.key, required this.dayKey});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Timer? _t;
  late final ConfettiController _conf =
      ConfettiController(duration: const Duration(seconds: 2));
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _t?.cancel();
    _conf.dispose();
    super.dispose();
  }

  SlotItem? _nextSlot(DayBundle b) {
    final plan = b.plan;
    if (plan == null) return null;
    for (final s in plan.slots) {
      if (!(b.states[s.index]?.posted ?? false)) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.forDay(widget.dayKey);
    final plan = b.plan;
    final d = parseDayKey(widget.dayKey);
    final isToday = widget.dayKey == app.todayKey;
    final off = app.isOffDay(widget.dayKey);

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(fmtDateBn(d))),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🗓️', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 12),
          Text(b.readOnly ? 'এই দিনে কোনো প্ল্যান ছিল না' : 'এই দিনের প্ল্যান এখনো নেই',
              style: const TextStyle(color: AppTheme.textMid, fontSize: 16)),
          if (!b.readOnly) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => DaySetupScreen(dayKey: widget.dayKey))),
              icon: const Text('🧙'), label: const Text('প্ল্যান বানাও'),
            ),
          ],
        ])),
      );
    }

    final done = b.postedCount;
    final next = _nextSlot(b);
    final allDone = done >= plan.count;

    // 🎉 টার্গেট পূর্ণে কনফেটি (একবার)
    if (allDone && !_celebrated) {
      _celebrated = true;
      _conf.play();
    }

    final remain = next != null
        ? slotDateTime(widget.dayKey, next.minuteOfDay).difference(DateTime.now())
        : Duration.zero;
    final yKey = planDayKeyOf(DateTime.now().subtract(const Duration(days: 1)));

    // ⏰ রিং শর্ত: লিড-সময়ের মধ্যে ঢুকেছে আর পোস্ট হয়নি → ব্যানার + ভয়েস/ফ্ল্যাশ/ভাইব্রেশন
    final prefs = plan.alarm;
    final ringNow = next != null && prefs.master && !off && !b.readOnly &&
        DateTime.now().isAfter(slotDateTime(widget.dayKey, next.minuteOfDay)
            .subtract(Duration(minutes: prefs.leadMin)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ringNow && !app.alarms.ringing) {
        app.alarms.startRing('${bnDigits(next!.index + 1)}', prefs);
      } else if (!ringNow && app.alarms.ringing) {
        app.alarms.stopRing();
      }
    });

    // 📊 হিসাব-ব্যানার: রাত ১১:৪০ থেকে (রিসেট ১২টা)
    final nowT = DateTime.now();
    final statsDue = isToday && prefs.statsAlarm && b.stats.ts == 0 &&
        (nowT.hour == 23 && nowT.minute >= 40 || nowT.hour == 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(fmtDateBn(d), style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: Text(off ? '🏖️' : '🏝️', style: TextStyle(fontSize: 20, color: off ? AppTheme.gold : AppTheme.textDim)),
            tooltip: 'ছুটির দিন',
            onPressed: b.readOnly ? null : () => app.setOffDay(widget.dayKey, !off),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        foregroundColor: const Color(0xFF1A1206),
        onPressed: () => showQuickAdd(context),
        child: const Icon(Icons.add, size: 30),
      ),
      body: Stack(alignment: Alignment.topCenter, children: [
        ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 100), children: [
          // হেডার
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCard(tint: allDone ? AppTheme.emerald : AppTheme.gold),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('এখন', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                  Text(fmtClock(DateTime.now()), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('পরের পোস্ট', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                  Text(
                    allDone ? '🎉 শেষ!' : next == null ? '—' : fmtRemain(remain),
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900,
                        color: allDone ? AppTheme.emerald : (remain.isNegative ? AppTheme.red : AppTheme.textHi)),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Text('${bnDigits(done)}/${bnDigits(plan.count)} পোস্ট', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (b.readOnly) const Text('   📖 অতীতের দিন (শুধু দেখা)', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                if (off) const Text('   🏖️ ছুটির দিন', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: plan.count == 0 ? 0 : done / plan.count,
                  minHeight: 9,
                  backgroundColor: AppTheme.glass,
                  valueColor: AlwaysStoppedAnimation(allDone ? AppTheme.emerald : AppTheme.gold),
                ),
              ),
              if (isToday) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft,
                  child: Text('গতকাল: ${bnDigits(app.postedOf(yKey))}টা পোস্ট হয়েছে',
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 12.5))),
              ],
            ]),
          ),
          if (ringNow) ...[
            const SizedBox(height: 12),
            _alarmBanner(app, next!),
          ],
          if (statsDue && !ringNow) ...[
            const SizedBox(height: 12),
            _statsBanner(),
          ],
          const SizedBox(height: 14),
          // কার্ড গ্রিড
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.45,
            children: [for (final s in plan.slots) _slotCard(app, b, s)],
          ),
        ]),
        ConfettiWidget(
          confettiController: _conf,
          blastDirection: pi / 2,
          maxBlastForce: 4, minBlastForce: 1,
          emissionFrequency: .08, numberOfParticles: 18, gravity: .25,
          colors: const [AppTheme.gold, AppTheme.emerald, AppTheme.sky, Colors.white],
        ),
      ]),
    );
  }

  Widget _alarmBanner(AppState app, SlotItem s) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.red.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.red, width: 1.6),
        ),
        child: Column(children: [
          Text('⏰ পোস্ট ${bnDigits(s.index + 1)} — সময় ঘনিয়েছে!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.red)),
          const SizedBox(height: 4),
          const Text('ভয়েস/ফ্ল্যাশ/ভাইব্রেশন চলছে (আপনার সেটিং অনুযায়ী)',
              style: TextStyle(color: AppTheme.textDim, fontSize: 12.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              onPressed: () {
                app.alarms.stopRing();
                app.setPosted(widget.dayKey, s.index, true);
              },
              icon: const Text('✅'),
              label: const Text('পোস্ট হয়ে গেছে — থামাও'),
            ),
          ),
        ]),
      );

  Widget _statsBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCard(tint: AppTheme.gold),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📊 হিসাব জমা দিন!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.gold)),
          const SizedBox(height: 3),
          const Text('রাত ১২টায় ফেসবুক ডেটা রিসেট — আগে লিখে রাখুন',
              style: TextStyle(color: AppTheme.textMid, fontSize: 12.5)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => StatsScreen(dayKey: widget.dayKey))),
              icon: const Text('🌙'),
              label: const Text('হিসাব লেখা শুরু করুন'),
            ),
          ),
        ]),
      );

  Widget _slotCard(AppState app, DayBundle b, SlotItem s) {
    final st = b.states[s.index] ?? SlotState();
    final canSched = app.canSchedule(widget.dayKey, s.minuteOfDay);
    final q = s.quality;
    final color = _qColor(q);
    final readOnly = b.readOnly;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassCard(tint: st.posted ? AppTheme.emerald : (q == TimeQuality.best ? AppTheme.gold : null)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('পোস্ট ${bnDigits(s.index + 1)}', style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          if (st.auto) const Text('⏰অটো', style: TextStyle(fontSize: 10, color: AppTheme.sky)),
        ]),
        const SizedBox(height: 2),
        Text(fmtMinOfDay(s.minuteOfDay), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        Text(qualityLabel(q), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        const Spacer(),
        Row(children: [
          // 📅 সিডিউল — সময় ২০ মিনিটের কম বাকি হলে অপশন অটো-মুছে যায় (FB নিয়ম)
          if (!st.posted && canSched && !readOnly)
            _tickBtn('📅', st.scheduled, () {
              HapticFeedback.lightImpact();
              app.setScheduled(widget.dayKey, s.index, s.minuteOfDay, !st.scheduled);
            }),
          if (st.scheduled && !st.posted)
            const Padding(padding: EdgeInsets.only(left: 6), child: Text('সিডিউলড', style: TextStyle(fontSize: 10.5, color: AppTheme.sky))),
          const Spacer(),
          // ✓ পোস্ট হয়েছে
          _tickBtn(st.posted ? '✅' : '✓', st.posted, readOnly ? null : () {
            HapticFeedback.lightImpact();
            app.setPosted(widget.dayKey, s.index, !st.posted);
          }, filled: st.posted),
        ]),
      ]),
    );
  }

  Widget _tickBtn(String label, bool on, VoidCallback? onTap, {bool filled = false}) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? (filled ? AppTheme.emerald : AppTheme.sky.withValues(alpha: .25)) : AppTheme.glass,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? (filled ? AppTheme.emerald : AppTheme.sky) : AppTheme.glassBorder),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: on ? (filled ? Colors.white : AppTheme.sky) : AppTheme.textMid)),
        ),
      );
}

// ==================================================================
// পরের ধাপের স্ক্রিন (সেটিংস) — স্ট্যাটস/অ্যানালিটিক্স pages_stats.dart-এ
// ==================================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const _Stub('⚙️', 'সেটিংস', 'অ্যালার্ম পছন্দ, ছুটি মোড, থিম, এক্সপোর্ট। (পরের ধাপ)');
}

class _Stub extends StatelessWidget {
  final String title, note;
  final String emoji;
  const _Stub(this.emoji, this.title, this.note);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('$emoji $title')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(note, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMid, height: 1.6)),
            ]),
          ),
        ),
      );
}
