import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:projectstor/screens/permission_service.dart';
import 'package:sqflite/sqflite.dart';

import '../dashboard_screen.dart';
import '../database_helper.dart';

class LoginScreen extends StatefulWidget {
  final int? userId; // جعله اختياري مؤقتاً

  const LoginScreen({super.key, this.userId});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PermissionService _permissionService = PermissionService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // دالة تشفير كلمة المرور (نفسها في database_helper.dart)
  String _hashPassword(String password) {
    var bytes = utf8.encode(password + 'salt_12345');
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await _dbHelper.database;

      // البحث عن المستخدم بالاسم فقط
      final users = await db.query(
        'users',
        where: 'username = ? AND is_active = 1',
        whereArgs: [username],
        limit: 1,
      );

      if (users.isEmpty) {
        _showError('اسم المستخدم أو كلمة المرور غير صحيحة');
        return;
      }

      final user = users.first;
      final storedPassword = user['password'] as String;

      // تشفير كلمة المرور المدخلة والمقارنة مع المخزنة
      final hashedPassword = _hashPassword(password);

      if (hashedPassword != storedPassword) {
        _showError('اسم المستخدم أو كلمة المرور غير صحيحة');
        return;
      }

      // تسجيل الدخول ناجح
      _permissionService.setUserPermissions(user['role'] as String);

      // تحديث آخر وقت دخول
      await db.update(
        'users',
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [user['id']],
      );

      // تسجيل محاولة الدخول الناجحة
      await _logLoginAttempt(db, user['id'] as int, true);

      // الانتقال إلى الشاشة الرئيسية
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            username: user['name'] as String,
            role: user['role'] as String,

          ),
        ),
      );

    } catch (e) {
      _showError('حدث خطأ أثناء تسجيل الدخول');
      print('Login error: $e');

      // تسجيل خطأ النظام
      await _logSystemError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logLoginAttempt(Database db, int userId, bool success) async {
    try {
      await db.insert('audit_log', {
        'user_id': userId,
        'action': 'login',
        'details': json.encode({
          'success': success,
          'timestamp': DateTime.now().toIso8601String(),
          'ip_address': 'local',
        }),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed to log login attempt: $e');
    }
  }

  Future<void> _logSystemError(String error) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('audit_log', {
        'action': 'system_error',
        'details': json.encode({
          'error': error,
          'screen': 'LoginScreen',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed to log system error: $e');
    }
  }

  Future<void> _resetAdminPassword() async {
    if (!kDebugMode) return;

    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final hashedPassword = _hashPassword('admin123');

      final result = await db.update(
        'users',
        {'password': hashedPassword},
        where: 'username = ?',
        whereArgs: ['admin'],
      );

      if (result > 0) {
        _showSuccess('تم إعادة تعيين كلمة مرور المدير إلى admin123');
      } else {
        _showError('لم يتم العثور على مستخدم المدير');
      }
    } catch (e) {
      _showError('خطأ في إعادة التعيين: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // شعار التطبيق
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              SizedBox(height: 30),

              // عنوان التطبيق
              Text(
                'نظام إدارة المخزون',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'سجل الدخول إلى حسابك',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 40),

              // حقل اسم المستخدم
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              SizedBox(height: 20),

              // حقل كلمة المرور
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock, color: Colors.deepPurple),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.deepPurple,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onFieldSubmitted: (_) => _login(),
              ),
              SizedBox(height: 10),

              // نسيت كلمة المرور (إن وجدت)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    _showError('الرجاء التواصل مع مدير النظام');
                  },
                  child: Text(
                    'نسيت كلمة المرور؟',
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ),
              SizedBox(height: 30),

              // زر تسجيل الدخول
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: Colors.deepPurple.withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // زر إصلاح كلمة المرور (للتطوير فقط)
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _resetAdminPassword,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'إصلاح كلمة مرور المدير (للتطوير فقط)',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),

              // معلومات إضافية
              SizedBox(height: 40),
              Divider(color: Colors.grey[300]),
              SizedBox(height: 20),
              Text(
                'نسخة النظام: 1.1.0',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 5),
              Text(
                '© 2024 نظام إدارة المخزون',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}