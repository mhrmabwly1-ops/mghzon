import 'package:flutter/material.dart';
import 'package:projectstor/screens/permission_service.dart';

import '../database_helper.dart';

class UsersManagementScreen extends StatefulWidget {
  @override
  _UsersManagementScreenState createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PermissionService _permissionService = PermissionService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!_permissionService.canManageUsers) {
      _showError('غير مصرح لك بالوصول إلى هذه الصفحة');
      Navigator.pop(context);
      return;
    }

    try {
      setState(() => _isLoading = true);
      final db = await _dbHelper.database;
      final users = await db.query('users', orderBy: 'created_at DESC');
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل المستخدمين: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _toggleUserStatus(int userId, bool currentStatus) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد'),
        content: Text(currentStatus ? 'هل تريد تعطيل هذا المستخدم؟' : 'هل تريد تفعيل هذا المستخدم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('تأكيد')),
        ],
      ),
    );

    if (result == true) {
      try {
        await _dbHelper.database.then((db) => db.update(
          'users',
          {'is_active': currentStatus ? 0 : 1},
          where: 'id = ?',
          whereArgs: [userId],
        ));
        _loadUsers();
      } catch (e) {
        _showError('فشل في تحديث حالة المستخدم: $e');
      }
    }
  }

  Future<void> _changeUserRole(int userId, String currentRole) async {
    final newRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغيير دور المستخدم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleOption('مدير النظام', 'admin', currentRole),
            _buildRoleOption('مدير', 'manager', currentRole),
            _buildRoleOption('أمين مخزن', 'warehouse', currentRole),
            _buildRoleOption('كاشير', 'cashier', currentRole),
            _buildRoleOption('مشرف', 'viewer', currentRole),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        ],
      ),
    );

    if (newRole != null) {
      try {
        await _dbHelper.database.then((db) => db.update(
          'users',
          {'role': newRole},
          where: 'id = ?',
          whereArgs: [userId],
        ));
        _loadUsers();
      } catch (e) {
        _showError('فشل في تغيير دور المستخدم: $e');
      }
    }
  }

  Widget _buildRoleOption(String title, String role, String currentRole) {
    return ListTile(
      leading: Radio<String>(
        value: role,
        groupValue: currentRole,
        onChanged: (value) => Navigator.pop(context, value),
      ),
      title: Text(title),
      onTap: () => Navigator.pop(context, role),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionService.canManageUsers) {
      return Scaffold(
        appBar: AppBar(title: Text('إدارة المستخدمين')),
        body: Center(child: Text('غير مصرح لك بالوصول إلى هذه الصفحة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة المستخدمين'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadUsers),
          IconButton(icon: Icon(Icons.add), onPressed: _addNewUser),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user['role']),
          child: Text(user['name'][0], style: TextStyle(color: Colors.white)),
        ),
        title: Text(user['name']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اسم المستخدم: ${user['username']}'),
            Text('الدور: ${_getRoleName(user['role'])}'),
            Text('الحالة: ${user['is_active'] == 1 ? 'مفعل' : 'معطل'}'),
            if (user['last_login'] != null)
              Text('آخر دخول: ${_formatDate(DateTime.parse(user['last_login']))}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _changeUserRole(user['id'], user['role']),
            ),
            IconButton(
              icon: Icon(
                user['is_active'] == 1 ? Icons.person_off : Icons.person,
                color: user['is_active'] == 1 ? Colors.orange : Colors.green,
              ),
              onPressed: () => _toggleUserStatus(user['id'], user['is_active'] == 1),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewUser() {
    showDialog(
      context: context,
      builder: (context) => AddUserDialog(onUserAdded: _loadUsers),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'manager': return Colors.orange;
      case 'warehouse': return Colors.blue;
      case 'cashier': return Colors.green;
      case 'viewer': return Colors.grey;
      default: return Colors.purple;
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin': return 'مدير النظام';
      case 'manager': return 'مدير';
      case 'warehouse': return 'أمين مخزن';
      case 'cashier': return 'كاشير';
      case 'viewer': return 'مشرف';
      default: return role;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class AddUserDialog extends StatefulWidget {
  final VoidCallback onUserAdded;

  const AddUserDialog({Key? key, required this.onUserAdded}) : super(key: key);

  @override
  _AddUserDialogState createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'cashier';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إضافة مستخدم جديد'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'الاسم الكامل'),
              validator: (value) => value!.isEmpty ? 'يرجى إدخال الاسم' : null,
            ),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'اسم المستخدم'),
              validator: (value) => value!.isEmpty ? 'يرجى إدخال اسم المستخدم' : null,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
              validator: (value) => value!.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(labelText: 'الدور'),
              items: [
                DropdownMenuItem(value: 'admin', child: Text('مدير النظام')),
                DropdownMenuItem(value: 'manager', child: Text('مدير')),
                DropdownMenuItem(value: 'warehouse', child: Text('أمين مخزن')),
                DropdownMenuItem(value: 'cashier', child: Text('كاشير')),
                DropdownMenuItem(value: 'viewer', child: Text('مشرف')),
              ],
              onChanged: (value) => setState(() => _selectedRole = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        ElevatedButton(
          onPressed: _addUser,
          child: Text('إضافة'),
        ),
      ],
    );
  }

  Future<void> _addUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final db = await DatabaseHelper().database;
        await db.insert('users', {
          'username': _usernameController.text,
          'password': _passwordController.text, // في الواقع يجب تشفيرها
          'name': _nameController.text,
          'role': _selectedRole,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
        widget.onUserAdded();
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في إضافة المستخدم: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}