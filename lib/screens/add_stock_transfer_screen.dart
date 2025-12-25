import 'package:flutter/material.dart';

import '../database_helper.dart';

class AddStockTransferScreen extends StatefulWidget {
  @override
  _AddStockTransferScreenState createState() => _AddStockTransferScreenState();
}

class _AddStockTransferScreenState extends State<AddStockTransferScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _products = [];

  int? _selectedFromWarehouseId;
  int? _selectedToWarehouseId;
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final warehouses = await _dbHelper.getWarehouses();
      setState(() {
        _warehouses = warehouses;
      });
    } catch (e) {
      _showError('فشل في تحميل البيانات: $e');
    }
  }

  Future<void> _loadFromWarehouseProducts() async {
    if (_selectedFromWarehouseId == null) return;

    setState(() {
      _products = [];
      _items = [];
    });

    try {
      final products = await _dbHelper.getWarehouseStockForTransfer(_selectedFromWarehouseId!);
      setState(() {
        _products = products;
      });
    } catch (e) {
      _showError('فشل في تحميل منتجات المخزن المصدر: $e');
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

  void _addItem(int productId, int quantity) {
    setState(() {
      final product = _products.firstWhere((p) => p['id'] == productId);
      final existingIndex = _items.indexWhere((item) => item['product_id'] == productId);

      if (existingIndex != -1) {
        _items[existingIndex]['quantity'] = quantity;
      } else {
        _items.add({
          'product_id': productId,
          'product_name': product['name'],
          'quantity': quantity,
        });
      }
    });
  }

  void _removeItem(int productId) {
    setState(() {
      _items.removeWhere((item) => item['product_id'] == productId);
    });
  }

  Future<void> _submitTransfer() async {
    if (_selectedFromWarehouseId == null) {
      _showError('يرجى اختيار المخزن المصدر');
      return;
    }

    if (_selectedToWarehouseId == null) {
      _showError('يرجى اختيار المخزن الهدف');
      return;
    }

    if (_selectedFromWarehouseId == _selectedToWarehouseId) {
      _showError('لا يمكن تحويل المنتجات لنفس المخزن');
      return;
    }

    if (_items.isEmpty) {
      _showError('يرجى إضافة منتجات على الأقل');
      return;
    }

    final transfer = {
      'from_warehouse_id': _selectedFromWarehouseId,
      'to_warehouse_id': _selectedToWarehouseId,
      'notes': _notes,
      'transfer_date': DateTime.now().toIso8601String(),
      'status': 'draft',
    };

    final result = await _dbHelper.createStockTransferWithItems(transfer, _items);

    if (result['success']) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء تحويل المخزون بنجاح - رقم: ${result['transfer_number']}'),
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
        title: Text('إضافة تحويل مخزون'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _submitTransfer,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // معلومات التحويل الأساسية
              _buildBasicInfo(),
              SizedBox(height: 20),

              // قائمة المنتجات
              _buildProductsList(),

              // المنتجات المضافة
              if (_items.isNotEmpty) ...[
                SizedBox(height: 20),
                _buildSelectedItems(),
              ],
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedFromWarehouseId,
                    decoration: InputDecoration(
                      labelText: 'المخزن المصدر',
                      border: OutlineInputBorder(),
                    ),
                    items: _warehouses.map((warehouse) {
                      return DropdownMenuItem<int>(
                        value: warehouse['id'],
                        child: Text(warehouse['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFromWarehouseId = value;
                      });
                      _loadFromWarehouseProducts();
                    },
                    validator: (value) {
                      if (value == null) return 'يرجى اختيار المخزن المصدر';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.arrow_forward, color: Colors.blue),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedToWarehouseId,
                    decoration: InputDecoration(
                      labelText: 'المخزن الهدف',
                      border: OutlineInputBorder(),
                    ),
                    items: _warehouses.map((warehouse) {
                      return DropdownMenuItem<int>(
                        value: warehouse['id'],
                        child: Text(warehouse['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedToWarehouseId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) return 'يرجى اختيار المخزن الهدف';
                      return null;
                    },
                  ),
                ),
              ],
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

  Widget _buildProductsList() {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'منتجات المخزن المصدر',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              _products.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      _selectedFromWarehouseId == null
                          ? 'يرجى اختيار المخزن المصدر'
                          : 'لا توجد منتجات في المخزن المصدر',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final currentQty = product['current_quantity'] ?? 0;
                    final existingItem = _items.firstWhere(
                          (item) => item['product_id'] == product['id'],
                      orElse: () => {},
                    );

                    return ProductTransferItem(
                      product: product,
                      currentQuantity: currentQty,
                      onQuantityChanged: (qty) => _addItem(product['id'], qty),
                      onRemove: () => _removeItem(product['id']),
                      isSelected: existingItem.isNotEmpty,
                      selectedQuantity: existingItem.isNotEmpty ? existingItem['quantity'] : 0,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedItems() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المنتجات المحددة (${_items.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ..._items.map((item) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  item['quantity'].toString(),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              title: Text(item['product_name']),
              subtitle: Text('الكمية: ${item['quantity']}'),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(item['product_id']),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class ProductTransferItem extends StatefulWidget {
  final Map<String, dynamic> product;
  final int currentQuantity;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;
  final bool isSelected;
  final int selectedQuantity;

  const ProductTransferItem({
    Key? key,
    required this.product,
    required this.currentQuantity,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.isSelected,
    required this.selectedQuantity,
  }) : super(key: key);

  @override
  _ProductTransferItemState createState() => _ProductTransferItemState();
}

class _ProductTransferItemState extends State<ProductTransferItem> {
  final TextEditingController _quantityController = TextEditingController();
  int _transferQuantity = 0;

  @override
  void initState() {
    super.initState();
    _transferQuantity = widget.selectedQuantity;
    _quantityController.text = _transferQuantity.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: widget.isSelected ? Colors.blue : Colors.grey,
          child: Text(
            widget.product['name'][0],
            style: TextStyle(color: Colors.white),
          ),
        ),
        title: Text(widget.product['name']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المخزون المتاح: ${widget.currentQuantity}'),
            if (widget.product['min_stock_level'] > 0)
              Text('الحد الأدنى: ${widget.product['min_stock_level']}'),
          ],
        ),
        trailing: Container(
          width: 150,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الكمية',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onChanged: (value) {
                    final qty = int.tryParse(value) ?? 0;
                    final maxQty = widget.currentQuantity;

                    if (qty > maxQty) {
                      _quantityController.text = maxQty.toString();
                      _transferQuantity = maxQty;
                    } else {
                      _transferQuantity = qty;
                    }

                    if (_transferQuantity > 0) {
                      widget.onQuantityChanged(_transferQuantity);
                    }
                  },
                ),
              ),
              if (widget.isSelected)
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}