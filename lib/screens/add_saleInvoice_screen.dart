import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class AddSaleInvoiceScreen extends StatefulWidget {
  @override
  _AddSaleInvoiceScreenState createState() => _AddSaleInvoiceScreenState();
}

class _AddSaleInvoiceScreenState extends State<AddSaleInvoiceScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // البيانات الأساسية
  int? _selectedCustomerId;
  int? _selectedWarehouseId;
  String _paymentMethod = 'cash';
  double _discountAmount = 0.0;
  double _discountPercent = 0.0;
  double _taxPercent = 15.0;
  double _paidAmount = 0.0;
  double _customerBalance = 0.0;
  double _customerCreditLimit = 0.0;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();

  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  DateTime? _transferDate;

  // تأكيدات الدفع
  bool _cashReceived = false;
  bool _transferConfirmed = false;
  String _transferReference = '';
  String _transferBank = '';
  String _guaranteeDetails = '';

  // القوائم
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  // بنود الفاتورة
  final List<Map<String, dynamic>> _invoiceItems = [];

  // الحالة
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showCustomerDetails = false;

  // البحث
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _generateInvoiceNumber();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    _invoiceNumberController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // 📌 دالة توليد رقم الفاتورة
  void _generateInvoiceNumber() {
    final now = DateTime.now();
    final number = 'S${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour}${now.minute}${now.second}';
    _invoiceNumberController.text = number;
  }

  // 📌 تحميل البيانات الأولية
  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      final results = await Future.wait([
        _dbHelper.getCustomers(),
        _dbHelper.getWarehouses(),
        _dbHelper.getProducts(),
      ]);

      setState(() {
        _customers = results[0];
        _warehouses = results[1];
        _products = results[2];
        _filteredProducts = results[2];
        _isLoading = false;
      });

      // اختيار المخزن الأول تلقائياً إذا كان موجوداً
      if (_warehouses.isNotEmpty) {
        _selectedWarehouseId = _warehouses.first['id'] as int?;
      }

    } catch (e) {
      _showError('❌ فشل في تحميل البيانات: $e');
      setState(() => _isLoading = false);
    }
  }

  // 📌 تحميل معلومات العميل
  Future<void> _loadCustomerInfo() async {
    if (_selectedCustomerId == null) return;

    try {
      final customer = await _dbHelper.getCustomer(_selectedCustomerId!);
      if (customer != null) {
        setState(() {
          _customerBalance = (customer['balance'] as num?)?.toDouble() ?? 0.0;
          _customerCreditLimit = (customer['credit_limit'] as num?)?.toDouble() ?? 0.0;
          _showCustomerDetails = true;
        });
      }
    } catch (e) {
      print('⚠️ خطأ في تحميل معلومات العميل: $e');
    }
  }

  // 📌 البحث عن المنتجات
  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          final barcode = product['barcode']?.toString().toLowerCase() ?? '';
          return name.contains(query) || barcode.contains(query);
        }).toList();
      }
    });
  }

  // 📌 إضافة منتج للفاتورة
  void _addProductToInvoice(Map<String, dynamic> product) {
    final productId = product['id'] as int;
    final existingIndex = _invoiceItems.indexWhere((item) => item['product_id'] == productId);

    if (existingIndex != -1) {
      // زيادة الكمية إذا المنتج موجود
      setState(() {
        _invoiceItems[existingIndex]['quantity'] += 1;
      });
      _showSuccess('✅ تم زيادة كمية المنتج');
    } else {
      // إضافة منتج جديد
      setState(() {
        _invoiceItems.add({
          'product_id': productId,
          'product_name': product['name']?.toString() ?? 'غير معروف',
          'barcode': product['barcode']?.toString() ?? '',
          'unit_price': (product['sell_price'] as num?)?.toDouble() ?? 0.0,
          'cost_price': (product['purchase_price'] as num?)?.toDouble() ?? 0.0,
          'quantity': 1,
        });
      });
      _showSuccess('✅ تم إضافة المنتج للفاتورة');
    }

    _searchController.clear();
    Navigator.pop(context);
  }

  // 📌 تحديث كمية المنتج
  void _updateItemQuantity(int index, int quantity) {
    if (quantity < 1) {
      _showError('الحد الأدنى للكمية هو 1');
      return;
    }

    if (quantity > 999) {
      _showError('الحد الأقصى للكمية هو 999');
      return;
    }

    setState(() {
      _invoiceItems[index]['quantity'] = quantity;
    });
  }

  // 📌 حذف منتج من الفاتورة
  void _removeItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج من الفاتورة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _invoiceItems.removeAt(index));
              Navigator.pop(context);
              _showSuccess('✅ تم حذف المنتج');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // 📌 الحسابات
  double get _subTotal {
    return _invoiceItems.fold(0.0, (sum, item) {
      return sum + (item['quantity'] * item['unit_price']);
    });
  }

  double get _totalDiscount {
    if (_discountPercent > 0) {
      return _subTotal * (_discountPercent / 100);
    }
    return _discountAmount;
  }

  double get _totalTax {
    return (_subTotal - _totalDiscount) * (_taxPercent / 100);
  }

  double get _totalAmount {
    return _subTotal - _totalDiscount + _totalTax;
  }

  double get _remainingAmount {
    return _totalAmount - _paidAmount;
  }

  double get _totalProfit {
    return _invoiceItems.fold(0.0, (sum, item) {
      final revenue = item['quantity'] * item['unit_price'];
      final cost = item['quantity'] * item['cost_price'];
      return sum + (revenue - cost);
    }) - _totalDiscount;
  }

  // 📌 تأكيد الدفع النقدي
  Future<bool> _confirmCashPayment() async {
    if (_paidAmount >= _totalAmount) return true;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الدفع النقدي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المبلغ المطلوب: ${_totalAmount.toStringAsFixed(2)} ريال'),
            Text('المبلغ المدفوع: ${_paidAmount.toStringAsFixed(2)} ريال'),
            if (_paidAmount < _totalAmount)
              Text('المبلغ الناقص: ${(_totalAmount - _paidAmount).toStringAsFixed(2)} ريال',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('تأكيد استلام النقود'),
              value: _cashReceived,
              onChanged: (value) => setState(() => _cashReceived = value ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _cashReceived ? () => Navigator.pop(context, true) : null,
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ) ?? false;
  }

  // 📌 تأكيد التحويل البنكي
  Future<bool> _confirmTransferPayment() async {
    _transferReference = '';
    _transferBank = '';

    return await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('بيانات التحويل البنكي'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'رقم المرجع',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _transferReference = value,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'اسم البنك',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _transferBank = value,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _transferDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ التحويل',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_transferDate != null
                              ? DateFormat('yyyy-MM-dd').format(_transferDate!)
                              : 'اختر التاريخ'),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('تأكيد وصول المبلغ'),
                    value: _transferConfirmed,
                    onChanged: (value) => setState(() => _transferConfirmed = value ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: (_transferReference.isNotEmpty &&
                    _transferBank.isNotEmpty &&
                    _transferDate != null &&
                    _transferConfirmed)
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('تأكيد'),
              ),
            ],
          );
        },
      ),
    ) ?? false;
  }

  // 📌 تأكيد البيع الآجل
  Future<bool> _confirmCreditPayment() async {
    // التحقق من الحد الائتماني
    final newBalance = _customerBalance + _totalAmount;
    if (_customerCreditLimit > 0 && newBalance > _customerCreditLimit) {
      _showError('❌ تجاوز الحد الائتماني! '
          'الرصيد الحالي: ${_customerBalance.toStringAsFixed(2)} + '
          'الفاتورة: ${_totalAmount.toStringAsFixed(2)} = '
          '${newBalance.toStringAsFixed(2)} > '
          'الحد: ${_customerCreditLimit.toStringAsFixed(2)}');
      return false;
    }

    // اختيار تاريخ الاستحقاق
    _dueDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (_dueDate == null) {
      _showError('يرجى تحديد تاريخ الاستحقاق');
      return false;
    }

    return true;
  }

  // 📌 حفظ الفاتورة
  // دالة _saveInvoice المحدثة:
  Future<void> _saveInvoice() async {
    // 📌 1. التحقق من رصيد الصندوق
    if (_paymentMethod == 'cash' && _paidAmount > 0) {
      try {
        final cashBalance = await _dbHelper.getCurrentCashBalance();
        if (cashBalance < _paidAmount) {
          final confirm = await _showCashBalanceWarning(cashBalance, _paidAmount);
          if (!confirm) return;
        }
      } catch (e) {
        print('⚠️ خطأ في التحقق من رصيد الصندوق: $e');
      }
    }

    // 📌 2. التحقق من البيانات الأساسية
    if (_selectedWarehouseId == null) {
      _showError('يرجى اختيار المخزن');
      return;
    }

    if (_invoiceItems.isEmpty) {
      _showError('يرجى إضافة منتجات للفاتورة');
      return;
    }

    if (_paidAmount > _totalAmount) {
      _showError('المبلغ المدفوع لا يمكن أن يكون أكبر من الإجمالي');
      return;
    }

    // 📌 3. التحقق من توفر المخزون
    bool allItemsAvailable = true;
    String errorMessage = '';

    for (final item in _invoiceItems) {
      try {
        final stock = await _dbHelper.getProductStock(
            item['product_id'],
            _selectedWarehouseId!
        );

        if (stock == null || (stock['quantity'] as int) < item['quantity']) {
          allItemsAvailable = false;
          errorMessage = 'المنتج "${item['product_name']}" غير متوفر بالكمية المطلوبة';
          break;
        }
      } catch (e) {
        allItemsAvailable = false;
        errorMessage = 'خطأ في التحقق من مخزون المنتج "${item['product_name']}"';
        break;
      }
    }

    if (!allItemsAvailable) {
      _showError(errorMessage);
      return;
    }

    // 📌 4. تأكيدات الدفع حسب النوع
    bool paymentConfirmed = true;

    if (_paymentMethod == 'cash') {
      paymentConfirmed = await _confirmCashPayment();
    } else if (_paymentMethod == 'transfer') {
      paymentConfirmed = await _confirmTransferPayment();
    } else if (_paymentMethod == 'credit') {
      paymentConfirmed = await _confirmCreditPayment();
      if (_selectedCustomerId == null) {
        _showError('يجب اختيار عميل للبيع الآجل');
        return;
      }
    }

    if (!paymentConfirmed) return;

    // 📌 5. حفظ الفاتورة
    setState(() => _isSubmitting = true);

    try {
      final invoiceData = {
        'invoice_number': _invoiceNumberController.text.trim(),
        'customer_id': _selectedCustomerId,
        'warehouse_id': _selectedWarehouseId,
        'payment_method': _paymentMethod,
        'sub_total': _subTotal,
        'discount_amount': _totalDiscount,
        'tax_percent': _taxPercent,
        'tax_amount': _totalTax,
        'total_amount': _totalAmount,
        'paid_amount': _paidAmount,
        'remaining_amount': _remainingAmount,
        'notes': _notesController.text.trim(),
        'invoice_date': _invoiceDate.toIso8601String(),
        'status': 'approved',
        'created_by': 1,

        // بيانات إضافية
        'due_date': _dueDate?.toIso8601String(),
        'transfer_reference': _transferReference,
        'transfer_bank': _transferBank,
        'transfer_date': _transferDate?.toIso8601String(),
        'guarantee_details': _guaranteeDetails,
        'cash_received': _cashReceived ? 1 : 0,
        'transfer_confirmed': _transferConfirmed ? 1 : 0,
      };

      final items = _invoiceItems.map((item) {
        final totalPrice = item['quantity'] * item['unit_price'];
        final totalCost = item['quantity'] * item['cost_price'];
        final profit = totalPrice - totalCost;

        return {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'cost_price': item['cost_price'],
          'total_price': totalPrice,
          'total_cost': totalCost,
          'profit': profit,
        };
      }).toList();

      final result = await _dbHelper.createSaleInvoiceWithItems(invoiceData, items);

      if (result['success'] == true) {
        final invoiceId = result['invoice_id'] as int;
        final invoiceNumber = _invoiceNumberController.text.trim();

        // 📌 6. تحديث مخزون المنتجات
        for (final item in _invoiceItems) {
          try {
            await _dbHelper.updateProductStockForSale(
              item['product_id'],
              _selectedWarehouseId!,
              item['quantity'],
            );
            print('📦 تم تحديث مخزون المنتج ${item['product_id']}');
          } catch (e) {
            print('⚠️ خطأ في تحديث مخزون المنتج ${item['product_id']}: $e');
          }
        }

        // 📌 7. تحديث سجل الصندوق (إذا كان الدفع نقدي)
        if (_paymentMethod == 'cash' && _paidAmount > 0) {
          try {
            await _dbHelper.addSaleToCashLedger(_paidAmount, invoiceNumber, invoiceId);
            print('💰 تم تحديث سجل الصندوق بمبلغ: $_paidAmount');
          } catch (e) {
            print('⚠️ خطأ في تحديث سجل الصندوق: $e');
          }
        }

        // 📌 8. تحديث رصيد العميل (إذا كان البيع آجل)
        if (_paymentMethod == 'credit' && _selectedCustomerId != null) {
          try {
            await _dbHelper.updateCustomerBalance(
              _selectedCustomerId!,
              _totalAmount,
              true, // زيادة مدين العميل
            );
            print('👤 تم تحديث رصيد العميل $_selectedCustomerId');
          } catch (e) {
            print('⚠️ خطأ في تحديث رصيد العميل: $e');
          }
        }

        // 📌 9. تسجيل المعاملات في جدول transactions
        try {
          // احصل على اسم العميل
          String customerName = 'عميل نقدي';
          if (_selectedCustomerId != null) {
            final customer = await _dbHelper.getCustomer(_selectedCustomerId!);
            customerName = customer?['name']?.toString() ?? 'عميل';
          }

          // تسجيل كل منتج كمعاملة منفصلة
          for (final item in _invoiceItems) {
            final totalPrice = item['quantity'] * item['unit_price'];
            final totalCost = item['quantity'] * item['cost_price'];
            final profit = totalPrice - totalCost;

            await _dbHelper.insertTransaction({
              'type': 'sale',
              'product_id': item['product_id'],
              'product_name': item['product_name'],
              'customer_id': _selectedCustomerId,
              'customer_name': customerName,
              'quantity': item['quantity'],
              'unit_sell_price': item['unit_price'],
              'profit': profit,
              'total_amount': totalPrice,
              'date': _invoiceDate.toIso8601String(),
              'created_by': 1, // TODO: استخدم ID المستخدم الحقيقي
            });

            print('📝 تم تسجيل معاملة بيع للمنتج: ${item['product_name']}');
          }

          print('✅ تم تسجيل ${_invoiceItems.length} معاملة بيع');

        } catch (e) {
          print('⚠️ خطأ في تسجيل المعاملات: $e');
          // لا نعرض خطأ للمستخدم لأن الفاتورة تمت بنجاح
        }

        _showSuccess('✅ تم إنشاء الفاتورة رقم $invoiceNumber');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context, true);
      } else {
        _showError('❌ ${result['error'] ?? 'حدث خطأ في الحفظ'}');
      }

    } catch (e) {
      _showError('❌ فشل في حفظ الفاتورة: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

// 📌 دالة مساعدة للتحذير من نقص رصيد الصندوق
  Future<bool> _showCashBalanceWarning(double currentBalance, double requiredAmount) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ رصيد الصندوق غير كافي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الرصيد الحالي: ${currentBalance.toStringAsFixed(2)} ريال'),
            Text('المبلغ المطلوب: ${requiredAmount.toStringAsFixed(2)} ريال'),
            Text('النقص: ${(requiredAmount - currentBalance).toStringAsFixed(2)} ريال'),
            const SizedBox(height: 16),
            const Text(
              'هل تريد المتابعة رغم نقص الرصيد؟',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('متابعة'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 📌 واجهة البحث عن المنتجات
  void _showProductSearch() {
    _searchController.clear();
    _filterProducts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // شريط البحث
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'ابحث عن منتج...',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (_) => _filterProducts(),
                          autofocus: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // عدد المنتجات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'المنتجات المتاحة (${_filteredProducts.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // قائمة المنتجات
              Expanded(
                child: _filteredProducts.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'لا توجد منتجات'
                            : 'لا توجد نتائج للبحث',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final price = (product['sell_price'] as num?)?.toDouble() ?? 0.0;
                    final inInvoice = _invoiceItems.any((item) =>
                    item['product_id'] == product['id']);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: inInvoice ? Colors.green[100] : Colors.blue[100],
                          child: Icon(
                            inInvoice ? Icons.check : Icons.shopping_bag,
                            color: inInvoice ? Colors.green : Colors.blue,
                          ),
                        ),
                        title: Text(
                          product['name']?.toString() ?? 'غير معروف',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product['barcode'] != null)
                              Text(
                                'باركود: ${product['barcode']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            Text(
                              'السعر: ${price.toStringAsFixed(2)} ريال',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: inInvoice
                            ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'مضاف',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                            : IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () => _addProductToInvoice(product),
                        ),
                        onTap: () => _addProductToInvoice(product),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة بيع جديدة'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _saveInvoice,
            tooltip: 'حفظ الفاتورة',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 📦 معلومات الفاتورة الأساسية
            _buildInvoiceInfoCard(),

            const SizedBox(height: 16),

            // 💰 ملخص الفاتورة
            _buildInvoiceSummaryCard(),

            const SizedBox(height: 16),

            // 🛒 المنتجات
            _buildProductsCard(),

            const SizedBox(height: 24),

            // 💾 زر الحفظ
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // 📦 بطاقة معلومات الفاتورة
  Widget _buildInvoiceInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'معلومات الفاتورة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // رقم الفاتورة
            TextFormField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                labelText: 'رقم الفاتورة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              readOnly: true,
            ),

            const SizedBox(height: 12),

            // العميل
            DropdownButtonFormField<int?>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(
                labelText: 'العميل',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('عميل نقدي'),
                ),
                ..._customers.map<DropdownMenuItem<int?>>((customer) {
                  return DropdownMenuItem<int?>(
                    value: customer['id'] as int?,
                    child: Text(customer['name']?.toString() ?? 'غير معروف'),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCustomerId = value;
                  _showCustomerDetails = false;
                });
                if (value != null) _loadCustomerInfo();
              },
            ),

            const SizedBox(height: 12),

            // معلومات العميل (إذا تم اختياره)
            if (_showCustomerDetails)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الرصيد: ${_customerBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _customerBalance > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'الحد الائتماني: ${_customerCreditLimit.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    if (_customerCreditLimit > 0 &&
                        (_customerBalance + _totalAmount) > _customerCreditLimit)
                      Icon(Icons.warning, color: Colors.orange),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // المخزن
            DropdownButtonFormField<int?>(
              value: _selectedWarehouseId,
              decoration: const InputDecoration(
                labelText: 'المخزن *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
              items: _warehouses.map<DropdownMenuItem<int?>>((warehouse) {
                return DropdownMenuItem<int?>(
                  value: warehouse['id'] as int?,
                  child: Text(warehouse['name']?.toString() ?? ''),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedWarehouseId = value),
              validator: (value) => value == null ? 'مطلوب' : null,
            ),

            const SizedBox(height: 12),

            // طريقة الدفع
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'cash',
                  child: Row(
                    children: [
                      Icon(Icons.money, color: Colors.green),
                      SizedBox(width: 8),
                      Text('نقدي'),
                    ],
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'credit',
                  child: Row(
                    children: [
                      Icon(Icons.credit_card, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('آجل'),
                    ],
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'transfer',
                  child: Row(
                    children: [
                      Icon(Icons.account_balance, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('تحويل'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paymentMethod = value);
                }
              },
            ),

            const SizedBox(height: 12),

            // التاريخ
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _invoiceDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _invoiceDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الفاتورة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy-MM-dd').format(_invoiceDate)),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // الخصم
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _discountAmount.toStringAsFixed(2),
                    decoration: const InputDecoration(
                      labelText: 'الخصم (مبلغ)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _discountAmount = double.tryParse(value) ?? 0.0;
                        _discountPercent = 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _discountPercent.toString(),
                    decoration: const InputDecoration(
                      labelText: 'الخصم (%)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _discountPercent = double.tryParse(value) ?? 0.0;
                        _discountAmount = 0;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // الملاحظات
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  // 💰 بطاقة ملخص الفاتورة
  Widget _buildInvoiceSummaryCard() {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // العنوان
            Row(
              children: [
                Icon(Icons.calculate, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'ملخص الفاتورة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // المجموع
            _buildAmountRow('المجموع:', '${_subTotal.toStringAsFixed(2)} ريال'),
            const SizedBox(height: 8),

            // الخصم
            _buildAmountRow('الخصم:', '${_totalDiscount.toStringAsFixed(2)} ريال',
                color: Colors.red),
            const SizedBox(height: 8),

            // الضريبة
            _buildAmountRow('الضريبة (${_taxPercent}%):',
                '${_totalTax.toStringAsFixed(2)} ريال'),
            const SizedBox(height: 8),

            // الإجمالي
            _buildAmountRow('الإجمالي:', '${_totalAmount.toStringAsFixed(2)} ريال',
                isBold: true),
            const SizedBox(height: 16),

            // المدفوع
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المدفوع:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    initialValue: _paidAmount.toStringAsFixed(2),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                      suffixText: 'ريال',
                    ),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    onChanged: (value) {
                      setState(() => _paidAmount = double.tryParse(value) ?? 0.0);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // المتبقي
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),

            _buildAmountRow(
              'المتبقي:',
              '${_remainingAmount.toStringAsFixed(2)} ريال',
              color: _remainingAmount > 0 ? Colors.red : Colors.green,
              isBold: true,
              fontSize: 18,
            ),

            const SizedBox(height: 8),

            // الربح
            _buildAmountRow(
              'الربح:',
              '${_totalProfit.toStringAsFixed(2)} ريال',
              color: _totalProfit > 0 ? Colors.green : Colors.red,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  // 🛒 بطاقة المنتجات
  Widget _buildProductsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان والزر
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'المنتجات (${_invoiceItems.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منتج'),
                  onPressed: _showProductSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // قائمة المنتجات أو رسالة فارغة
            if (_invoiceItems.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'لم تتم إضافة أي منتجات',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'انقر على "إضافة منتج" لبدء الفاتورة',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ..._invoiceItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final total = item['quantity'] * item['unit_price'];
                final cost = item['quantity'] * item['cost_price'];
                final profit = total - cost;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // معلومات المنتج
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // رقم المنتج
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // التفاصيل
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // الاسم والسعر
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['product_name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${total.toStringAsFixed(2)} ر.س',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 4),

                                  // الباركود
                                  if (item['barcode'] != null && item['barcode'].isNotEmpty)
                                    Text(
                                      'باركود: ${item['barcode']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),

                                  const SizedBox(height: 12),

                                  // التحكم في الكمية
                                  Row(
                                    children: [
                                      // أزرار الكمية
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey[300]!),
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 20),
                                              onPressed: () => _updateItemQuantity(index, item['quantity'] - 1),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                            Container(
                                              width: 40,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              alignment: Alignment.center,
                                              child: Text(
                                                item['quantity'].toString(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 20),
                                              onPressed: () => _updateItemQuantity(index, item['quantity'] + 1),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // السعر والربح
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item['unit_price'].toStringAsFixed(2)} × ${item['quantity']}',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            Text(
                                              'الربح: ${profit.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: profit > 0 ? Colors.green : Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // أزرار التحكم
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('تعديل السعر'),
                              onPressed: () => _editItem(index),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: BorderSide(color: Colors.blue.shade300),
                              ),
                            ),

                            const SizedBox(width: 8),

                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('حذف'),
                              onPressed: () => _removeItem(index),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  // 💾 زر الحفظ
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: _isSubmitting
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.save, size: 24),
        label: Text(
          _isSubmitting ? 'جاري حفظ الفاتورة...' : 'حفظ الفاتورة',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: _isSubmitting ? null : _saveInvoice,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  // 📊 دالة مساعدة لعرض الأسطر
  Widget _buildAmountRow(String label, String value, {
    Color? color,
    bool isBold = false,
    double fontSize = 16,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }

  // ✏️ دالة تعديل المنتج
  void _editItem(int index) {
    final item = _invoiceItems[index];
    final priceController = TextEditingController(
      text: item['unit_price'].toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل السعر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المنتج: ${item['product_name']}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'السعر الجديد',
                border: OutlineInputBorder(),
                prefixText: 'ريال ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text) ?? item['unit_price'];
              if (newPrice >= 0) {
                setState(() {
                  _invoiceItems[index]['unit_price'] = newPrice;
                });
                Navigator.pop(context);
                _showSuccess('✅ تم تحديث السعر');
              }
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}