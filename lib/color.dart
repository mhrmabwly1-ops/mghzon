import 'package:flutter/material.dart';

class AppColors {
  // اللون الأساسي الرئيسي للتطبيق
  static const Color primary = Color(0xFF2E7D32); // أخضر داكن

  // ألوان ثابتة أخرى مستخدمة في الـ Stats Cards
  static const Color purple = Color(0xFF6C63FF);
  static const Color green = Color(0xFF4CAF50);
  static const Color orange = Color(0xFFFF9800);
  static const Color red = Color(0xFFF44336);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color deepPurple = Color(0xFF9C27B0);
  static const Color pink = Color(0xFFE91E63);
  static const Color brown = Color(0xFF795548);
  static const Color blueGrey = Color(0xFF607D8B);
  static const Color indigo = Color(0xFF3F51B5);

  // ألوان ديناميكية تعتمد على وضع السطوع (فاتح/داكن)
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF121212) // خلفية داكنة
        : Color(0xFFF5F5F5); // خلفية فاتحة
  }

  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF1E1E1E) // كارت داكن
        : Colors.white; // كارت فاتح
  }

  static Color textDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white // نص أبيض في الوضع الداكن
        : Color(0xFF333333); // نص داكن في الوضع الفاتح
  }

  static Color textGray(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Color(0xFFB0B0B0) // رمادي فاتح في الوضع الداكن
        : Color(0xFF666666); // رمادي في الوضع الفاتح
  }

  // ألوان إضافية يمكن استخدامها
  static Color scaffoldBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color divider(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  static Color primaryContainer(BuildContext context) {
    return Theme.of(context).colorScheme.primaryContainer;
  }

  static Color onPrimaryContainer(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimaryContainer;
  }
}
