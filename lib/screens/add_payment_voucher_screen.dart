import 'package:flutter/material.dart';

import '../database_helper.dart';


class AddPaymentVoucherScreen extends StatefulWidget {
  @override
  _AddPaymentVoucherScreenState createState() => _AddPaymentVoucherScreenState();
}

class _AddPaymentVoucherScreenState extends State<AddPaymentVoucherScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _purchaseInvoices = [];

  int? _selectedSupplierId;
  int? _selectedInvoiceId;
  double _amount = 0;
  String _paymentMethod = 'cash';
  String _referenceType = 'expense';
  String _notes = '';
  DateTime _paymentDate = DateTime.now();

  final Map<String, String> _paymentMethods = {
    'cash': 'نقدي',
    'transfer': 'تحويل',
    'check': 'شيك',
  };

  final Map<String, String> _referenceTypes = {
    'invoice': 'فاتورة شراء',
    'expense': 'مصروفات',
    'salary': 'رواتب',
    'other': 'أخرى',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final suppliers = await _dbHelper.getSuppliers();
      setState(() {
        _suppliers = suppliers;
      });
    } catch (e) {
      _showError('فشل في تحميل البيانات: $e');
    }
  }

  Future<void> _loadSupplierInvoices() async {
    if (_selectedSupplierId == null) return;

    try {
      final db = await _dbHelper.database;
      final invoices = await db.rawQuery('''
        SELECT id, invoice_number, total_amount, paid_amount, 
               (total_amount - paid_amount) as remaining_amount
        FROM purchase_invoices 
        WHERE supplier_id = ? AND status = 'approved'
          AND (total_amount - paid_amount) > 0
        ORDER BY invoice_date DESC
      ''', [_selectedSupplierId]);

      setState(() {
        _purchaseInvoices = invoices;
      });
    } catch (e) {
      _showError('فشل في تحميل فواتير المورد: $e');
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
      final invoice = _purchaseInvoices.firstWhere(
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
      'supplier_id': _selectedSupplierId,
      'amount': _amount,
      'payment_method': _paymentMethod,
      'payment_date': _paymentDate.toIso8601String(),
      'notes': _notes,
      'reference_type': _referenceType,
      'reference_id': _selectedInvoiceId,
      'created_by': 1, // TODO: استخدام ID المستخدم الحالي
    };

    final result = await _dbHelper.createPaymentVoucher(voucher);

    if (result['success']) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء سند الصرف بنجاح - رقم: ${result['voucher_number']}'),
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
        title: Text('إضافة سند صرف'),
        backgroundColor: Colors.orange,
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

              // معلومات المرجع
              _buildReferenceInfo(),
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
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المعلومات الأساسية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedSupplierId,
              decoration: InputDecoration(
                labelText: 'المورد',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              items: _suppliers.map((supplier) {
                return DropdownMenuItem<int>(
                  value: supplier['id'],
                  child: Text('${supplier['name']} - رصيد: ${supplier['balance']}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSupplierId = value;
                  _selectedInvoiceId = null;
                  _amount = 0;
                });
                _loadSupplierInvoices();
              },
              validator: (value) {
                if (value == null) return 'يرجى اختيار المورد';
                return null;
              },
            ),
            SizedBox(height: 12),
            if (_purchaseInvoices.isNotEmpty) ...[
              DropdownButtonFormField<int>(
                value: _selectedInvoiceId,
                decoration: InputDecoration(
                  labelText: 'فاتورة الشراء (اختياري)',
                  border: OutlineInputBorder(),
                ),
                items: _purchaseInvoices.map((invoice) {
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
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDate(_paymentDate)),
                    Icon(Icons.arrow_drop_down),
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
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الدفع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            SizedBox(height: 16),
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
                prefixIcon: Icon(Icons.payment),
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
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceInfo() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات المرجع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _referenceType,
              decoration: InputDecoration(
                labelText: 'نوع المرجع',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _referenceTypes.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _referenceType = value!;
                });
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
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
      label: Text('حفظ سند الصرف'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: _submitVoucher,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}