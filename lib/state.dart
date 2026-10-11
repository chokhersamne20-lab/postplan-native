import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarms.dart';
import 'api.dart';
import 'models.dart';
import 'planner.dart';
import 'util.dart';

/// অ্যাপ-ওয়াইড স্টেট (ChangeNotifier) — অফলাইন-ফার্স্ট: লোকালে সাথে সাথে,
/// নেট থাকলে ব্যাকগ্রাউন্ডে Sheets-এ push/pull।
class AppState extends ChangeNotifier {
  final LocalStore store = LocalStore();
  final ApiClient api = ApiClient();
  final AlarmEngine alarms = AlarmEngine.i;

  bool ready = false;
  bool online = true;
  DateTime? lastSync;

  final Map<String, DayBundle> _days = {};
  Set<String> offDays = {};
  int streak = 0;
  Set<String> badges = {};

  Timer? _ticker;

  Future<void> init() async {
    await store.init();
    offDays = store.offDays();
    streak = store.streak;
    badges = store.badges();
    ready = true;
    notifyListeners();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => tick());
    unawaited(syncToday());
    // 🔔 চালু প্ল্যানগুলোর অ্যালার্ম পুনঃসিঙ্ক (রিবুট/আপডেটের পর)
    unawaited(() async {
      await alarms.init();
      final now = DateTime.now();
      for (var i = 0; i <= 30; i++) {
        final k = i == 0 ? todayKey : dateKeyOf(now.add(Duration(days: i)));
        final b = store.loadDay(k);
        if (b?.plan != null && !offDays.contains(k)) {
          unawaited(alarms.syncDay(b!));
        }
      }
    }());
  }

  // ---------- দিন পাওয়া ----------
  String get todayKey => planDayKeyOf(DateTime.now());

  DayBundle forDay(String dayKey) {
    var b = _days[dayKey];
    if (b == null) {
      final isPast = dayKey.compareTo(todayKey) < 0;
      b = store.loadDay(dayKey, readOnly: isPast) ?? DayBundle(dayKey, readOnly: isPast);
      _days[dayKey] = b;
    }
    return b;
  }

  bool isOffDay(String dayKey) => offDays.contains(dayKey);

  bool hasPlan(String dayKey) =>
      (_days[dayKey]?.plan != null) || (store.loadDay(dayKey)?.plan != null);

  int postedOf(String dayKey) => forDay(dayKey).postedCount;

  Future<void> setOffDay(String dayKey, bool off) async {
    off ? offDays.add(dayKey) : offDays.remove(dayKey);
    await store.setOffDay(dayKey, off);
    if (off) unawaited(alarms.syncDay(forDay(dayKey))); // প্ল্যান থাকলে অ্যালার্ম বন্ধ
    notifyListeners();
  }

  /// 🎲 উইজার্ড থেকে: সময় জেনারেট + প্ল্যান সেভ
  Future<void> generateAndSave(String dayKey, int count,
      Map<Segment, int> segCount, Map<Segment, int> segGap, AlarmPrefs alarm) {
    final slots = generateTimes(segCount, segGap);
    final plan = DayPlan(
      count: count,
      segCount: {for (final e in segCount.entries) e.key.index: e.value},
      segGap: {for (final e in segGap.entries) e.key.index: e.value},
      slots: slots,
      alarm: alarm,
      createdTs: DateTime.now().millisecondsSinceEpoch,
    );
    return savePlan(dayKey, plan);
  }

  // ---------- প্ল্যান বানানো/বদলানো ----------
  Future<void> savePlan(String dayKey, DayPlan plan) async {
    final b = forDay(dayKey);
    b.plan = plan;
    b.states = {};
    await _persist(b);
    unawaited(alarms.syncDay(b));
  }

  // ---------- টিক ----------
  Future<void> setPosted(String dayKey, int slotIdx, bool v) async {
    final b = forDay(dayKey);
    if (b.readOnly) return;
    final st = b.states.putIfAbsent(slotIdx, SlotState.new);
    st.posted = v;
    st.postTs = v ? DateTime.now().millisecondsSinceEpoch : 0;
    st.auto = false;
    if (v && st.scheduled) { st.scheduled = false; st.schedTs = 0; } // পোস্ট → সিডিউল মুছে
    await _persist(b);
    unawaited(alarms.cancelSlot(dayKey, slotIdx));
    _afterProgressChange(b);
  }

  /// 📅 সিডিউল — শুধু তখনই, যখন পাবলিশের কমপক্ষে ২০ মিনিট বাকি (FB নিয়ম)
  bool canSchedule(String dayKey, int minuteOfDay) {
    final t = slotDateTime(dayKey, minuteOfDay);
    final remain = t.difference(DateTime.now()).inMinutes;
    return remain >= kFbSchedLeadMin;
  }

  Future<void> setScheduled(String dayKey, int slotIdx, int minuteOfDay, bool v) async {
    final b = forDay(dayKey);
    if (b.readOnly) return;
    if (v && !canSchedule(dayKey, minuteOfDay)) return; // নিয়ম: ২০ মিনিটের কম হলে না
    final st = b.states.putIfAbsent(slotIdx, SlotState.new);
    if (st.posted) return;
    st.scheduled = v;
    st.schedTs = v ? DateTime.now().millisecondsSinceEpoch : 0;
    await _persist(b);
  }

  // ---------- ⏰ অটো-রূপান্তর: সিডিউল-টিক + সময় পার → পোস্ট হয়েছে ----------
  int autoConvert(String dayKey) {
    final b = forDay(dayKey);
    final plan = b.plan;
    if (plan == null || b.readOnly) return 0;
    final now = DateTime.now();
    var changed = 0;
    for (final s in plan.slots) {
      final st = b.states[s.index];
      if (st != null && st.scheduled && !st.posted && slotDateTime(dayKey, s.minuteOfDay).isBefore(now)) {
        st.scheduled = false;
        st.posted = true;
        st.auto = true;
        st.postTs = slotDateTime(dayKey, s.minuteOfDay).millisecondsSinceEpoch;
        changed++;
      }
    }
    if (changed > 0) {
      _persist(b);
      _afterProgressChange(b);
      unawaited(alarms.syncDay(b)); // কনভার্ট হওয়া স্লটের অ্যালার্ম মুছো
    }
    return changed;
  }

  // ---------- ৩০ সেকেন্ডের হার্টবিট ----------
  void tick() {
    autoConvert(todayKey);
    notifyListeners();
  }

  // ---------- হিসাব (দিন-শেষ স্ট্যাটস) ----------
  Future<void> saveStats(String dayKey, DayStats s) async {
    final b = forDay(dayKey);
    if (b.readOnly) return;
    s.ts = DateTime.now().millisecondsSinceEpoch;
    b.stats = s;
    await _persist(b);
    unawaited(alarms.syncDay(b)); // 📊 ১১:৫০-নোটিফ এখান আর লাগবে না
  }

  // ---------- স্ট্রিক/ব্যাজ (সাজেশন 🔒 সব গৃহীত) ----------
  void _afterProgressChange(DayBundle b) {
    final plan = b.plan;
    if (plan == null) return;
    if (b.postedCount >= plan.count && plan.count > 0 && b.dateKey == todayKey) {
      streak += 1;
      store.streak = streak;
      store.awardBadge('day_complete_$streak');
      notifyListeners();
    }
  }

  // ---------- সিঙ্ক ----------
  Future<void> _persist(DayBundle b) async {
    b.updatedTs = DateTime.now().millisecondsSinceEpoch;
    await store.saveDay(b);
    await store.enqueue(b.dateKey);
    notifyListeners();
    unawaited(_push(b.dateKey));
  }

  Future<void> _push(String dayKey) async {
    try {
      final res = await api.nsave(store.cid, forDay(dayKey));
      if (res['day'] is Map) {
        final cloud = DayBundle.fromJson(Map<String, dynamic>.from(res['day'] as Map));
        if (cloud.updatedTs > forDay(dayKey).updatedTs) {
          _days[dayKey] = cloud;
          await store.saveDay(cloud);
        }
      }
      await store.dequeue(dayKey);
      online = true;
      lastSync = DateTime.now();
      notifyListeners();
    } catch (_) {
      online = false;
      notifyListeners(); // outbox-এ জমে থাকবে, নেট ফিরলে syncToday
    }
  }

  Future<void> syncToday() => _push(todayKey);

  AlarmPrefs get alarmPrefs => store.alarmPrefs();
  Future<void> saveAlarmPrefs(AlarmPrefs a) => store.saveAlarmPrefs(a);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
