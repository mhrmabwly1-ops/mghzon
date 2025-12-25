import 'dart:io';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'add_product_screen.dart';
import 'color.dart';
import 'database_helper.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedSupplier = 'all';
  String _selectedStockStatus = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _dbHelper.getProductsWithDetails();
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('خطأ في تحميل المنتجات: $e', isError: true);
    }
  }

  void _filterProducts() {
    List<Map<String, dynamic>> filtered = _products;

    // البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        final barcode = product['barcode']?.toString().toLowerCase() ?? '';
        final supplierName = product['supplier_name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return name.contains(query) ||
            barcode.contains(query) ||
            supplierName.contains(query);
      }).toList();
    }

    // تصفية الفئة
    if (_selectedCategory != 'all' && _selectedCategory.isNotEmpty) {
      filtered = filtered.where((product) {
        return product['category_name']?.toString() == _selectedCategory;
      }).toList();
    }

    // تصفية المورد
    if (_selectedSupplier != 'all' && _selectedSupplier.isNotEmpty) {
      filtered = filtered.where((product) {
        return product['supplier_name']?.toString() == _selectedSupplier;
      }).toList();
    }

    // تصفية حالة المخزون
    if (_selectedStockStatus != 'all') {
      filtered = filtered.where((product) {
        final quantity = product['current_quantity'] ?? 0;
        final minStock = product['min_stock_level'] ?? 0;

        switch (_selectedStockStatus) {
          case 'in_stock':
            return quantity > 0;
          case 'low_stock':
            return quantity > 0 && quantity <= minStock;
          case 'out_of_stock':
            return quantity == 0;
          case 'normal_stock':
            return quantity > minStock;
          default:
            return true;
        }
      }).toList();
    }

    // الترتيب
    filtered.sort((a, b) {
      dynamic valueA, valueB;

      switch (_sortBy) {
        case 'name':
          valueA = a['name']?.toString().toLowerCase();
          valueB = b['name']?.toString().toLowerCase();
          break;
        case 'sell_price':
          valueA = a['sell_price'] ?? 0.0;
          valueB = b['sell_price'] ?? 0.0;
          break;
        case 'purchase_price':
          valueA = a['purchase_price'] ?? 0.0;
          valueB = b['purchase_price'] ?? 0.0;
          break;
        case 'stock':
          valueA = a['current_quantity'] ?? 0;
          valueB = b['current_quantity'] ?? 0;
          break;
        case 'barcode':
          valueA = a['barcode']?.toString().toLowerCase() ?? '';
          valueB = b['barcode']?.toString().toLowerCase() ?? '';
          break;
        case 'supplier':
          valueA = a['supplier_name']?.toString().toLowerCase() ?? '';
          valueB = b['supplier_name']?.toString().toLowerCase() ?? '';
          break;
        case 'profit':
          valueA = (a['sell_price'] ?? 0.0) - (a['purchase_price'] ?? 0.0);
          valueB = (b['sell_price'] ?? 0.0) - (b['purchase_price'] ?? 0.0);
          break;
        default:
          valueA = a['name']?.toString().toLowerCase();
          valueB = b['name']?.toString().toLowerCase();
      }

      if (valueA == valueB) return 0;
      return _sortAscending ? valueA.compareTo(valueB) : valueB.compareTo(valueA);
    });

    setState(() => _filteredProducts = filtered);
  }

  List<String> _getCategories() {
    final categories = _products
        .map((p) => p['category_name']?.toString())
        .where((cat) => cat != null && cat.isNotEmpty)
        .toSet()
        .toList()
        .cast<String>();

    categories.sort();
    categories.insert(0, 'all');
    return categories;
  }

  List<String> _getSuppliers() {
    final suppliers = _products
        .map((p) => p['supplier_name']?.toString())
        .where((sup) => sup != null && sup.isNotEmpty)
        .toSet()
        .toList()
        .cast<String>();

    suppliers.sort();
    suppliers.insert(0, 'all');
    return suppliers;
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteProduct(int productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "$productName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _dbHelper.deleteProduct(productId);
        if (result > 0) {
          _showSnackBar('تم حذف المنتج', isError: false);
          _loadProducts();
        }
      } catch (e) {
        _showSnackBar('خطأ في الحذف: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar()  {
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.inventory_2, size: 24),
          SizedBox(width: 8),
          Text('إدارة المنتجات', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(width: 8),
          badges.Badge(
            badgeContent: Text(_filteredProducts.length.toString(),
                style: TextStyle(fontSize: 10)),
            child: SizedBox(),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list, color: _showFilters ? Colors.amber : Colors.white),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          tooltip: 'الفلاتر',
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadProducts,
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // شريط البحث
        _buildSearchBar(),

        // بطاقات الإحصائيات
        _buildStatsCards(),

        // الفلاتر (مخفية/مرئية)
        if (_showFilters) _buildFiltersPanel(),

        // قائمة المنتجات
        Expanded(child: _buildProductsList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _filterProducts();
                },
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
              onPressed: () => _showSnackBar('مسح باركود', isError: false),
              tooltip: 'مسح باركود',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = _calculateStats();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(
            title: 'المنتجات',
            value: stats['total'].toString(),
            icon: Icons.inventory,
            color: AppColors.primary,
            subtitle: '${_filteredProducts.length} / ${_products.length}',
          ),
          SizedBox(width: 8),
          _buildStatCard(
            title: 'المخزون',
            value: stats['stock'].toString(),
            icon: Icons.storage,
            color: Colors.green,
            subtitle: 'منخفض: ${stats['low']}',
          ),
          SizedBox(width: 8),
          _buildStatCard(
            title: 'القيمة',
            value: '${(stats['value'] as double).toStringAsFixed(0)} ر.س',
            icon: Icons.attach_money,
            color: Colors.orange,
            subtitle: 'متوسط: ${(stats['avgValue'] as double).toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String subtitle = '',
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: TextStyle(fontSize: 8, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, size: 18, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text('الفلاتر', style: TextStyle(fontWeight: FontWeight.w600)),
                Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'all';
                      _selectedSupplier = 'all';
                      _selectedStockStatus = 'all';
                      _filterProducts();
                    });
                  },
                  child: Text('إعادة تعيين', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            SizedBox(height: 12),

            // الفلاتر الأساسية
            _buildFilterRow('الفئة:', _buildCategoryFilter()),
            SizedBox(height: 8),
            _buildFilterRow('المورد:', _buildSupplierFilter()),
            SizedBox(height: 8),
            _buildFilterRow('المخزون:', _buildStockFilter()),
            SizedBox(height: 8),
            _buildFilterRow('الترتيب:', _buildSortOptions()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(String label, Widget filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        SizedBox(height: 4),
        filter,
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('all', 'الكل', _selectedCategory),
          ..._getCategories().where((cat) => cat != 'all').map((cat) {
            return Padding(
              padding: EdgeInsets.only(right: 4),
              child: _buildFilterChip(cat, cat, _selectedCategory),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSupplierFilter() {
    return Container(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('all', 'الكل', _selectedSupplier),
          ..._getSuppliers().where((sup) => sup != 'all').take(5).map((sup) {
            return Padding(
              padding: EdgeInsets.only(right: 4),
              child: _buildFilterChip(sup, sup, _selectedSupplier),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStockFilter() {
    final options = [
      {'value': 'all', 'label': 'الكل'},
      {'value': 'in_stock', 'label': 'متوفر'},
      {'value': 'out_of_stock', 'label': 'نفذ'},
      {'value': 'low_stock', 'label': 'منخفض'},
    ];

    return Container(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.map((opt) {
          return Padding(
            padding: EdgeInsets.only(right: 4),
            child: _buildFilterChip(opt['value']!, opt['label']!, _selectedStockStatus),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortOptions() {
    final options = [
      {'value': 'name', 'label': 'الاسم', 'icon': Icons.text_fields},
      {'value': 'stock', 'label': 'المخزون', 'icon': Icons.inventory},
      {'value': 'sell_price', 'label': 'البيع', 'icon': Icons.sell},
      {'value': 'profit', 'label': 'الربح', 'icon': Icons.trending_up},
    ];

    return Container(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.map((opt) {
          return Padding(
            padding: EdgeInsets.only(right: 4),
            child: _buildSortChip(opt['value'] as String, opt['label']! as String, opt['icon']!as IconData),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, String selected) {
    final isSelected = selected == value;

    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        if (value == 'all') {
          _selectedCategory = 'all';
          _selectedSupplier = 'all';
          _selectedStockStatus = 'all';
        } else {
          // تحديد أي قيمة تم الضغط عليها
          if (_getCategories().contains(value)) {
            _selectedCategory = value;
          } else if (_getSuppliers().contains(value)) {
            _selectedSupplier = value;
          } else {
            _selectedStockStatus = value;
          }
        }
        _filterProducts();
      },
      backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : Colors.grey[700]),
      shape: StadiumBorder(side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey),
    ));
  }

  Widget _buildSortChip(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;

    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 11)),
      avatar: Icon(icon, size: 14,
          color: isSelected ? AppColors.primary : Colors.grey[600]),
      onPressed: () {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
        });
        _filterProducts();
      },
      backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
      shape: StadiumBorder(side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey)),
    );
  }

  Widget _buildProductsList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: AppColors.primary,
      child: ListView.separated(
        padding: EdgeInsets.all(12),
        itemCount: _filteredProducts.length,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _buildProductCard(_filteredProducts[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text('لا توجد منتجات',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          SizedBox(height: 8),
          Text('قم بإضافة منتجات أو تغيير الفلاتر',
              style: TextStyle(color: Colors.grey[500])),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddProductScreen())
            ).then((_) => _loadProducts()),
            icon: Icon(Icons.add, size: 18),
            label: Text('إضافة منتج جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final quantity = product['current_quantity'] ?? 0;
    final minStock = product['min_stock_level'] ?? 0;
    final purchasePrice = product['purchase_price'] ?? 0.0;
    final sellPrice = product['sell_price'] ?? 0.0;
    final profit = sellPrice - purchasePrice;
    final isLowStock = quantity > 0 && quantity <= minStock;
    final isOutOfStock = quantity == 0;

    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة المنتج
              _buildProductImage(product),
              SizedBox(width: 12),

              // معلومات المنتج
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الصف الأول: الاسم والحالة
                    Row(
                      children: [
                        Expanded(
                          child: Text(product['name'] ?? 'غير معروف',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(width: 8),
                        _buildStockBadge(quantity, minStock, isLowStock, isOutOfStock),
                      ],
                    ),

                    SizedBox(height: 4),

                    // الصف الثاني: الباركود والفئة
                    Text('${product['barcode'] ?? 'بدون باركود'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    if (product['category_name'] != null)
                      Text(product['category_name'] ?? '',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),

                    SizedBox(height: 8),

                    // الصف الثالث: الأسعار والأرباح
                    Row(
                      children: [
                        _buildPriceChip(
                          'شراء',
                          '${purchasePrice.toStringAsFixed(0)} ر.س',
                          Colors.blueGrey,
                        ),
                        SizedBox(width: 6),
                        _buildPriceChip(
                          'بيع',
                          '${sellPrice.toStringAsFixed(0)} ر.س',
                          Colors.green,
                        ),
                        SizedBox(width: 6),
                        _buildPriceChip(
                          'ربح',
                          '${profit.toStringAsFixed(0)} ر.س',
                          profit >= 0 ? Colors.teal : Colors.red,
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // الصف الرابع: المخزون والمورد
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.inventory, size: 12, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text('$quantity ${product['unit']}',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        if (product['supplier_name'] != null)
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 12, color: Colors.grey[600]),
                                SizedBox(width: 4),
                                Text(product['supplier_name'] ?? '',
                                    style: TextStyle(fontSize: 11,
                                        color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // القائمة المنبثقة
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('التفاصيل'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'movements',
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('الحركات'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'details':
                      _showProductDetails(product);
                      break;
                    case 'edit':
                      _editProduct(product);
                      break;
                    case 'movements':
                      _showProductMovements(product);
                      break;
                    case 'delete':
                      _deleteProduct(product['id'], product['name']);
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final imagePath = product['image_path'];

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.primary.withOpacity(0.05),
      ),
      child: (imagePath != null && imagePath.isNotEmpty)
          ? ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
        ),
      )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Icon(Icons.inventory_2, color: AppColors.primary.withOpacity(0.3)),
    );
  }

  Widget _buildStockBadge(int quantity, int minStock, bool isLowStock, bool isOutOfStock) {
    Color color;
    String text;

    if (isOutOfStock) {
      color = Colors.red;
      text = 'نفذ';
    } else if (isLowStock) {
      color = Colors.orange;
      text = 'منخفض';
    } else {
      color = Colors.green;
      text = 'جيد';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPriceChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w500)),
          SizedBox(height: 1),
          Text(value,
              style: TextStyle(fontSize: 9, color: Colors.grey[800], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddProductScreen()),
      ).then((_) => _loadProducts()),
      icon: Icon(Icons.add, color: Colors.white),
      label: Text('إضافة', style: TextStyle(color: Colors.white)),
      backgroundColor: AppColors.primary,
      elevation: 2,
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProductDetailsBottomSheet(product: product),
    );
  }

  void _editProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(), // TODO: يمكن إضافة شاشة تعديل
      ),
    ).then((_) => _loadProducts());
  }

  void _showProductMovements(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => ProductMovementsDialog(product: product),
    );
  }

  Map<String, dynamic> _calculateStats() {
    final int total = _filteredProducts.length;

    final int stock = _filteredProducts.fold<int>(
      0,
          (sum, p) {
        final qty = p['current_quantity'];
        if (qty is num) {
          return sum + qty.toInt();
        }
        return sum;
      },
    );

    final double value = _filteredProducts.fold<double>(
      0.0,
          (sum, p) {
        final qty = p['current_quantity'];
        final price = p['purchase_price'];

        final double q = qty is num ? qty.toDouble() : 0.0;
        final double pr = price is num ? price.toDouble() : 0.0;

        return sum + (q * pr);
      },
    );

    final int low = _filteredProducts.where((p) {
      final qty = p['current_quantity'];
      final min = p['min_stock_level'];

      final int q = qty is num ? qty.toInt() : 0;
      final int m = min is num ? min.toInt() : 0;

      return q > 0 && q <= m;
    }).length;

    final double avgValue = total > 0 ? value / total : 0.0;

    return {
      'total': total,
      'stock': stock,
      'value': value,
      'low': low,
      'avgValue': avgValue,
    };
  }

}

class ProductDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> product;

  ProductDetailsBottomSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // المؤشر العلوي
              Container(
                margin: EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // العنوان
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('تفاصيل المنتج',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              Divider(height: 20),

              // المحتوى
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // معلومات عامة
                      _buildDetailSection('معلومات المنتج', [
                        _buildDetailRow('الاسم', product['name'] ?? 'غير معروف'),
                        _buildDetailRow('الباركود', product['barcode'] ?? 'بدون'),
                        _buildDetailRow('الفئة', product['category_name'] ?? 'بدون'),
                        _buildDetailRow('المورد', product['supplier_name'] ?? 'بدون'),
                        _buildDetailRow('الوحدة', product['unit'] ?? 'قطعة'),
                        if (product['description'] != null)
                          _buildDetailRow('الوصف', product['description']),
                      ]),

                      SizedBox(height: 20),

                      // التسعير
                      _buildDetailSection('التسعير', [
                        _buildDetailRow('سعر الشراء',
                            '${(product['purchase_price'] ?? 0.0).toStringAsFixed(2)} ر.س'),
                        _buildDetailRow('سعر البيع',
                            '${(product['sell_price'] ?? 0.0).toStringAsFixed(2)} ر.س'),
                        _buildDetailRow('الربح',
                            '${((product['sell_price'] ?? 0.0) - (product['purchase_price'] ?? 0.0)).toStringAsFixed(2)} ر.س'),
                      ]),

                      SizedBox(height: 20),

                      // المخزون
                      _buildDetailSection('المخزون', [
                        _buildDetailRow('الكمية الحالية',
                            '${product['current_quantity'] ?? 0} ${product['unit']}'),
                        _buildDetailRow('الحد الأدنى',
                            '${product['min_stock_level'] ?? 0} ${product['unit']}'),
                        _buildDetailRow('الكمية الأولية',
                            '${product['initial_quantity'] ?? 0} ${product['unit']}'),
                      ]),

                      SizedBox(height: 20),

                      // معلومات إضافية
                      _buildDetailSection('معلومات إضافية', [
                        _buildDetailRow('تاريخ الإضافة',
                            _formatDate(product['created_at'])),
                        _buildDetailRow('آخر تحديث',
                            _formatDate(product['updated_at'])),
                      ]),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.primary)),
        SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text('$label:',
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'غير معروف';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

class ProductMovementsDialog extends StatelessWidget {
  final Map<String, dynamic> product;

  ProductMovementsDialog({required this.product});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.history, color: AppColors.primary),
          SizedBox(width: 8),
          Text('حركات المنتج'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TODO: جلب وعرض حركات المنتج
            Container(
              height: 200,
              child: Center(
                child: Text('قائمة الحركات ستظهر هنا'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إغلاق'),
        ),
      ],
    );
  }
}