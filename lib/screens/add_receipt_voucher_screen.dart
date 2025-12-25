import 'package:flutter/material.dart';

import '../database_helper.dart';

class AddReceiptVoucherScreen extends StatefulWidget {
  @override
  _AddReceiptVoucherScreenState createState() => _AddReceiptVoucherScreenState();
}

class _AddReceiptVoucherScreenState extends State<AddReceiptVoucherScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _saleInvoices = [];

  int? _selectedCustomerId;
  int? _selectedInvoiceId;
  double _amount = 0;
  String _paymentMethod = 'cash';
  String _notes = '';
  DateTime _paymentDate = DateTime.now();

  final Map<String, String> _paymentMethods = {
    'cash': 'نقدي',
    'transfer': 'تحويل',
    'check': 'شيك',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final customers = await _dbHelper.getCustomers();
      setState(() {
        _customers = customers;
      });
    } catch (e) {
      _showError('فشل في تحميل البيانات: $e');
    }
  }

  Future<void> _loadCustomerInvoices() async {
    if (_selectedCustomerId == null) return;

    try {
      final db = await _dbHelper.database;
      final invoices = await db.rawQuery('''
        SELECT id, invoice_number, total_amount, paid_amount, 
               (total_amount - paid_amount) as remaining_amount
        FROM sale_invoices 
        WHERE customer_id = ? AND status = 'approved'
          AND (total_amount - paid_amount) > 0
        ORDER BY invoice_date DESC
      ''', [_selectedCustomerId]);

      setState(() {
        _saleInvoices = invoices;
      });
    } catch (e) {
      _showError('فشل في تحميل فواتير العميل: $e');
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _paymentDate) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  void _setAmountFromInvoice() {
    if (_selectedInvoiceId != null) {
      final invoice = _saleInvoices.firstWhere(
            (inv) => inv['id'] == _selectedInvoiceId,
      );
      setState(() {
        _amount = invoice['remaining_amount']?.toDouble() ?? 0;
      });
    }
  }

  Future<void> _submitVoucher() async {
    if (!_formKey.currentState!.validate()) return;

    if (_amount <= 0) {
      _showError('يرجى إدخال مبلغ صحيح');
      return;
    }

    final voucher = {
      'customer_id': _selectedCustomerId,
      'amount': _amount,
      'payment_method': _paymentMethod,
      'payment_date': _paymentDate.toIso8601String(),
      'notes': _notes,
      'reference_type': _selectedInvoiceId != null ? 'invoice' : null,
      'reference_id': _selectedInvoiceId,
      'created_by': 1, // TODO: استخدام ID المستخدم الحالي
    };

    final result = await _dbHelper.createReceiptVoucher(voucher);

    if (result['success']) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء سند القبض بنجاح - رقم: ${result['voucher_number']}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showError(result['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة سند قبض'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _submitVoucher,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // معلومات السند الأساسية
              _buildBasicInfo(),
              SizedBox(height: 20),

              // معلومات الدفع
              _buildPaymentInfo(),
              SizedBox(height: 20),

              // زر الحفظ
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: _selectedCustomerId,
              decoration: InputDecoration(
                labelText: 'العميل',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.person),
              ),
              items: _customers.map((customer) {
                return DropdownMenuItem<int>(
                  value: customer['id'],
                  child: Text('${customer['name']} - رصيد: ${customer['balance']}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCustomerId = value;
                  _selectedInvoiceId = null;
                  _amount = 0;
                });
                _loadCustomerInvoices();
              },
              validator: (value) {
                if (value == null) return 'يرجى اختيار العميل';
                return null;
              },
            ),
            SizedBox(height: 12),
            if (_saleInvoices.isNotEmpty) ...[
              DropdownButtonFormField<int>(
                value: _selectedInvoiceId,
                decoration: InputDecoration(
                  labelText: 'فاتورة البيع (اختياري)',
                  border: OutlineInputBorder(),
                ),
                items: _saleInvoices.map((invoice) {
                  return DropdownMenuItem<int>(
                    value: invoice['id'],
                    child: Text('${invoice['invoice_number']} - المتبقي: ${invoice['remaining_amount']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedInvoiceId = value;
                  });
                  _setAmountFromInvoice();
                },
              ),
              SizedBox(height: 12),
            ],
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'تاريخ السند',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDate(_paymentDate)),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _amount = double.tryParse(value) ?? 0;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) return 'يرجى إدخال المبلغ';
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) return 'يرجى إدخال مبلغ صحيح';
                return null;
              },
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: InputDecoration(
                labelText: 'طريقة الدفع',
                border: OutlineInputBorder(),
              ),
              items: _paymentMethods.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => _notes = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      icon: Icon(Icons.save),
      label: Text('حفظ سند القبض'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _submitVoucher,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}