/// বাংলা সংখ্যা/তারিখ ফরম্যাট সাহায্যকারী
library;

const _bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

String bnDigits(Object v) {
  final s = v.toString();
  final b = StringBuffer();
  for (final ch in s.codeUnits) {
    final c = ch - 48; // '0'
    b.write(c >= 0 && c <= 9 ? _bn[c] : String.fromCharCode(ch));
  }
  return b.toString();
}

String two(int x) => x.toString().padLeft(2, '0');

/// বাংলা সংখ্যা টাইপ করলেও (০১২৩) ইংরেজিতে রূপান্তর — ফর্ম-ইনপুট পার্সের জন্য
String asciiDigits(String s) {
  final b = StringBuffer();
  for (final ch in s.codeUnits) {
    if (ch >= 0x09E6 && ch <= 0x09EF) {
      b.write(ch - 0x09E6);
    } else {
      b.writeCharCode(ch);
    }
  }
  return b.toString();
}

/// DateTime → 'YYYY-MM-DD' (ক্যালেন্ডার-নির্ভুল; ভোর ৩টার নিয়ম এখানে নয়)
String dateKeyOf(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// মিনিট-অব-ডে (৪২০..১৬১৯) → '১০:৩০ AM' (বাংলা সংখ্যায়)
String fmtMinOfDay(int m) {
  final h24 = (m ~/ 60) % 24;
  final mm = m % 60;
  final ampm = h24 < 12 ? 'AM' : 'PM';
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '${bnDigits('$h12:${two(mm)}')} $ampm';
}

String fmtClock(DateTime t) => bnDigits(
    '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${two(t.minute)}:${two(t.second)} ${t.hour < 12 ? 'AM' : 'PM'}');

const _wdFull = ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'];
const _wdShort = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
final _monthBn = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
];

String weekdayBn(DateTime d) => _wdFull[d.weekday - 1];
String weekdayShortBn(DateTime d) => _wdShort[d.weekday - 1];
String monthBn(int m) => _monthBn[m - 1];

/// 'শুক্রবার, ১১ অক্টোবর'
String fmtDateBn(DateTime d) => '${weekdayBn(d)}, ${bnDigits(d.day)} ${monthBn(d.month)}';

/// 'YYYY-MM-DD' → DateTime (আধা-রাত)
DateTime parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// X মিনিট/ঘণ্টা-সেকেন্ড → '১২ মিনিট ৪০ সেকেন্ড বাকি' ধাঁচের বাংলা
String fmtRemain(Duration d) {
  final neg = d.isNegative;
  final s = d.abs().inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String core;
  if (h > 0) {
    core = '${bnDigits(h)} ঘণ্টা ${bnDigits(m)} মিনিট';
  } else if (m > 0) {
    core = '${bnDigits(m)} মিনিট ${bnDigits(sec)} সেকেন্ড';
  } else {
    core = '${bnDigits(sec)} সেকেন্ড';
  }
  return neg ? '$core আগে পার হয়েছে' : '$core বাকি';
}
