import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../model/receipt_voucher.dart';
import 'add_receipt_voucher_screen.dart';

class ReceiptVouchersScreen extends StatefulWidget {
  @override
  _ReceiptVouchersScreenState createState() => _ReceiptVouchersScreenState();
}

class _ReceiptVouchersScreenState extends State<ReceiptVouchersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<ReceiptVoucher> _vouchers = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dbHelper.getReceiptVouchers(
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _vouchers = data.map((e) => ReceiptVoucher.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل سندات القبض: $e');
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

  Future<void> _deleteVoucher(int voucherId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا السند؟'),
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
      final deleteResult = await _dbHelper.deleteReceiptVoucher(voucherId);
      if (deleteResult['success']) {
        _loadVouchers();
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadVouchers();
    }
  }

  double get _totalAmount {
    return _vouchers.fold(0, (sum, voucher) => sum + voucher.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سندات القبض'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadVouchers,
          ),
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddReceiptVoucherScreen()),
          );
          if (result == true) {
            _loadVouchers();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // إحصائيات سريعة
          _buildStatsCard(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _vouchers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد سندات قبض',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadVouchers,
              child: ListView.builder(
                itemCount: _vouchers.length,
                padding: EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final voucher = _vouchers[index];
                  return ReceiptVoucherCard(
                    voucher: voucher,
                    onTap: () => _showVoucherDetails(voucher),
                    onDelete: () => _deleteVoucher(voucher.id!),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  'إجمالي السندات',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  '${_vouchers.length}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              children: [
                Text(
                  'إجمالي المبالغ',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  '$_totalAmount ريال',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDetails(ReceiptVoucher voucher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سند قبض #${voucher.voucherNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('العميل', voucher.customerName ?? 'غير محدد'),
            _buildDetailRow('المبلغ', '${voucher.amount} ريال'),
            _buildDetailRow('طريقة الدفع', _getPaymentMethodText(voucher.paymentMethod)),
            _buildDetailRow('التاريخ', _formatDate(voucher.paymentDate)),
            if (voucher.notes != null) _buildDetailRow('ملاحظات', voucher.notes!),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'cash': return 'نقدي';
      case 'transfer': return 'تحويل';
      case 'check': return 'شيك';
      default: return method;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class ReceiptVoucherCard extends StatelessWidget {
  final ReceiptVoucher voucher;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ReceiptVoucherCard({
    Key? key,
    required this.voucher,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(
            Icons.arrow_downward,
            color: Colors.white,
          ),
        ),
        title: Text(
          'سند قبض #${voucher.voucherNumber}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(voucher.customerName ?? 'غير محدد'),
            Text('المبلغ: ${voucher.amount} ريال'),
            Text('التاريخ: ${_formatDate(voucher.paymentDate)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                _getPaymentMethodText(voucher.paymentMethod),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: Colors.blue,
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              iconSize: 20,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'cash': return 'نقدي';
      case 'transfer': return 'تحويل';
      case 'check': return 'شيك';
      default: return method;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}