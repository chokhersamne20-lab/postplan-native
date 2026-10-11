import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

import 'api.dart';
import 'models.dart';

/// ⏰ অ্যালার্ম ইঞ্জিন
/// - প্রতি স্লটে লোকাল নোটিফিকেশন (অ্যাপ বন্ধ থাকলেও) — leadMin আগে
/// - নোটিফিকেশনের ভেতরেই "✓ পোস্ট হয়েছে" বাটন (ব্যাকগ্রাউন্ড হ্যান্ডলার)
/// - অ্যাপ খোলা থাকলে: বাংলা ভয়েস + ফ্ল্যাশ + ভাইব্রেশন লুপ
/// - রাত ১১:৫০ 📊 হিসাব-অ্যালার্ম
class AlarmEngine {
  AlarmEngine._();
  static final AlarmEngine i = AlarmEngine._();

  final _noti = FlutterLocalNotificationsPlugin();
  final _tts = FlutterTts();
  bool _inited = false;

  static const _chAlarm = 'post_alarm';
  static const _chStats = 'stats_alarm';

  /// নোটিফিকেশন ট্যাপ/বাটন → অ্যাপ খোলা থাকলে কোন স্ক্রিনে যাবে (main.dart সেট করে)
  void Function(String payload)? onRoute;

  bool get canExact => _canExact;
  bool _canExact = false;

  int _dayId(String dayKey) =>
      (int.tryParse(dayKey.replaceAll('-', '')) ?? 0) % 100000;
  int slotNotiId(String dayKey, int idx) => _dayId(dayKey) * 1000 + idx;
  int statsNotiId(String dayKey) => _dayId(dayKey) * 1000 + 900;

  Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    // ঢাকা ফিক্সড; পরে ডিভাইস-টাইমজোন ডিটেক্ট করা যাবে
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    await _noti.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _fgTap,
      onDidReceiveBackgroundNotificationResponse: _bgTap,
    );

    final android = _noti.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _chAlarm, 'পোস্ট অ্যালার্ম',
      description: 'পোস্টের সময় ঘোষণা (জোরালো, স্ক্রিন-জাগানো)',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _chStats, 'হিসাব অ্যালার্ম',
      description: 'রাত ১১:৫০ — দিনের ডেটা রিসেটের আগে হিসাব জমা',
      importance: Importance.max,
      playSound: true,
    ));

    await _tts.setLanguage('bn-BD');
    await _tts.setSpeechRate(0.45);
    _inited = true;
  }

  // ---------- অনুমতি ----------
  Future<String> ensurePermissions() async {
    final android = _noti.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notif = await android?.requestNotificationsPermission() ?? true;
    _canExact = await android?.canScheduleExactNotifications() ?? false;
    if (!_canExact) {
      _canExact = await android?.requestExactAlarmsPermission() ?? false;
    }
    if (!notif) return '⚠️ নোটিফিকেশন অনুমতি পাওয়া যায়নি — অ্যালার্ম দেখাবে না';
    if (!_canExact) {
      return '⚠️ "Alarms & reminders" অনুমতি নেই — অ্যালার্ম কয়েক মিনিট আগে-পিছে হতে পারে (সেটিংসে চালু করতে পারেন)';
    }
    return '✅ অ্যালার্ম সম্পূর্ণ প্রস্তুত';
  }

  // ---------- সময়সূচি ----------
  Future<void> syncDay(DayBundle b) async {
    if (!_inited) return;
    // আগের আইডি মুছো (০..১৪৯ স্লট + স্ট্যাটস)
    for (var i = 0; i < 150; i++) {
      await _noti.cancel(slotNotiId(b.dateKey, i));
    }
    await _noti.cancel(statsNotiId(b.dateKey));

    final plan = b.plan;
    if (plan == null || b.readOnly) return;
    final prefs = plan.alarm;
    final now = DateTime.now();

    // স্লট অ্যালার্ম
    if (prefs.master) {
      for (final s in plan.slots) {
        final st = b.states[s.index];
        if (st != null && st.posted) continue;
        final at = slotDateTime(b.dateKey, s.minuteOfDay)
            .subtract(Duration(minutes: prefs.leadMin));
        if (at.isBefore(now)) continue;
        await _zoned(
          slotNotiId(b.dateKey, s.index),
          '⏰ পোস্ট ${s.index + 1} — ${prefs.leadMin} মিনিট বাকি',
          'সময় ${'' /*সেকুন্ড বাদে */}— এখনই প্রস্তুত হোন। ✓ চেপে টিক দিন',
          at,
          _chAlarm,
          payload: 'alarm|${b.dateKey}|${s.index}|${s.minuteOfDay}',
          action: true,
        );
      }
    }

    // 📊 রাত ১১:৫০ হিসাব-অ্যালার্ম
    if (prefs.statsAlarm && b.stats.ts == 0) {
      final d = slotDateTime(b.dateKey, kStatsAlarmMinOfDay);
      if (d.isAfter(now)) {
        await _zoned(statsNotiId(b.dateKey), '📊 হিসাব জমা দিন!',
            'রাত ১২টায় ফেসবুক ডেটা রিসেট — আজকের ভিউ/এনগেজমেন্ট/ইনকাম লিখে রাখুন',
            d, _chStats,
            payload: 'stats|${b.dateKey}');
      }
    }
  }

  Future<void> _zoned(int id, String title, String body, DateTime at, String channel,
      {required String payload, bool action = false}) async {
    final androidDetails = AndroidNotificationDetails(
      channel, channel == _chAlarm ? 'পোস্ট অ্যালার্ম' : 'হিসাব অ্যালার্ম',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: channel == _chAlarm,
      ongoing: action, // টিক না দিলে সরানো যাবে না
      autoCancel: !action,
      vibrationPattern: Int64List.fromList(const [0, 600, 300, 600]),
      actions: action
          ? const [AndroidNotificationAction('tick', '✓ পোস্ট হয়েছে', showsUserInterface: false)]
          : null,
    );
    await _noti.zonedSchedule(
      id, title, body,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: _canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelSlot(String dayKey, int idx) async {
    await _noti.cancel(slotNotiId(dayKey, idx));
    stopRing();
  }

  /// অ্যাপ বন্ধ থেকে নোটিফিকেশনে খোলা হলে — পেলোড (একবার)
  Future<String?> launchPayload() async {
    final d = await _noti.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) {
      return d!.notificationResponse?.payload;
    }
    return null;
  }

  // ---------- ট্যাপ/বাটন হ্যান্ডলার ----------
  void _fgTap(NotificationResponse r) {
    final p = r.payload;
    if (p == null) return;
    if (r.actionId == 'tick') {
      unawaited(_markTick(p, foreground: true));
    } else {
      onRoute?.call(p);
    }
  }

  // ---------- ফোরগ্রাউন্ড রিং (ভয়েস+ফ্ল্যাশ+ভাইব্রেশন লুপ) ----------
  Timer? _speakT, _flashT, _vibeT, _stopT;
  bool _flashOn = false;
  bool _ringing = false;
  bool get ringing => _ringing;

  Future<void> startRing(String postLabel, AlarmPrefs prefs) async {
    if (_ringing) return;
    _ringing = true;

    if (prefs.voice) {
      await speak('পোস্ট নম্বর $postLabel, এই সময় হয়েছে — এখনই পোস্ট করুন');
      _speakT = Timer.periodic(const Duration(seconds: 30),
          (_) => speak('পোস্ট নম্বর $postLabel, এই সময় হয়েছে — এখনই পোস্ট করুন'));
    }
    if (prefs.flash) {
      _flashT = Timer.periodic(const Duration(milliseconds: 700), (_) async {
        try {
          _flashOn ? await TorchLight.disableTorch() : await TorchLight.enableTorch();
          _flashOn = !_flashOn;
        } catch (_) {}
      });
    }
    if (prefs.vibrate) {
      _vibeT = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(pattern: [0, 500, 300, 500]);
          }
        } catch (_) {}
      });
    }
    // কতক্ষণ বাজবে
    if (prefs.ring == RingMode.min1 || prefs.ring == RingMode.min3) {
      _stopT = Timer(
          prefs.ring == RingMode.min1 ? const Duration(minutes: 1) : const Duration(minutes: 3),
          stopRing);
    }
  }

  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void stopRing() {
    _ringing = false;
    _speakT?.cancel();
    _vibeT?.cancel();
    _stopT?.cancel();
    _flashT?.cancel();
    if (_flashOn) {
      TorchLight.disableTorch().catchError((_) {});
      _flashOn = false;
    }
    _tts.stop();
  }
}

