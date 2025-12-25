import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../model/payment_voucher.dart';
import 'add_payment_voucher_screen.dart';

class PaymentVouchersScreen extends StatefulWidget {
  @override
  _PaymentVouchersScreenState createState() => _PaymentVouchersScreenState();
}

class _PaymentVouchersScreenState extends State<PaymentVouchersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<PaymentVoucher> _vouchers = [];
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
      final data = await _dbHelper.getPaymentVouchers(
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _vouchers = data.map((e) => PaymentVoucher.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل سندات الصرف: $e');
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
      final deleteResult = await _dbHelper.deletePaymentVoucher(voucherId);
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
        title: Text('سندات الصرف'),
        backgroundColor: Colors.orange,
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
            MaterialPageRoute(builder: (context) => AddPaymentVoucherScreen()),
          );
          if (result == true) {
            _loadVouchers();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // إحصائيات سريعة
          _buildStatsCard(),
          // فلترة التاريخ
          _buildDateFilterCard(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _vouchers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد سندات صرف',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'انقر على زر + لإنشاء سند صرف جديد',
                    style: TextStyle(color: Colors.grey),
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
                  return PaymentVoucherCard(
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
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  'إجمالي السندات',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '${_vouchers.length}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Text(
                  'إجمالي المبالغ',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '$_totalAmount ريال',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الفترة:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
              style: TextStyle(color: Colors.blue),
            ),
            IconButton(
              icon: Icon(Icons.filter_alt, color: Colors.blue),
              onPressed: _selectDateRange,
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDetails(PaymentVoucher voucher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.orange),
            SizedBox(width: 8),
            Text('سند صرف #${voucher.voucherNumber}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('المورد', voucher.supplierName ?? 'غير محدد'),
            _buildDetailRow('المبلغ', '${voucher.amount} ريال'),
            _buildDetailRow('طريقة الدفع', _getPaymentMethodText(voucher.paymentMethod)),
            _buildDetailRow('التاريخ', _formatDate(voucher.paymentDate)),
            if (voucher.notes != null) _buildDetailRow('ملاحظات', voucher.notes!),
            _buildDetailRow('تاريخ الإنشاء', _formatDate(voucher.createdAt)),
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
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14),
            ),
          ),
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

class PaymentVoucherCard extends StatelessWidget {
  final PaymentVoucher voucher;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PaymentVoucherCard({
    Key? key,
    required this.voucher,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(
            Icons.arrow_upward,
            color: Colors.white,
          ),
        ),
        title: Text(
          'سند صرف #${voucher.voucherNumber}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(voucher.supplierName ?? 'غير محدد'),
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
                style: TextStyle(color: Colors.white, fontSize: 10),
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