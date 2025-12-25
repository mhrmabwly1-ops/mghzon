import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../widgets/status_badge.dart';
import 'add_purchase_returnScreen.dart';


class PurchaseReturnsScreen extends StatefulWidget {
  @override
  _PurchaseReturnsScreenState createState() => _PurchaseReturnsScreenState();
}

class _PurchaseReturnsScreenState extends State<PurchaseReturnsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _returns = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dbHelper.getPurchaseReturns(
          status: _filterStatus == 'all' ? null : _filterStatus
      );

      setState(() {
        _returns = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل المرتجعات: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _deleteReturn(int returnId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا المرتجع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      final deleteResult = await _dbHelper.deletePurchaseReturn(returnId);
      if (deleteResult['success']) {
        _loadReturns();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleteResult['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError(deleteResult['error']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مرتجعات الشراء'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReturns,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadReturns();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('جميع المرتجعات')),
              PopupMenuItem(value: 'draft', child: Text('مسودة')),
              PopupMenuItem(value: 'approved', child: Text('معتمدة')),
              PopupMenuItem(value: 'cancelled', child: Text('ملغاة')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPurchaseReturnScreen()),
          );
          if (result == true) {
            _loadReturns();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _returns.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد مرتجعات شراء',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadReturns,
        child: ListView.builder(
          itemCount: _returns.length,
          padding: EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final returnData = _returns[index];
            return PurchaseReturnCard(
              returnData: returnData,
              onTap: () => _showReturnDetails(returnData),
              onDelete: () => _deleteReturn(returnData['id']),
            );
          },
        ),
      ),
    );
  }

  void _showReturnDetails(Map<String, dynamic> returnData) {
    // يمكن إضافة تفاصيل المرتجع هنا
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('مرتجع شراء #${returnData['return_number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المورد: ${returnData['supplier_name']}'),
            Text('المخزن: ${returnData['warehouse_name']}'),
            Text('المبلغ: ${returnData['total_amount']} ريال'),
            Text('الحالة: ${_getStatusText(returnData['status'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved': return 'معتمدة';
      case 'cancelled': return 'ملغاة';
      default: return 'مسودة';
    }
  }
}

class PurchaseReturnCard extends StatelessWidget {
  final Map<String, dynamic> returnData;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PurchaseReturnCard({
    Key? key,
    required this.returnData,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(returnData['status']),
          child: Icon(
            Icons.assignment_return,
            color: Colors.white,
          ),
        ),
        title: Text(
          'مرتجع #${returnData['return_number']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فاتورة الشراء: ${returnData['purchase_invoice_number']}'),
            Text('المورد: ${returnData['supplier_name']}'),
            Text('المبلغ: ${returnData['total_amount']} ريال'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: returnData['status']),
            if (returnData['status'] == 'draft') ...[
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
                iconSize: 20,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }
}