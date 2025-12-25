import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class AddPurchaseReturnScreen extends StatefulWidget {
  @override
  _AddPurchaseReturnScreenState createState() => _AddPurchaseReturnScreenState();
}

class _AddPurchaseReturnScreenState extends State<AddPurchaseReturnScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // بيانات المرتجع
  int? _selectedSupplierId;
  int? _selectedWarehouseId;
  int? _selectedPurchaseInvoiceId;
  String _reason = '';
  DateTime _returnDate = DateTime.now();

  // القوائم المنسدلة
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _purchaseInvoices = [];
  List<Map<String, dynamic>> _invoiceItems = [];

  // بنود المرتجع
  List<ReturnItem> _returnItems = [];

  // حالة التحميل
  bool _isLoading = true;
  bool _isSubmitting = false;

  // البحث والتصفية
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final suppliers = await _dbHelper.getSuppliers();
      final warehouses = await _dbHelper.getWarehouses();

      setState(() {
        _suppliers = suppliers;
        _warehouses = warehouses;
        _isLoading = false;
      });
    } catch (e) {
      _showError('فشل في تحميل البيانات: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPurchaseInvoices(int supplierId) async {
    try {
      final invoices = await _dbHelper.getPurchaseInvoices(status: 'approved');
      final supplierInvoices = invoices.where((invoice) => invoice['supplier_id'] == supplierId).toList();

      setState(() {
        _purchaseInvoices = supplierInvoices;
        _selectedPurchaseInvoiceId = null;
        _invoiceItems = [];
        _returnItems = [];
      });
    } catch (e) {
      _showError('فشل في تحميل فواتير الشراء: $e');
    }
  }

  Future<void> _loadInvoiceItems(int invoiceId) async {
    try {
      final invoiceData = await _dbHelper.getPurchaseInvoiceWithItems(invoiceId);
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

    if (_selectedItems.isEmpty) {
      _showError('يرجى إضافة منتجات للمرتجع');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final returnData = {
        'purchase_invoice_id': _selectedPurchaseInvoiceId,
        'supplier_id': _selectedSupplierId,
        'warehouse_id': _selectedWarehouseId,
        'reason': _reason,
        'return_date': _returnDate.toIso8601String(),
        'created_by': 1, // TODO: استبدال بـ ID المستخدم الحالي
      };

      final items = _selectedItems.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      }).toList();

      final result = await _dbHelper.createPurchaseReturnWithItems(returnData, items);

      if (result['success']) {
        _showSuccess('تم إنشاء مرتجع الشراء بنجاح');
        Navigator.pop(context, true);
      } else {
        _showError(result['error']);
      }
    } catch (e) {
      _showError('فشل في إنشاء المرتجع: $e');
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
        title: Text('إضافة مرتجع شراء'),
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

            // المورد
            DropdownButtonFormField<int>(
              value: _selectedSupplierId,
              decoration: InputDecoration(
                labelText: 'المورد *',
                border: OutlineInputBorder(),
              ),
              items: _suppliers.map((supplier) {
                return DropdownMenuItem<int>(
                  value: supplier['id'],
                  child: Text(supplier['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSupplierId = value);
                if (value != null) _loadPurchaseInvoices(value);
              },
              validator: (value) => value == null ? 'يرجى اختيار المورد' : null,
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

            // فاتورة الشراء
            DropdownButtonFormField<int>(
              value: _selectedPurchaseInvoiceId,
              decoration: InputDecoration(
                labelText: 'فاتورة الشراء *',
                border: OutlineInputBorder(),
              ),
              items: _purchaseInvoices.map((invoice) {
                return DropdownMenuItem<int>(
                  value: invoice['id'],
                  child: Text('فاتورة #${invoice['invoice_number']} - ${invoice['total_amount']} ريال'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPurchaseInvoiceId = value);
                if (value != null) _loadInvoiceItems(value);
              },
              validator: (value) => value == null ? 'يرجى اختيار فاتورة الشراء' : null,
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
                labelText: 'سبب المرتجع',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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

            if (_invoiceItems.isEmpty && _selectedPurchaseInvoiceId != null)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                    Text('لا توجد بنود في الفاتورة المحددة'),
                  ],
                ),
              )
            else if (_selectedPurchaseInvoiceId == null)
              Center(
                child: Text('يرجى اختيار فاتورة شراء أولاً'),
              )
            else
              ..._returnItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildReturnItemCard(item, index);
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItemCard(ReturnItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      color: item.quantity > 0 ? Colors.blue[50] : null,
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
                Text('الكمية المتاحة: ${item.maxQuantity}'),
                Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: item.quantity > 0
                          ? () => _updateItemQuantity(index, item.quantity - 1)
                          : null,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.quantity.toString(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
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
                child: Text(
                  'المجموع: ${(item.quantity * item.unitPrice).toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
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
                Text('${_selectedItems.length}'),
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
              'حفظ مرتجع الشراء',
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