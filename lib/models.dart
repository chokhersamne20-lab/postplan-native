/// PostPlan Native — কোর ডেটা মডেল (v17)
library;

// ---------- কনস্ট্যান্ট (স্পেক-লকড 🔒) ----------
const int kMaxPostsPerDay = 120; // ভুল টাইপ আটকাতে
const int kFbSchedLeadMin = 20; // ফেসবুকে পাবলিশের কমপক্ষে ২০ মিনিট আগে শিডিউল
const int kStatsAlarmMinOfDay = 23 * 60 + 50; // রাত ১১:৫০ — হিসাব জমার বড় অ্যালার্ম
const int kDayStartMin = 7 * 60; // সকাল ৭টা
const int kDayEndMin = 27 * 60; // রাত ৩টা (= পরদিন ০৩:০০)

// ---------- দিনের ৩ ভাগ ----------
enum Segment { morningHome, office, nightHome }

class SegmentDef {
  final Segment seg;
  final String label;
  final String emoji;
  final int startMin, endMin;
  const SegmentDef(this.seg, this.label, this.emoji, this.startMin, this.endMin);
}

const List<SegmentDef> kSegments = [
  SegmentDef(Segment.morningHome, 'বাসা (সকাল)', '🏠', 7 * 60, 17 * 60),
  SegmentDef(Segment.office, 'অফিস', '🏢', 17 * 60, 24 * 60),
  SegmentDef(Segment.nightHome, 'বাসা (রাত)', '🌙', 24 * 60, 27 * 60),
];

Segment segmentOf(int minuteOfDay) {
  for (final s in kSegments) {
    if (minuteOfDay >= s.startMin && minuteOfDay < s.endMin) return s.seg;
  }
  return Segment.nightHome;
}

// ---------- সময়ের মান (ভালো/খারাপ বার্তা) ----------
enum TimeQuality { best, great, good, ok, bad }

TimeQuality qualityOf(int minuteOfDay) {
  if (minuteOfDay >= 600 && minuteOfDay < 660) return TimeQuality.best; // সকাল ১০–১১
  if (minuteOfDay >= 1200 && minuteOfDay < 1260) return TimeQuality.great; // রাত ৮–৯
  if (minuteOfDay >= 420 && minuteOfDay < 540) return TimeQuality.good; // ৭–৯টা পরীক্ষামূলক
  if (minuteOfDay >= 1440) return TimeQuality.bad; // রাত ১২টা–৩টা (ফাঁকা)
  return TimeQuality.ok;
}

String qualityLabel(TimeQuality q) => switch (q) {
      TimeQuality.best => '★ সেরা সময়',
      TimeQuality.great => '★ দ্বিতীয় সেরা',
      TimeQuality.good => 'ভালো সময় (পরীক্ষামূলক)',
      TimeQuality.ok => 'সাধারণ সময়',
      TimeQuality.bad => '⚠ ফাঁকা সময় — ভিউ কম',
    };

// ---------- স্লট (একটা পোস্ট বক্স) ----------
class SlotItem {
  final int index;
  final int minuteOfDay; // ৪২০..১৬১৯ (৭টা AM..ভোর ২:৫৯)
  SlotItem(this.index, this.minuteOfDay);
  TimeQuality get quality => qualityOf(minuteOfDay);
  Segment get segment => segmentOf(minuteOfDay);

  Map<String, dynamic> toJson() => {'i': index, 'm': minuteOfDay};
  static SlotItem fromJson(Map<String, dynamic> j) =>
      SlotItem(j['i'] as int, j['m'] as int);
}

class SlotState {
  bool scheduled; // 📅 সিডিউল টিক
  int schedTs;
  bool posted; // ✓ পোস্ট হয়েছে
  int postTs;
  bool auto; // ⏰ সময় পার → অটো-রূপান্তর
  SlotState({this.scheduled = false, this.schedTs = 0, this.posted = false, this.postTs = 0, this.auto = false});

  Map<String, dynamic> toJson() =>
      {'s': scheduled ? 1 : 0, 'st': schedTs, 'p': posted ? 1 : 0, 'pt': postTs, 'a': auto ? 1 : 0};
  static SlotState fromJson(Map<String, dynamic> j) => SlotState(
        scheduled: j['s'] == 1,
        schedTs: (j['st'] ?? 0) as int,
        posted: j['p'] == 1,
        postTs: (j['pt'] ?? 0) as int,
        auto: j['a'] == 1,
      );
}

