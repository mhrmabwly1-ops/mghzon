import 'package:flutter/material.dart';
import '../database_helper.dart';

class WarehousesScreen extends StatefulWidget {
  @override
  _WarehousesScreenState createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _warehousesWithStats = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWarehousesWithStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehousesWithStats() async {
    try {
      // جلب المخازن
      final warehouses = await _dbHelper.getWarehouses();

      // جلب إحصائيات كل مخزن
      List<Map<String, dynamic>> warehousesWithStats = [];

      for (var warehouse in warehouses) {
        try {
          final stockInfo = await _dbHelper.getWarehouseStockSummary(warehouse['id']);
          final stockItems = await _dbHelper.getWarehouseStock(warehouse['id']);

          warehousesWithStats.add({
            ...warehouse,
            'stats': stockInfo,
            'products_count': stockItems.length,
            'total_quantity': stockInfo['total_quantity'] ?? 0,
            'total_value': stockInfo['total_value'] ?? 0.0,
          });
        } catch (e) {
          print('خطأ في تحميل إحصائيات المخزن ${warehouse['id']}: $e');
          warehousesWithStats.add({
            ...warehouse,
            'stats': {},
            'products_count': 0,
            'total_quantity': 0,
            'total_value': 0.0,
          });
        }
      }

      setState(() {
        _warehouses = warehouses;
        _warehousesWithStats = warehousesWithStats;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل المخازن: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showWarehouseStock(int warehouseId, String warehouseName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WarehouseStockDetailsScreen(
          warehouseId: warehouseId,
          warehouseName: warehouseName,
        ),
      ),
    );
  }

  void _showAddWarehouseDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddWarehouseDialog(
        onWarehouseAdded: _loadWarehousesWithStats,
      ),
    );
  }

