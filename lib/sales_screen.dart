import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'color.dart';
import 'database_helper.dart';

class SalesScreen extends StatefulWidget {
  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _barcodeController = TextEditingController();
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();
  final _paidAmountController = TextEditingController();

  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _products = [];

  int? _selectedCustomerId;
  int? _selectedWarehouseId;
  double _totalAmount = 0.0;
  double _paidAmount = 0.0;
  double _changeAmount = 0.0;
  bool _isLoading = false;
  MobileScannerController? _cameraController;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _generateInvoiceNumber();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    _paidAmountController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  String _invoiceNumber = '';

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    _invoiceNumber = 'POS${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}';
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      final customers = await _dbHelper.getCustomers();
      final warehouses = await _dbHelper.getWarehouses();
      final products = await _dbHelper.getProducts();

      setState(() {
        _customers = customers;
        _warehouses = warehouses;
        _products = products;
        if (warehouses.isNotEmpty) _selectedWarehouseId = warehouses.first['id'];
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
      _showSnackBar('فشل تحميل البيانات', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // 📸 دالة المسح الضوئي بالكاميرا باستخدام mobile_scanner
  Future<void> _scanBarcode() async {
    if (_selectedWarehouseId == null) {
      _showSnackBar('يرجى اختيار المخزن أولاً', isError: true);
      return;
    }

    // فتح شاشة المسح الضوئي
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          onBarcodeDetected: (barcode) {
            _searchProductByBarcode(barcode);
          },
        ),
      ),
    );
  }

  Future<void> _searchProductByBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      // البحث في القائمة المحملة أولاً
      final product = _products.firstWhere(
            (p) => p['barcode']?.toString() == barcode,
        orElse: () => {},
      );