// ---------- দিনের তারিখ-কী ----------
/// প্ল্যান-দিন: সকাল ৭টা → রাত ৩টা। ভোর ৩টা AM-এর আগে = গতকালের দিন।
String planDayKeyOf(DateTime now) {
  final d = now.hour < 3 ? now.subtract(const Duration(days: 1)) : now;
  String two(int x) => x.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// dayKey-এর কোনো মিনিট-অব-দে-এর আসল DateTime (১৪৪০+ = পরের ক্যালেন্ডার দিন)
DateTime slotDateTime(String dayKey, int minuteOfDay) {
  final p = dayKey.split('-').map(int.parse).toList();
  final base = DateTime(p[0], p[1], p[2]);
  return base.add(Duration(minutes: minuteOfDay));
}

// ---------- অ্যালার্ম পছন্দ ----------
enum RingMode { untilTick, min1, min3 }

class AlarmPrefs {
  bool master;
  int leadMin; // কত মিনিট আগে
  RingMode ring; // কতক্ষণ বাজবে
  bool flash, vibrate, voice, statsAlarm;
  AlarmPrefs({
    this.master = true,
    this.leadMin = 1,
    this.ring = RingMode.untilTick,
    this.flash = true,
    this.vibrate = true,
    this.voice = true,
    this.statsAlarm = true,
  });

  AlarmPrefs copy() => AlarmPrefs(
      master: master, leadMin: leadMin, ring: ring,
      flash: flash, vibrate: vibrate, voice: voice, statsAlarm: statsAlarm);

  Map<String, dynamic> toJson() => {
        'on': master, 'lead': leadMin, 'ring': ring.index,
        'fl': flash, 'vb': vibrate, 'vc': voice, 'sa': statsAlarm,
      };
  static AlarmPrefs fromJson(Map<String, dynamic> j) => AlarmPrefs(
        master: (j['on'] ?? true) as bool,
        leadMin: (j['lead'] ?? 1) as int,
        ring: RingMode.values[(j['ring'] ?? 0) as int],
        flash: (j['fl'] ?? true) as bool,
        vibrate: (j['vb'] ?? true) as bool,
        voice: (j['vc'] ?? true) as bool,
        statsAlarm: (j['sa'] ?? true) as bool,
      );
}

// ---------- দিনের প্ল্যান ----------
class DayPlan {
  final int count; // মোট পোস্ট (১–১২০)
  final Map<int, int> segCount; // Segment.index → কতটা
  final Map<int, int> segGap; // Segment.index → মিনিট গ্যাপ
  final List<SlotItem> slots; // জেনারেটেড সময়গুলো
  final AlarmPrefs alarm;
  final int createdTs;
  DayPlan({required this.count, required this.segCount, required this.segGap,
      required this.slots, required this.alarm, required this.createdTs});

  Map<String, dynamic> toJson() => {
        'c': count,
        'sc': segCount.map((k, v) => MapEntry('$k', v)),
        'sg': segGap.map((k, v) => MapEntry('$k', v)),
        'sl': slots.map((s) => s.toJson()).toList(),
        'al': alarm.toJson(),
        'ct': createdTs,
      };
  static DayPlan fromJson(Map<String, dynamic> j) => DayPlan(
        count: (j['c'] ?? 0) as int,
        segCount: (j['sc'] as Map).map((k, v) => MapEntry(int.parse('$k'), (v as num).toInt())),
        segGap: (j['sg'] as Map).map((k, v) => MapEntry(int.parse('$k'), (v as num).toInt())),
        slots: (j['sl'] as List).map((e) => SlotItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        alarm: AlarmPrefs.fromJson(Map<String, dynamic>.from(j['al'] as Map)),
        createdTs: (j['ct'] ?? 0) as int,
      );
}

// ---------- দিন-শেষ হিসাব ----------
class DayStats {
  int views, engage, followers;
  double income;
  int ts;
  DayStats({this.views = 0, this.engage = 0, this.followers = 0, this.income = 0, this.ts = 0});
  Map<String, dynamic> toJson() =>
      {'v': views, 'e': engage, 'f': followers, 'i': income, 't': ts};
  static DayStats fromJson(Map<String, dynamic> j) => DayStats(
        views: (j['v'] ?? 0) as int,
        engage: (j['e'] ?? 0) as int,
        followers: (j['f'] ?? 0) as int,
        income: ((j['i'] ?? 0) as num).toDouble(),
        ts: (j['t'] ?? 0) as int,
      );
}

// ---------- এক দিনের পুরো বান্ডিল (Sheets-এ এক ব্লব হিসেবে সেভ) ----------
class DayBundle {
  final String dateKey;
  DayPlan? plan;
  Map<int, SlotState> states; // slotIndex → টিক-অবস্থা
  DayStats stats;
  int updatedTs;
  bool readOnly; // অতীতের দিন → শুধু দেখা
  DayBundle(this.dateKey,
      {this.plan, Map<int, SlotState>? states, DayStats? stats,
      this.updatedTs = 0, this.readOnly = false})
      : states = states ?? {},
        stats = stats ?? DayStats();

  int get postedCount => states.values.where((s) => s.posted).length;

  Map<String, dynamic> toJson() => {
        'd': dateKey,
        'plan': plan?.toJson(),
        'st': states.map((k, v) => MapEntry('$k', v.toJson())),
        'stat': stats.toJson(),
        'u': updatedTs,
      };
  static DayBundle fromJson(Map<String, dynamic> j, {bool readOnly = false}) => DayBundle(
        (j['d'] ?? '') as String,
        plan: j['plan'] == null ? null : DayPlan.fromJson(Map<String, dynamic>.from(j['plan'] as Map)),
        states: ((j['st'] ?? {}) as Map).map((k, v) =>
            MapEntry(int.parse('$k'), SlotState.fromJson(Map<String, dynamic>.from(v as Map)))),
        stats: j['stat'] == null ? null : DayStats.fromJson(Map<String, dynamic>.from(j['stat'] as Map)),
        updatedTs: (j['u'] ?? 0) as int,
        readOnly: readOnly,
      );
}