  Future<void> _deleteWarehouse(int warehouseId, String warehouseName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "$warehouseName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteWarehouse(warehouseId);
        _showSnackBar('✅ تم حذف المخزن بنجاح');
        _loadWarehousesWithStats();
      } catch (e) {
        _showSnackBar('❌ خطأ في حذف المخزن');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _warehousesWithStats.where((w) => w['is_active'] == 1).length;
    final totalProducts = _warehousesWithStats.fold(0, (sum, w) => sum + (w['products_count'] as int?? 0));
    final totalValue = _warehousesWithStats.fold(0.0, (sum, w) => sum + (w['total_value'] ?? 0.0));

    return Scaffold(
      appBar: AppBar(
        title: Text('المخازن'),
        actions: [
          IconButton(
            icon: Icon(Icons.add, size: 24),
            onPressed: _showAddWarehouseDialog,
            tooltip: 'إضافة مخزن',
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 22),
            onPressed: _loadWarehousesWithStats,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // الإحصائيات الرئيسية
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildMainStatCard(
                      title: 'المخازن',
                      value: _warehousesWithStats.length.toString(),
                      icon: Icons.warehouse,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 12),
                    _buildMainStatCard(
                      title: 'المنتجات',
                      value: totalProducts.toString(),
                      icon: Icons.inventory,
                      color: Colors.green,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    _buildMainStatCard(
                      title: 'القيمة',
                      value: '${totalValue.toStringAsFixed(0)} ر.س',
                      icon: Icons.attach_money,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    _buildMainStatCard(
                      title: 'نشطة',
                      value: '$activeCount/${_warehousesWithStats.length}',
                      icon: Icons.check_circle,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // قائمة المخازن
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _warehousesWithStats.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warehouse_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد مخازن',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddWarehouseDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('إضافة مخزن جديد'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.only(bottom: 16),
              itemCount: _warehousesWithStats.length,
              itemBuilder: (context, index) {
                return _buildWarehouseCard(_warehousesWithStats[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseCard(Map<String, dynamic> warehouse) {
    final isActive = warehouse['is_active'] == 1;
    final name = warehouse['name'] ?? 'غير معروف';
    final stats = warehouse['stats'] ?? {};
    final productsCount = warehouse['products_count'] ?? 0;
    final totalQuantity = warehouse['total_quantity'] ?? 0;
    final totalValue = warehouse['total_value'] ?? 0.0;
    final lowStock = stats['low_stock_products'] ?? 0;
    final outOfStock = stats['out_of_stock_products'] ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // العنوان والتفاصيل
          ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warehouse,
                color: isActive ? Colors.green : Colors.red,
                size: 26,
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      isActive ? 'نشط' : 'غير نشط',
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
            onTap: () => _showWarehouseStock(warehouse['id'], name),
          ),

          // الإحصائيات
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStatItem('المنتجات', productsCount.toString(), Icons.inventory),
                _buildMiniStatItem('الكمية', totalQuantity.toString(), Icons.format_list_numbered),
                _buildMiniStatItem('القيمة', '${totalValue.toStringAsFixed(0)} ر.س', Icons.monetization_on),
                _buildMiniStatItem('منخفض', lowStock.toString(), Icons.warning, color: Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatItem(String title, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? Colors.blue),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.blue,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _AddWarehouseDialog extends StatefulWidget {
  final Map<String, dynamic>? warehouse;
  final Function onWarehouseAdded;

  const _AddWarehouseDialog({
    this.warehouse,
    required this.onWarehouseAdded,
  });

  @override
  __AddWarehouseDialogState createState() => __AddWarehouseDialogState();
}

class __AddWarehouseDialogState extends State<_AddWarehouseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _addressController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.warehouse != null;
    if (_isEditMode) {
      _nameController.text = widget.warehouse!['name'] ?? '';
      _codeController.text = widget.warehouse!['code'] ?? '';
      _addressController.text = widget.warehouse!['address'] ?? '';
      _isActive = widget.warehouse!['is_active'] == 1;
    }
  }

  Future<void> _saveWarehouse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final warehouseData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'is_active': _isActive ? 1 : 0,
      };

      int result;
      if (_isEditMode) {
        result = await _dbHelper.updateWarehouse(widget.warehouse!['id'], warehouseData);
      } else {
        result = await _dbHelper.insertWarehouse(warehouseData);
      }

      if (result > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '✅ تم تحديث المخزن' : '✅ تم إضافة المخزن'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onWarehouseAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode ? 'تعديل المخزن' : 'إضافة مخزن جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم المخزن',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) => value!.isEmpty ? 'يجب إدخال اسم المخزن' : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'الكود (اختياري)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'العنوان (اختياري)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),

              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value!),
                  ),
                  Text('المخزن نشط'),
                ],
              ),
              SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: Text('إلغاء'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveWarehouse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(_isEditMode ? 'تحديث' : 'إضافة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}

class WarehouseStockDetailsScreen extends StatefulWidget {
  final int warehouseId;
  final String warehouseName;

  const WarehouseStockDetailsScreen({
    required this.warehouseId,
    required this.warehouseName,
  });

  @override
  _WarehouseStockDetailsScreenState createState() => _WarehouseStockDetailsScreenState();
}

class _WarehouseStockDetailsScreenState extends State<WarehouseStockDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _filteredStockItems = [];
  bool _isLoading = true;
  Map<String, dynamic> _warehouseInfo = {};

  @override
  void initState() {
    super.initState();
    _loadWarehouseDetails();
    _searchController.addListener(_filterStockItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouseDetails() async {
    try {
      // جلب المخزون
      final stockItems = await _dbHelper.getWarehouseStock(widget.warehouseId);

      // جلب معلومات إضافية للمنتجات
      List<Map<String, dynamic>> enhancedStockItems = [];

      for (var item in stockItems) {
        try {
          // جلب تفاصيل المنتج من جدول products
          final products = await _dbHelper.getProducts();
          final product = products.firstWhere(
                (p) => p['id'] == item['product_id'],
            orElse: () => {},
          );

          // جلب معلومات المورد
          final suppliers = await _dbHelper.getSuppliers();
          final supplier = product['supplier_id'] != null
              ? suppliers.firstWhere(
                (s) => s['id'] == product['supplier_id'],
            orElse: () => {},
          )
              : {};

          enhancedStockItems.add({
            ...item,
            'product_details': product,
            'supplier_details': supplier,
            'purchase_price': product['purchase_price'] ?? 0.0,
            'sell_price': product['sell_price'] ?? 0.0,
            'supplier_name': supplier['name'] ?? 'غير معروف',
            'unit': product['unit'] ?? 'قطعة',
          });
        } catch (e) {
          print('خطأ في تحميل تفاصيل المنتج ${item['product_id']}: $e');
          enhancedStockItems.add({
            ...item,
            'product_details': {},
            'supplier_details': {},
            'purchase_price': 0.0,
            'sell_price': 0.0,
            'supplier_name': 'غير معروف',
            'unit': 'قطعة',
          });
        }
      }

      // جلب إحصائيات المخزن
      final warehouseStats = await _dbHelper.getWarehouseStockSummary(widget.warehouseId);

      setState(() {
        _stockItems = enhancedStockItems;
        _filteredStockItems = enhancedStockItems;
        _warehouseInfo = warehouseStats;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل تفاصيل المخزن: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterStockItems() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredStockItems = _stockItems);
    } else {
      setState(() {
        _filteredStockItems = _stockItems.where((item) {
          final name = item['product_name']?.toString().toLowerCase() ?? '';
          final barcode = item['barcode']?.toString().toLowerCase() ?? '';
          final supplier = item['supplier_name']?.toString().toLowerCase() ?? '';
          return name.contains(query) || barcode.contains(query) || supplier.contains(query);
        }).toList();
      });
    }
  }

  double get _totalValue {
    return _filteredStockItems.fold(0.0, (sum, item) {
      final quantity = item['quantity'] ?? 0;
      final sellPrice = item['sell_price'] ?? 0.0;
      return sum + (quantity * sellPrice);
    });
  }

  double get _totalCost {
    return _filteredStockItems.fold(0.0, (sum, item) {
      final quantity = item['quantity'] ?? 0;
      final purchasePrice = item['purchase_price'] ?? 0.0;
      return sum + (quantity * purchasePrice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _filteredStockItems.length;
    final lowStock = _filteredStockItems.where((item) {
      final quantity = item['quantity'] ?? 0;
      final min = item['min_stock_level'] ?? 0;
      return quantity <= min && quantity > 0;
    }).length;
    final outOfStock = _filteredStockItems.where((item) => (item['quantity'] ?? 0) == 0).length;
    final potentialProfit = _totalValue - _totalCost;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.warehouseName),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 22),
            onPressed: _loadWarehouseDetails,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // الإحصائيات الرئيسية
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildDetailStatCard(
                      title: 'المنتجات',
                      value: totalItems.toString(),
                      subtitle: '${_warehouseInfo['total_products'] ?? 0} منتج',
                      color: Colors.blue,
                    ),
                    SizedBox(width: 12),
                    _buildDetailStatCard(
                      title: 'الكمية',
                      value: (_warehouseInfo['total_quantity'] ?? 0).toString(),
                      subtitle: 'قطعة',
                      color: Colors.green,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    _buildDetailStatCard(
                      title: 'القيمة',
                      value: '${_totalValue.toStringAsFixed(0)} ر.س',
                      subtitle: 'الربح: ${potentialProfit.toStringAsFixed(0)} ر.س',
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    _buildDetailStatCard(
                      title: 'المخزون',
                      value: '${lowStock + outOfStock}',
                      subtitle: '$lowStock منخفض • $outOfStock نفذ',
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // شريط البحث
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث في المخزون...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),

          // قائمة المنتجات
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredStockItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 60,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد منتجات في المخزون',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.only(bottom: 16),
              itemCount: _filteredStockItems.length,
              itemBuilder: (context, index) {
                return _buildProductItem(_filteredStockItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 0;
    final minStock = item['min_stock_level'] ?? 0;
    final isLow = quantity <= minStock && quantity > 0;
    final isOut = quantity == 0;
    final purchasePrice = item['purchase_price'] ?? 0.0;
    final sellPrice = item['sell_price'] ?? 0.0;
    final profit = sellPrice - purchasePrice;
    final supplierName = item['supplier_name'] ?? 'غير معروف';
    final unit = item['unit'] ?? 'قطعة';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getStockColor(isOut, isLow).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: _getStockColor(isOut, isLow),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name'] ?? 'غير معروف',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStockColor(isOut, isLow),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _getStockStatus(isOut, isLow, minStock),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getStockColor(isOut, isLow),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$quantity $unit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStockColor(isOut, isLow),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'المخزون',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // التفاصيل
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildProductDetailItem('الشراء', '${purchasePrice.toStringAsFixed(0)} ر.س', Colors.blueGrey),
                    _buildProductDetailItem('البيع', '${sellPrice.toStringAsFixed(0)} ر.س', Colors.green),
                    _buildProductDetailItem('الربح', '${profit.toStringAsFixed(0)} ر.س',
                        profit >= 0 ? Colors.teal : Colors.red),
                  ],
                ),
                SizedBox(height: 8),
                if (item['barcode'] != null)
                  Text(
                    'باركود: ${item['barcode']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                SizedBox(height: 4),
                Text(
                  'المورد: $supplierName',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetailItem(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getStockColor(bool isOut, bool isLow) {
    if (isOut) return Colors.red;
    if (isLow) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatus(bool isOut, bool isLow, int minStock) {
    if (isOut) return 'نفذ من المخزون';
    if (isLow) return 'منخفض (الحد: $minStock)';
    return 'ممتاز';
  }
}