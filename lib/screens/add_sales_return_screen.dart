import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class AddSalesReturnScreen extends StatefulWidget {
  @override
  _AddSalesReturnScreenState createState() => _AddSalesReturnScreenState();
}

class _AddSalesReturnScreenState extends State<AddSalesReturnScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // بيانات المرتجع
  int? _selectedCustomerId;
  int? _selectedWarehouseId;
  int? _selectedSaleInvoiceId;
  String _reason = '';
  DateTime _returnDate = DateTime.now();

  // القوائم المنسدلة
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _saleInvoices = [];
  List<Map<String, dynamic>> _invoiceItems = [];

  // بنود المرتجع
  List<ReturnItem> _returnItems = [];

  // حالة التحميل
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final customers = await _dbHelper.getCustomers();
      final warehouses = await _dbHelper.getWarehouses();

      setState(() {
        _customers = customers;
        _warehouses = warehouses;
        _isLoading = false;
      });
    } catch (e) {
      _showError('فشل في تحميل البيانات: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSaleInvoices(int? customerId) async {
    try {
      final invoices = await _dbHelper.getSaleInvoices(status: 'approved');

      List<Map<String, dynamic>> filteredInvoices;
      if (customerId != null) {
        filteredInvoices = invoices.where((invoice) => invoice['customer_id'] == customerId).toList();
      } else {
        filteredInvoices = invoices;
      }

      setState(() {
        _saleInvoices = filteredInvoices;
        _selectedSaleInvoiceId = null;
        _invoiceItems = [];
        _returnItems = [];
      });
    } catch (e) {
      _showError('فشل في تحميل فواتير البيع: $e');
    }
  }

  Future<void> _loadInvoiceItems(int invoiceId) async {
    try {
      final invoiceData = await _dbHelper.getSaleInvoiceWithItems(invoiceId);
      if (invoiceData != null) {
        setState(() {
          _invoiceItems = invoiceData['items'];
          _initializeReturnItems();
        });
      }
    } catch (e) {
      _showError('فشل في تحميل بنود الفاتورة: $e');
    }
  }

  void _initializeReturnItems() {
    _returnItems = _invoiceItems.map((item) {
      return ReturnItem(
        productId: item['product_id'],
        productName: item['product_name'],
        barcode: item['barcode'],
        maxQuantity: item['quantity'],
        unitPrice: (item['unit_price'] as num).toDouble(),
        quantity: 0,
      );
    }).toList();
  }

  void _updateItemQuantity(int index, int quantity) {
    setState(() {
      if (quantity <= _returnItems[index].maxQuantity && quantity >= 0) {
        _returnItems[index] = _returnItems[index].copyWith(quantity: quantity);
      }
    });
  }

  double get _totalAmount {
    return _returnItems.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  List<ReturnItem> get _selectedItems {
    return _returnItems.where((item) => item.quantity > 0).toList();
  }

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) {
      _showError('يرجى تعبئة جميع الحقول المطلوبة');
      return;
    }

    if (_selectedSaleInvoiceId == null) {
      _showError('يرجى اختيار فاتورة البيع');
      return;
    }

    if (_selectedWarehouseId == null) {
      _showError('يرجى اختيار المخزن');
      return;
    }

    if (_selectedItems.isEmpty) {
      _showError('يرجى إضافة منتجات للمرتجع');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final returnData = {
        'sale_invoice_id': _selectedSaleInvoiceId,
        'customer_id': _selectedCustomerId,
        'warehouse_id': _selectedWarehouseId,
        'reason': _reason,
        'return_date': _returnDate.toIso8601String(),
        'created_by': 1,
      };

      final items = _selectedItems.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      }).toList();

      final result = await _dbHelper.createSalesReturnWithItems(returnData, items);

      if (result['success']) {
        final returnId = result['return_id'] as int;
        final returnNumber = result['return_number'] as String;
        final totalAmount = result['total_amount'] as double;

        // 📌 **الجزء الجديد: تحديث النظام**

        // 1. تحديث مخزون المنتجات
        for (final item in _selectedItems) {
          try {
            // ⬅️ إضافة الكميات للمخزون (زيادة)
            await _dbHelper.updateProductQuantity(
              item.productId,
              item.quantity,
              'return', // نوع الحركة
              warehouseId: _selectedWarehouseId,
              notes: 'مرتجع بيع رقم $returnNumber',
            );
            print('📦 تم إضافة ${item.quantity} للمنتج ${item.productId}');
          } catch (e) {
            print('⚠️ خطأ في تحديث مخزون المنتج ${item.productId}: $e');
          }
        }

        // 2. تحديث رصيد العميل (خصم من مديونيته)
        if (_selectedCustomerId != null) {
          try {
            await _dbHelper.updateCustomerBalance(
              _selectedCustomerId!,
              totalAmount,
              false, // ⬅️ خصم (نقصان)
            );
            print('👤 تم خصم $totalAmount من رصيد العميل $_selectedCustomerId');
          } catch (e) {
            print('⚠️ خطأ في تحديث رصيد العميل: $e');
          }
        }

        // 3. تسجيل المعاملات في جدول transactions
        try {
          // احصل على اسم العميل
          String customerName = 'غير معروف';
          if (_selectedCustomerId != null) {
            final customer = await _dbHelper.getCustomer(_selectedCustomerId!);
            customerName = customer?['name']?.toString() ?? 'عميل';
          }

          // احصل على معلومات الفاتورة الأصلية
          final invoiceData = await _dbHelper.getSaleInvoiceWithItems(_selectedSaleInvoiceId!);
          final originalPaymentMethod = invoiceData?['invoice']?['payment_method'] ?? 'cash';

          // تسجيل كل منتج مرتجع كمعاملة
          for (final item in _selectedItems) {
            final itemTotal = item.quantity * item.unitPrice;

            await _dbHelper.insertTransaction({
              'type': 'return',
              'product_id': item.productId,
              'product_name': item.productName,
              'customer_id': _selectedCustomerId,
              'customer_name': customerName,
              'quantity': item.quantity,
              'unit_sell_price': item.unitPrice,
              'total_amount': itemTotal,
              'date': _returnDate.toIso8601String(),
              'created_by': 1,
            });

            print('📝 تم تسجيل معاملة مرتجع للمنتج: ${item.productName}');
          }

          // 4. تحديث الصندوق إذا كانت الفاتورة الأصلية نقدية
          if (originalPaymentMethod == 'cash' && totalAmount > 0) {
            try {
              await _dbHelper.addSaleToCashLedger(
                totalAmount,
                returnNumber,
                returnId,
                isReturn: true, // ⬅️ إشارة أن هذه حركة مرتجع
              );
              print('💰 تم إضافة $totalAmount للصندوق من المرتجع');
            } catch (e) {
              print('⚠️ خطأ في تحديث الصندوق: $e');
            }
          }

          print('✅ تم تسجيل ${_selectedItems.length} معاملة مرتجع');

        } catch (e) {
          print('⚠️ خطأ في تسجيل المعاملات: $e');
        }

        _showSuccess('✅ تم إنشاء مرتجع البيع بنجاح #$returnNumber');

        // تأخير بسيط ثم العودة
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context, true);

      } else {
        _showError(result['error']);
      }
    } catch (e) {
      _showError('❌ فشل في إنشاء المرتجع: $e');
    } finally {
      setState(() => _isSubmitting = false);
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
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _returnDate) {
      setState(() => _returnDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة مرتجع بيع'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitReturn,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: ListView(
            children: [
              // معلومات أساسية
              _buildBasicInfoSection(),
              SizedBox(height: 20),

              // بنود المرتجع
              _buildReturnItemsSection(),
              SizedBox(height: 20),

              // الملخص
              _buildSummarySection(),
              SizedBox(height: 20),

              // زر الحفظ
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المعلومات الأساسية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // العميل
            DropdownButtonFormField<int>(
              value: _selectedCustomerId,
              decoration: InputDecoration(
                labelText: 'العميل',
                border: OutlineInputBorder(),
                hintText: 'اختر العميل',
              ),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Text('جميع العملاء'),
                ),
                ..._customers.map((customer) {
                  return DropdownMenuItem<int>(
                    value: customer['id'],
                    child: Text(customer['name']),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() => _selectedCustomerId = value);
                _loadSaleInvoices(value);
              },
            ),
            SizedBox(height: 12),

            // المخزن
            DropdownButtonFormField<int>(
              value: _selectedWarehouseId,
              decoration: InputDecoration(
                labelText: 'المخزن *',
                border: OutlineInputBorder(),
              ),
              items: _warehouses.map((warehouse) {
                return DropdownMenuItem<int>(
                  value: warehouse['id'],
                  child: Text(warehouse['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedWarehouseId = value);
              },
              validator: (value) => value == null ? 'يرجى اختيار المخزن' : null,
            ),
            SizedBox(height: 12),

            // فاتورة البيع
            DropdownButtonFormField<int>(
              value: _selectedSaleInvoiceId,
              decoration: InputDecoration(
                labelText: 'فاتورة البيع *',
                border: OutlineInputBorder(),
              ),
              items: _saleInvoices.map((invoice) {
                return DropdownMenuItem<int>(
                  value: invoice['id'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('فاتورة #${invoice['invoice_number']}'),
                      Text(
                        'المبلغ: ${invoice['total_amount']} ريال',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSaleInvoiceId = value);
                if (value != null) _loadInvoiceItems(value);
              },
              validator: (value) => value == null ? 'يرجى اختيار فاتورة البيع' : null,
            ),
            SizedBox(height: 12),

            // تاريخ المرتجع
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'تاريخ المرتجع *',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy-MM-dd').format(_returnDate)),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // سبب المرتجع
            TextFormField(
              decoration: InputDecoration(
                labelText: 'سبب المرتجع *',
                border: OutlineInputBorder(),
                hintText: 'أدخل سبب إرجاع المنتجات',
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'يرجى إدخال سبب المرتجع' : null,
              onChanged: (value) => setState(() => _reason = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItemsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'بنود المرتجع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                if (_returnItems.isNotEmpty)
                  Text(
                    '${_selectedItems.length} منتج مرفوع',
                    style: TextStyle(color: Colors.blue),
                  ),
              ],
            ),
            SizedBox(height: 16),

            if (_invoiceItems.isEmpty && _selectedSaleInvoiceId != null)
              _buildEmptyItemsState()
            else if (_selectedSaleInvoiceId == null)
              _buildSelectInvoiceState()
            else
              _buildItemsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.inventory_2, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد بنود في الفاتورة المحددة',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectInvoiceState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'يرجى اختيار فاتورة بيع أولاً',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'سيتم تحميل بنود الفاتورة تلقائياً',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      children: [
        ..._returnItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildReturnItemCard(item, index);
        }).toList(),

        if (_selectedItems.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'ملاحظة: سيتم إضافة الكميات المرتجعة إلى مخزون المخزن المحدد',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildReturnItemCard(ReturnItem item, int index) {
    final isSelected = item.quantity > 0;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      color: isSelected ? Colors.blue[50] : null,
      elevation: isSelected ? 2 : 1,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (item.barcode != null)
                        Text(
                          'باركود: ${item.barcode}',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      SizedBox(height: 4),
                      Text(
                        'الحد الأقصى للاسترجاع: ${item.maxQuantity}',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.unitPrice} ريال',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'الكمية:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.maxQuantity} متاح',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      onPressed: item.quantity > 0
                          ? () => _updateItemQuantity(index, item.quantity - 1)
                          : null,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      child: Text(
                        item.quantity.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline),
                      color: Colors.green,
                      onPressed: item.quantity < item.maxQuantity
                          ? () => _updateItemQuantity(index, item.quantity + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (item.quantity > 0)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المجموع:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(item.quantity * item.unitPrice).toStringAsFixed(2)} ريال',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص المرتجع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('عدد المنتجات:'),
                Text(
                  '${_selectedItems.length}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبلغ الإجمالي:'),
                Text(
                  '${_totalAmount.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(),
            Text(
              'سيتم تنفيذ العمليات التالية:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 4),
            Text(
              '• خصم المبلغ من رصيد العميل (إذا كان مديناً)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '• إضافة الكميات المرتجعة إلى المخزن',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitReturn,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _isSubmitting
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(width: 8),
          Text('جاري الحفظ...'),
        ],
      )
          : Text(
        'حفظ مرتجع البيع',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ReturnItem {
  final int productId;
  final String productName;
  final String? barcode;
  final int maxQuantity;
  final double unitPrice;
  final int quantity;

  ReturnItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.maxQuantity,
    required this.unitPrice,
    required this.quantity,
  });

  ReturnItem copyWith({
    int? quantity,
  }) {
    return ReturnItem(
      productId: productId,
      productName: productName,
      barcode: barcode,
      maxQuantity: maxQuantity,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}