// ---------- ব্যাকগ্রাউন্ড ট্যাপ (অ্যাপ বন্ধ থাকলে "✓ পোস্ট হয়েছে") ----------
@pragma('vm:entry-point')
void _bgTap(NotificationResponse r) {
  if (r.actionId != 'tick') return;
  _markTick(r.payload ?? '', foreground: false);
}

Future<void> _markTick(String payload, {required bool foreground}) async {
  final parts = payload.split('|');
  if (parts.length != 4 || parts[0] != 'alarm') return;
  final store = LocalStore();
  await store.init();
  final b = store.loadDay(parts[1]);
  if (b == null || b.plan == null) return;
  final idx = int.tryParse(parts[2]);
  if (idx == null) return;
  final st = b.states.putIfAbsent(idx, SlotState.new);
  if (st.posted) return;
  st.posted = true;
  st.postTs = DateTime.now().millisecondsSinceEpoch;
  st.auto = false;
  st.scheduled = false;
  b.updatedTs = st.postTs;
  await store.saveDay(b);
  await store.enqueue(b.dateKey);
  // নেট থাকলে সাথে সাথে পুশ (না থাকলে আউটবক্সে থাকবে)
  try {
    await ApiClient().nsave(store.cid, b);
    await store.dequeue(b.dateKey);
  } catch (_) {}
  // নোটিফিকেশন বন্ধ
  final noti = FlutterLocalNotificationsPlugin();
  await noti.cancel((int.tryParse(parts[1].replaceAll('-', '')) ?? 0) % 100000 * 1000 + idx);
}
