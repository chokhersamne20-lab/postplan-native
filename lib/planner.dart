import 'dart:math';

import 'models.dart';

/// মোট পোস্ট ৩ ভাগে স্বয়ংক্রিয় বণ্টন-পরামর্শ (সময়-আয়তন অনুপাতে)
Map<Segment, int> suggestSplit(int total) {
  const w = {Segment.morningHome: .55, Segment.office: .35, Segment.nightHome: .10};
  final r = <Segment, int>{};
  var rem = total;
  for (var i = 0; i < kSegments.length; i++) {
    final s = kSegments[i].seg;
    final n = i == kSegments.length - 1 ? rem : (total * w[s]!).round();
    r[s] = n < 0 ? 0 : n;
    rem -= r[s]!;
  }
  return r;
}

int suggestGap(Segment s) => switch (s) {
      Segment.morningHome => 15,
      Segment.office => 20,
      Segment.nightHome => 30,
    };

List<SlotItem> generateTimes(Map<Segment, int> counts, Map<Segment, int> gaps, {int? seed}) {
  final rnd = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
  const rank = {
    TimeQuality.best: 4, TimeQuality.great: 3, TimeQuality.good: 2,
    TimeQuality.ok: 1, TimeQuality.bad: 0,
  };
  final slots = <SlotItem>[];
  var idx = 0;
  for (final def in kSegments) {
    var n = counts[def.seg] ?? 0;
    if (n <= 0) continue;
    final span = def.endMin - def.startMin - 2;
    // গ্যাপ অসম্ভব হলে সঙ্কুচিত করো (ঘেকে না ফেলাই নিশ্চিত)
    var gap = (gaps[def.seg] ?? suggestGap(def.seg)).clamp(1, span);
    final need = (n - 1) * gap;
    if (need > span && n > 1) gap = (span ~/ (n - 1)).clamp(1, span);
    final placed = <int>[];
    for (var k = 0; k < n; k++) {
      int? bestT;
      var bestR = -1;
      for (var a = 0; a < 300; a++) {
        final t = def.startMin + rnd.nextInt(span);
        var ok = true;
        for (final q in placed) {
          if ((t - q).abs() < gap) { ok = false; break; }
        }
        if (!ok) continue;
        final r = rank[qualityOf(t)]!;
        if (r > bestR) { bestR = r; bestT = t; if (r == 4) break; }
      }
      bestT ??= def.startMin + 1 + rnd.nextInt(5); // ফ্যালব্যাক — গ্যাপ ভাঙতেও সময় দাও
      placed.add(bestT);
      placed.sort();
    }
    for (final t in placed) {
      slots.add(SlotItem(idx++, t));
    }
  }
  return slots;
}
