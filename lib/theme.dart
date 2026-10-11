import 'package:flutter/material.dart';

/// Midnight Premium থিম — ডার্ক নেভি + সোনালি অ্যাকসেন্ট + গ্লাস কার্ড
class AppTheme {
  AppTheme._();

  // ---- রঙ ----
  static const Color bg = Color(0xFF0F172A); // গভীর নেভি
  static const Color bgSoft = Color(0xFF1E293B);
  static const Color glass = Color(0x14FFFFFF); // স্বচ্ছ সাদা (কার্ড)
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color gold = Color(0xFFF59E0B); // প্রাইম/সেরা সময়
  static const Color emerald = Color(0xFF10B981); // সম্পন্ন/ভালো
  static const Color red = Color(0xFFEF4444); // খারাপ/বাদ-পড়া
  static const Color sky = Color(0xFF38BDF8); // সেকেন্ডারি
  static const Color textHi = Color(0xFFF8FAFC);
  static const Color textMid = Color(0xFFCBD5E1);
  static const Color textDim = Color(0xFF94A3B8);

  static BoxDecoration glassCard({Color? tint, double radius = 18}) =>
      BoxDecoration(
        color: tint == null ? glass : tint.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tint == null ? glassBorder : tint.withValues(alpha: .35)),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      );

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    // বাংলা: Android-এর ডিফল্ট Bengali ফন্ট (Noto Sans Bengali) ব্যবহৃত হয়;
    // পরে বান্ডল ফন্ট অ্যাসেট যোগ করা যাবে।
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: bgSoft,
        primary: gold,
        secondary: sky,
        error: red,
        onSurface: textHi,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textHi),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textHi,
        displayColor: textHi,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF1A1206),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass,
        hintStyle: const TextStyle(color: textDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
      ),
    );
  }
}