      if (product.isNotEmpty) {
        _addToCart(product);
        _barcodeController.clear();
      } else {
        // البحث في قاعدة البيانات
        final dbProduct = await _dbHelper.getProductByBarcode(barcode);
        if (dbProduct != null) {
          _addToCart(dbProduct);
          _barcodeController.clear();
        } else {
          _showSnackBar('المنتج غير موجود', isError: true);
        }
      }
    } catch (e) {
      print('خطأ في البحث: $e');
      _showSnackBar('خطأ في البحث عن المنتج', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    final productId = product['id'];
    final existingIndex = _cartItems.indexWhere((item) => item['product_id'] == productId);

    if (existingIndex != -1) {
      setState(() {
        _cartItems[existingIndex]['quantity'] += 1;
        _cartItems[existingIndex]['total_price'] =
            _cartItems[existingIndex]['quantity'] * _cartItems[existingIndex]['sell_price'];
      });
      _showSnackBar('تم زيادة الكمية', isError: false);
    } else {
      setState(() {
        _cartItems.add({
          'product_id': productId,
          'product_name': product['name'],
          'barcode': product['barcode'],
          'purchase_price': product['purchase_price'] ?? 0.0,
          'sell_price': product['sell_price'] ?? 0.0,
          'quantity': 1,
          'total_price': product['sell_price'] ?? 0.0,
        });
      });
      _showSnackBar('تم إضافة المنتج', isError: false);
    }
    _calculateTotal();
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _calculateTotal();
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      setState(() {
        _cartItems[index]['quantity'] = newQuantity;
        _cartItems[index]['total_price'] = newQuantity * _cartItems[index]['sell_price'];
        _calculateTotal();
      });
    }
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) => sum + (item['total_price'] as double));
    _calculateChange();
  }

  void _calculateChange() {
    _changeAmount = _paidAmount - _totalAmount;
  }

  Future<void> _completeSale() async {
    if (_cartItems.isEmpty) {
      _showSnackBar('السلة فارغة', isError: true);
      return;
    }

    if (_selectedWarehouseId == null) {
      _showSnackBar('يرجى اختيار المخزن', isError: true);
      return;
    }

    if (_paidAmount < _totalAmount) {
      _showSnackBar('المبلغ المدفوع غير كافي', isError: true);
      return;
    }

    // تأكيد عملية البيع
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد البيع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم الفاتورة: $_invoiceNumber'),
            SizedBox(height: 8),
            Text('الإجمالي: ${_totalAmount.toStringAsFixed(2)} ر.س'),
            Text('المدفوع: ${_paidAmount.toStringAsFixed(2)} ر.س'),
            Text('الباقي: ${_changeAmount.toStringAsFixed(2)} ر.س'),
            SizedBox(height: 8),
            Text('عدد المنتجات: ${_cartItems.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('تأكيد البيع'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // استخدام الدالة المحسنة
      final invoiceData = {
        'invoice_number': _invoiceNumber,
        'customer_id': _selectedCustomerId,
        'warehouse_id': _selectedWarehouseId,
        'total_amount': _totalAmount,
        'paid_amount': _paidAmount,
        'discount': 0.0,
        'payment_method': 'cash',
        'notes': _notesController.text.trim(),
        'status': 'approved',
        'invoice_date': DateTime.now().toIso8601String(),
        'created_by': 1, // TODO: استخدم ID المستخدم الحقيقي
      };

      final items = _cartItems.map((item) {
        return {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['sell_price'],
          'cost_price': item['purchase_price'],
          'total_price': item['total_price'],
        };
      }).toList();

      final result = await _dbHelper.createSaleInvoiceWithItems(invoiceData, items);

      if (result['success'] == true) {
        // تحديث المخزون
        for (final item in _cartItems) {
          await _dbHelper.updateProductStockForSale(
            item['product_id'],
            _selectedWarehouseId!,
            item['quantity'],
          );
        }

        // إضافة لسجل المعاملات
        for (final item in _cartItems) {
          await _dbHelper.insertTransaction({
            'type': 'sale',
            'product_id': item['product_id'],
            'product_name': item['product_name'],
            'customer_id': _selectedCustomerId,
            'customer_name': _selectedCustomerId != null ?
            _customers.firstWhere((c) => c['id'] == _selectedCustomerId)['name'] : 'نقدي',
            'quantity': item['quantity'],
            'unit_sell_price': item['sell_price'],
            'profit': item['sell_price'] - item['purchase_price'],
            'total_amount': item['total_price'],
            'date': DateTime.now().toIso8601String(),
            'created_by': 1,
          });
        }

        _showSnackBar('✅ تم إتمام البيع بنجاح', isError: false);

        // عرض إيصال البيع
        _showReceipt();

        _resetForm();
      } else {
        _showSnackBar('❌ فشل في إنشاء الفاتورة: ${result['error']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('❌ خطأ في إتمام البيع: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showReceipt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(child: Text('إيصال البيع', style: TextStyle(fontWeight: FontWeight.bold))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('رقم الفاتورة: $_invoiceNumber', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('التاريخ: ${DateTime.now().toString().split(' ')[0]}'),
              Divider(),
              ..._cartItems.map((item) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['product_name']}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${item['quantity']} × ${item['sell_price']}',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(width: 10),
                    Text(
                      '${item['total_price']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )).toList(),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_totalAmount.toStringAsFixed(2)} ر.س', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المدفوع:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_paidAmount.toStringAsFixed(2)} ر.س', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الباقي:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_changeAmount.toStringAsFixed(2)} ر.س', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _cartItems.clear();
      _totalAmount = 0.0;
      _paidAmount = 0.0;
      _changeAmount = 0.0;
      _barcodeController.clear();
      _notesController.clear();
      _paidAmountController.clear();
      _generateInvoiceNumber();
    });
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProductSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => ProductSearchDialog(
        products: _products,
        onProductSelected: _addToCart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.point_of_sale, size: 28),
            SizedBox(width: 10),
            Text('نقطة البيع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Spacer(),
            Text(_invoiceNumber, style: TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _showProductSearchDialog,
            tooltip: 'بحث عن منتج',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🏪 معلومات المخزن والعميل
          Card(
            margin: EdgeInsets.all(12),
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<int?>(
                              value: _selectedWarehouseId,
                              isExpanded: true,
                              underline: SizedBox(),
                              hint: Text('اختر المخزن'),
                              items: _warehouses.map((warehouse) {
                                return DropdownMenuItem<int?>(
                                  value: warehouse['id'],
                                  child: Text(warehouse['name'], style: TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedWarehouseId = value),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<int?>(
                              value: _selectedCustomerId,
                              isExpanded: true,
                              underline: SizedBox(),
                              hint: Text('عميل نقدي'),
                              items: [
                                DropdownMenuItem<int?>(value: null, child: Text('عميل نقدي')),
                                ..._customers.map((customer) {
                                  return DropdownMenuItem<int?>(
                                    value: customer['id'],
                                    child: Text(customer['name'], style: TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) => setState(() => _selectedCustomerId = value),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // 🔍 البحث والمسح
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _barcodeController,
                            decoration: InputDecoration(
                              hintText: 'أدخل الباركود يدوياً...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              suffixIcon: Icon(Icons.keyboard, color: Colors.grey),
                            ),
                            onSubmitted: (value) => _searchProductByBarcode(value),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.camera_alt),
                        label: Text('مسح', style: TextStyle(fontSize: 14)),
                        onPressed: _scanBarcode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 🛒 قائمة المنتجات
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('السلة فارغة', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Text('ابدأ بمسح الباركود أو البحث عن منتج', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
                : Column(
              children: [
                // رأس القائمة
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      ),
                      Expanded(
                        child: Center(child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]))),
                      ),
                      Expanded(
                        child: Center(child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]))),
                      ),
                      Expanded(
                        child: Center(child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]))),
                      ),
                      SizedBox(width: 40), // مساحة للأزرار
                    ],
                  ),
                ),

                // قائمة المنتجات
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        elevation: 1,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['product_name'],
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item['barcode'] != null)
                                      Text(
                                        'باركود: ${item['barcode']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.remove, size: 18),
                                          onPressed: () => _updateQuantity(index, item['quantity'] - 1),
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                        ),
                                        Container(
                                          width: 30,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item['quantity']}',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.add, size: 18),
                                          onPressed: () => _updateQuantity(index, item['quantity'] + 1),
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${item['sell_price'].toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${item['total_price'].toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeFromCart(index),
                                tooltip: 'حذف',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 💰 ملخص الفاتورة والدفع
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // الإجمالي
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '${_totalAmount.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // المدفوع والباقي
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _paidAmountController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'المبلغ المدفوع',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            prefixIcon: Icon(Icons.payments, color: Colors.grey),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _paidAmount = double.tryParse(value) ?? 0.0;
                              _calculateChange();
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: _changeAmount >= 0 ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _changeAmount >= 0 ? Colors.green[200]! : Colors.red[200]!),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'الباقي',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            '${_changeAmount.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _changeAmount >= 0 ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // الملاحظات
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: 'ملاحظات إضافية (اختياري)',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefixIcon: Icon(Icons.note, color: Colors.grey),
                    ),
                    maxLines: 2,
                  ),
                ),

                SizedBox(height: 16),

                // زر إتمام البيع
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_cartItems.isNotEmpty && _paidAmount >= _totalAmount) && !_isLoading
                        ? _completeSale
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('جاري المعالجة...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 24),
                        SizedBox(width: 8),
                        Text('إتمام البيع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// شاشة المسح الضوئي باستخدام MobileScanner
class BarcodeScannerScreen extends StatefulWidget {
  final Function(String) onBarcodeDetected;

  const BarcodeScannerScreen({Key? key, required this.onBarcodeDetected}) : super(key: key);

  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    torchEnabled: false,
    formats: [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _isTorchOn = false;
  bool _isScanning = true;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text('مسح الباركود', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              cameraController.toggleTorch();
            },
          ),
          IconButton(
            icon: Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // كاميرا المسح الضوئي
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!_isScanning) return;

              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  // إيقاف المسح مؤقتاً
                  setState(() => _isScanning = false);

                  // إرجاع النتيجة والعودة
                  Future.delayed(Duration(milliseconds: 500), () {
                    Navigator.pop(context);
                    widget.onBarcodeDetected(barcode.rawValue!);
                  });
                }
              }
            },
          ),

          // طبقات إرشادية
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // تعليمات
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    'ضع الباركود داخل الإطار',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سيتم المسح تلقائياً',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductSearchDialog extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onProductSelected;

  const ProductSearchDialog({required this.products, required this.onProductSelected});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('البحث عن المنتج', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الباركود...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              onChanged: (query) {
                // يمكنك إضافة البحث هنا
              },
            ),
            SizedBox(height: 16),
            Expanded(
              child: products.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text('لا توجد منتجات', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.inventory, color: Colors.blue),
                      ),
                      title: Text(product['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('السعر: ${product['sell_price']} ر.س'),
                          if (product['barcode'] != null)
                            Text('الباركود: ${product['barcode']}', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Icon(Icons.add_circle, color: Colors.green),
                      onTap: () {
                        onProductSelected(product);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}