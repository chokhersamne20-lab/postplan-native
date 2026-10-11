import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

// ---------- ব্যাকএন্ড (ওয়েব অ্যাপের একই Apps Script — v17 ডে-ব্লব প্রোটোকল) ----------
// প্রোটোকল:
//   GET  $kApiBase?action=nget&cid=..&day=YYYY-MM-DD
//        → { ok:true, rev, day:DayBundleJson|null, serverVersion }
//   POST form: action=nsave & cid & day & data=<json> & localTs
//        → { ok:true, rev, day:DayBundleJson }   (সার্ভারে last-write-wins per day; <= দিনের updatedTs হলে ওইটাই ফেরত)
// সার্ভার-সাইড (code.gs v17) পরের ধাপে যোগ হবে; ওয়েব v16 রো-গুলো অক্ষত থাকবে।
const String kApiBase =
    'https://script.google.com/macros/s/AKfycbzH85nD_5ep9xt-WgEiwxC5_hbm9_-cUQO0A6VVGcEGCsAgOYIUGaNaWKL7nHlMjkQ/exec';
const Duration kTimeout = Duration(seconds: 12);

class ApiException implements Exception {
  final String msg;
  ApiException(this.msg);
  @override
  String toString() => msg;
}

class ApiClient {
  Future<Map<String, dynamic>> nget(String cid, String dayKey) async {
    final uri = Uri.parse('$kApiBase?action=nget&cid=$cid&day=$dayKey');
    final res = await http.get(uri).timeout(kTimeout);
    final j = jsonDecode(res.body);
    if (j is! Map || j['ok'] != true) {
      throw ApiException('সার্ভার ত্রুটি: ${j is Map ? j['error'] : res.statusCode}');
    }
    return Map<String, dynamic>.from(j);
  }

  Future<Map<String, dynamic>> nsave(String cid, DayBundle bundle) async {
    final res = await http
        .post(Uri.parse(kApiBase), body: {
          'action': 'nsave',
          'cid': cid,
          'day': bundle.dateKey,
          'localTs': '${bundle.updatedTs}',
          'data': jsonEncode(bundle.toJson()),
        })
        .timeout(kTimeout);
    final j = jsonDecode(res.body);
    if (j is! Map || j['ok'] != true) {
      throw ApiException('সার্ভার ত্রুটি: ${j is Map ? j['error'] : res.statusCode}');
    }
    return Map<String, dynamic>.from(j);
  }
}

// ---------- লোকাল স্টোর (অফলাইন-ফার্স্ট ক্যাশ + আউটবক্স) ----------
class LocalStore {
  static const _kCid = 'cid';
  static const _kOnboard = 'onboardingDone';
  static const _kAlarm = 'alarmPrefs';
  static const _kOutbox = 'outboxDays';
  static const _kOffDays = 'offDays';
  static const _kStreak = 'streak';
  static const _kBadges = 'badges';

  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _p.getString(_kCid) ?? _newCid();
  }

  String _newCid() {
    final c = 'a${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    _p.setString(_kCid, c);
    return c;
  }

  String get cid => _p.getString(_kCid)!;

  bool get onboardingDone => _p.getBool(_kOnboard) ?? false;
  Future<void> setOnboardingDone() => _p.setBool(_kOnboard, true);

  AlarmPrefs alarmPrefs() {
    final s = _p.getString(_kAlarm);
    if (s == null) return AlarmPrefs();
    try {
      return AlarmPrefs.fromJson(jsonDecode(s));
    } catch (_) {
      return AlarmPrefs();
    }
  }

  Future<void> saveAlarmPrefs(AlarmPrefs a) => _p.setString(_kAlarm, jsonEncode(a.toJson()));

  // দিনের ক্যাশ
  DayBundle? loadDay(String dayKey, {bool readOnly = false}) {
    final s = _p.getString('day_$dayKey');
    if (s == null) return null;
    try {
      return DayBundle.fromJson(jsonDecode(s), readOnly: readOnly);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDay(DayBundle b) => _p.setString('day_${b.dateKey}', jsonEncode(b.toJson()));

  // সিঙ্ক-আউটবক্স (অফলাইনে জমে থাকে)
  List<String> outbox() => _p.getStringList(_kOutbox) ?? [];
  Future<void> enqueue(String dayKey) async {
    final l = outbox();
    if (!l.contains(dayKey)) {
      l.add(dayKey);
      await _p.setStringList(_kOutbox, l);
    }
  }

  Future<void> dequeue(String dayKey) async {
    final l = outbox()..remove(dayKey);
    await _p.setStringList(_kOutbox, l);
  }

  // অফ-ডে (ছুটি মোড)
  Set<String> offDays() => (_p.getStringList(_kOffDays) ?? []).toSet();
  Future<void> setOffDay(String dayKey, bool off) async {
    var l = offDays();
    off ? l.add(dayKey) : l.remove(dayKey);
    await _p.setStringList(_kOffDays, l.toList());
  }

  // স্ট্রিক ও ব্যাজ
  int get streak => _p.getInt(_kStreak) ?? 0;
  set streak(int v) => _p.setInt(_kStreak, v);
  Set<String> badges() => (_p.getStringList(_kBadges) ?? []).toSet();
  Future<void> awardBadge(String id) async {
    var b = badges();
    b.add(id);
    await _p.setStringList(_kBadges, b.toList());
  }
}
