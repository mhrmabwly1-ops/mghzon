import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

import 'color.dart';
import 'database_helper.dart';

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers للنص
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _initialQuantityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _customUnit = false;

  // البيانات الثابتة
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _warehouses = [];

  // القيم المختارة
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  int? _selectedWarehouseId;
  String _selectedUnit = 'قطعة';
  String _customUnitValue = '';

  // وحدات القياس القياسية
  final List<String> _units = [
    'قطعة',
    'كيلو',
    'جرام',
    'لتر',
    'متر',
    'علبة',
    'كرتون',
    'زجاجة',
    'طقم',
    'كراس',
    'دزينة'
  ];

  @override
  void initState() {
    super.initState();
    _generateBarcode();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      print('🔄 جاري تحميل البيانات الأولية...');

      final categories = await _dbHelper.getCategories();
      final suppliers = await _dbHelper.getSuppliers();
      final warehouses = await _dbHelper.getWarehouses();

      print('📊 عدد الفئات: ${categories.length}');
      print('📊 عدد الموردين: ${suppliers.length}');
      print('📊 عدد المخازن: ${warehouses.length}');

      setState(() {
        _categories = categories;
        _suppliers = suppliers;
        _warehouses = warehouses;

        // تحديد القيم الافتراضية
        if (warehouses.isNotEmpty) _selectedWarehouseId = warehouses.first['id'];
        if (categories.isNotEmpty) _selectedCategoryId = categories.first['id'];
        if (suppliers.isNotEmpty) _selectedSupplierId = suppliers.first['id'];
      });

      // إذا لم تكن هناك فئات، أضف فئة افتراضية
      if (_categories.isEmpty) {
        print('➕ إضافة فئة افتراضية "عام"...');
        await _addDefaultCategory();
        // إعادة تحميل الفئات
        final newCategories = await _dbHelper.getCategories();
        setState(() {
          _categories = newCategories;
          if (newCategories.isNotEmpty) _selectedCategoryId = newCategories.first['id'];
        });
      }

    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
      _showSnackBar('خطأ في تحميل البيانات: $e', isError: true);
    }
  }

  Future<void> _addDefaultCategory() async {
    try {
      await _dbHelper.insertCategory({
        'name': 'عام',
        'description': 'فئة عامة',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ تمت إضافة الفئة الافتراضية بنجاح');
    } catch (e) {
      print('❌ خطأ في إضافة الفئة الافتراضية: $e');
    }
  }

  Future<void> _addNewCategory(String name, String description) async {
    try {
      print('➕ جاري إضافة فئة جديدة: $name');

      final newCategoryId = await _dbHelper.insertCategory({
        'name': name.trim(),
        'description': description.trim(),
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      print(' تمت إضافة الفئة برقم: $newCategoryId');

      // تحديث القائمة
      final updatedCategories = await _dbHelper.getCategories();
      setState(() {
        _categories = updatedCategories;
        _selectedCategoryId = newCategoryId; // اختيار الفئة الجديدة
      });

      _showSnackBar('تمت إضافة الفئة "$name" بنجاح', isError: false);

    } catch (e) {
      print('❌ خطأ في إضافة الفئة: $e');
      _showSnackBar('خطأ في إضافة الفئة: $e', isError: true);
      rethrow;
    }
  }

  void _generateBarcode() {
    final newBarcode = 'PRD${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() {
      _barcodeController.text = newBarcode;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        final fileSize = await pickedFile.length();
        if (fileSize > 2 * 1024 * 1024) { // 2MB
          _showSnackBar('حجم الصورة كبير جداً (الحد الأقصى 2MB)', isError: true);
          return;
        }

        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showSnackBar('خطأ في تحميل الصورة: $e', isError: true);
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
    });
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    return null;
  }

  String? _validatePrice(String? value, String fieldName) {
    if (value == null || value.isEmpty) return 'يرجى إدخال $fieldName';
    final price = double.tryParse(value);
    if (price == null) return 'يجب أن يكون $fieldName رقم';
    if (price < 0) return 'يجب أن يكون $fieldName رقم موجب';
    return null;
  }

  String? _validateQuantity(String? value, String fieldName, {bool required = false}) {
    if (!required && (value == null || value.isEmpty)) return null;
    if (required && (value == null || value.isEmpty)) return 'يرجى إدخال $fieldName';

    final quantity = int.tryParse(value!);
    if (quantity == null) return 'يجب أن يكون $fieldName رقم صحيح';
    if (quantity < 0) return 'يجب أن يكون $fieldName رقم موجب';
    return null;
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplierId == null) {
      _showSnackBar('يرجى اختيار المورد', isError: true);
      return;
    }

    if (_selectedCategoryId == null) {
      _showSnackBar('يرجى اختيار الفئة', isError: true);
      return;
    }

    if (_selectedWarehouseId == null) {
      _showSnackBar('يرجى اختيار المخزن', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final unitToSave = _customUnit ? _customUnitValue : _selectedUnit;
      final quantity = int.tryParse(_initialQuantityController.text) ?? 0;
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;

      final productData = {
        'name': _nameController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': _selectedCategoryId,
        'supplier_id': _selectedSupplierId,
        'unit': unitToSave,
        'purchase_price': purchasePrice,
        'sell_price': double.tryParse(_sellPriceController.text) ?? 0.0,
        'min_stock_level': int.tryParse(_minStockController.text) ?? 0,
        'initial_quantity': quantity,
        'current_quantity': quantity,
        'image_path': _imageFile?.path ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final productId = await _dbHelper.insertProduct(productData);

      if (productId > 0) {
        // تحديث مخزون المخزن
        if (quantity > 0) {
          await _dbHelper.updateWarehouseStock(
            _selectedWarehouseId!,
            productId,
            quantity,
          );
        }

        // تحديث رصيد المورد إذا كان هناك سعر شراء
        if (quantity > 0 && purchasePrice > 0) {
          final totalPurchaseAmount = quantity * purchasePrice;

          // تحديث رصيد المورد
          await _dbHelper.updateSupplierBalance(
            _selectedSupplierId!,
            totalPurchaseAmount,
            true, // زيادة
          );
        }

        // تسجيل في سجل التدقيق
        await _logAuditAction('ADD_PRODUCT', 'products', productId,
            'تم إضافة منتج جديد: ${_nameController.text.trim()}');

        _showSnackBar('تم إضافة المنتج بنجاح', isError: false);
        await Future.delayed(Duration(milliseconds: 500));
        Navigator.pop(context, true);
      } else {
        _showSnackBar('❌ فشل في إضافة المنتج');
      }
    } catch (e) {
      _showSnackBar('❌ خطأ: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logAuditAction(String action, String tableName, int recordId, String description) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('audit_log', {
        'user_id': 1,
        'action': action,
        'table_name': tableName,
        'record_id': recordId,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging audit: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // دالة لإضافة فئة جديدة
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle, color: Colors.blue),
            SizedBox(width: 8),
            Text('إضافة فئة جديدة'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الفئة *',
                  hintText: 'أدخل اسم الفئة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                autofocus: true,
              ),
              SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'الوصف (اختياري)',
                  hintText: 'وصف الفئة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showSnackBar('يرجى إدخال اسم الفئة', isError: true);
                return;
              }

              try {
                Navigator.pop(context); // إغلاق الديالوج أولاً

                // إضافة الفئة
                await _addNewCategory(
                  nameController.text.trim(),
                  descriptionController.text.trim(),
                );

              } catch (e) {
                // الخطأ سيعرض في _addNewCategory
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'صورة المنتج',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  ' (اختياري)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 12),

            if (_imageFile == null)
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[400]),
                      SizedBox(height: 8),
                      Text(
                        'اضغط لإضافة صورة',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الحجم الأقصى: 2MB',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library, size: 18),
                    label: Text('المعرض', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt, size: 18),
                    label: Text('الكاميرا', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            if (required)
              Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
        SizedBox(height: 6),
        child,
        SizedBox(height: 4),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'المعلومات الأساسية',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // اسم المنتج
            _buildField(
              label: 'اسم المنتج',
              required: true,
              child: TextFormField(
                controller: _nameController,
                validator: (value) => _validateRequired(value, 'اسم المنتج'),
                decoration: InputDecoration(
                  hintText: 'أدخل اسم المنتج',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue, width: 1.5),
                  ),
                ),
                style: TextStyle(fontSize: 15, color: Colors.black),
              ),
            ),

            SizedBox(height: 12),

            // الباركود مع زر التوليد
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildField(
                    label: 'الباركود',
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        hintText: 'باركود المنتج',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue, width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 15, color: Colors.black),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.only(top: 22),
                    child: ElevatedButton(
                      onPressed: _generateBarcode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[700],
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 16),
                          SizedBox(width: 4),
                          Text('توليد', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // الفئة مع زر إضافة فئة جديدة
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'الفئة',
                    required: true,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                isExpanded: true,
                                value: _selectedCategoryId,
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                                items: _categories.map((category) {
                                  return DropdownMenuItem<int?>(
                                    value: category['id'],
                                    child: Text(
                                      category['name'] ?? 'غير محدد',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedCategoryId = value),
                                hint: _categories.isEmpty
                                    ? Text(
                                  'لا توجد فئات - اضغط زر +',
                                  style: TextStyle(color: Colors.red),
                                )
                                    : Text(
                                  'اختر الفئة',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                              ),
                            ),
                          ),
                          Container(
                            height: 48,
                            width: 1,
                            color: Colors.grey[300],
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle, color: Colors.blue, size: 22),
                            onPressed: _showAddCategoryDialog,
                            tooltip: 'إضافة فئة جديدة',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    label: 'المورد',
                    required: true,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _selectedSupplierId,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                          items: _suppliers.map((supplier) {
                            return DropdownMenuItem<int?>(
                              value: supplier['id'],
                              child: Text(
                                supplier['name'] ?? 'غير محدد',
                                style: TextStyle(color: Colors.black),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedSupplierId = value),
                          hint: _suppliers.isEmpty
                              ? Text(
                            'لا توجد موردين',
                            style: TextStyle(color: Colors.red),
                          )
                              : Text(
                            'اختر المورد',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // الوصف
            _buildField(
              label: 'الوصف',
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'وصف المنتج (اختياري)',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue, width: 1.5),
                  ),
                ),
                style: TextStyle(fontSize: 15, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monetization_on, size: 20, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'التسعير',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // أسعار الشراء والبيع
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'سعر الشراء',
                    required: true,
                    child: TextFormField(
                      controller: _purchasePriceController,
                      validator: (value) => _validatePrice(value, 'سعر الشراء'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        suffixText: 'ر.س',
                        suffixStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green, width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 15, color: Colors.black),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    label: 'سعر البيع',
                    required: true,
                    child: TextFormField(
                      controller: _sellPriceController,
                      validator: (value) => _validatePrice(value, 'سعر البيع'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        suffixText: 'ر.س',
                        suffixStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green, width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 15, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // وحدة القياس
            _buildField(
              label: 'وحدة القياس',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedUnit,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        items: _units.map((unit) {
                          return DropdownMenuItem<String>(
                            value: unit,
                            child: Text(
                              unit,
                              style: TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedUnit = value;
                              _customUnit = false;
                            });
                          }
                        },
                        hint: Text(
                          'اختر وحدة القياس',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _customUnit,
                        onChanged: (value) {
                          setState(() {
                            _customUnit = value!;
                            if (_customUnit) {
                              _selectedUnit = '';
                            }
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      Text(
                        'وحدة مخصصة',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_customUnit)
              Column(
                children: [
                  SizedBox(height: 12),
                  _buildField(
                    label: 'أدخل الوحدة المخصصة',
                    child: TextFormField(
                      onChanged: (value) => _customUnitValue = value,
                      decoration: InputDecoration(
                        hintText: 'مثل: علبة كبيرة، صندوق، الخ',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue, width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 15, color: Colors.black),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, size: 20, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'إدارة المخزون',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // المخزن
            _buildField(
              label: 'المخزن',
              required: true,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _selectedWarehouseId,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                    items: _warehouses.map((warehouse) {
                      return DropdownMenuItem<int?>(
                        value: warehouse['id'],
                        child: Text(
                          warehouse['name'] ?? 'غير محدد',
                          style: TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedWarehouseId = value),
                    hint: _warehouses.isEmpty
                        ? Text(
                      'لا توجد مخازن',
                      style: TextStyle(color: Colors.red),
                    )
                        : Text(
                      'اختر المخزن',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            // الكمية الأولية وحد المخزون
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'الكمية الأولية',
                    child: TextFormField(
                      controller: _initialQuantityController,
                      validator: (value) => _validateQuantity(value, 'الكمية الأولية'),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        suffixText: _customUnit ? _customUnitValue : _selectedUnit,
                        suffixStyle: TextStyle(color: Colors.black),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange, width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 15, color: Colors.black),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    label: 'حد المخزون الأدنى',
                    child: TextFormField(
                      controller: _minStockController,
                      validator: (value) => _validateQuantity(value, 'حد المخزون الأدنى'),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange, width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 15, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الكمية الأولية ستضاف تلقائياً للمخزن وتحدث رصيد المورد',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                      ),
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

  Widget _buildSupplierInfo() {
    final selectedSupplier = _suppliers.firstWhere(
          (supplier) => supplier['id'] == _selectedSupplierId,
      orElse: () => {},
    );

    if (selectedSupplier.isEmpty) return SizedBox();

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, size: 20, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'معلومات المورد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildInfoChip('الاسم:', selectedSupplier['name'] ?? 'غير محدد'),
                if (selectedSupplier['phone'] != null && selectedSupplier['phone'].toString().isNotEmpty)
                  _buildInfoChip('الهاتف:', selectedSupplier['phone'].toString()),
                if (selectedSupplier['email'] != null && selectedSupplier['email'].toString().isNotEmpty)
                  _buildInfoChip('البريد:', selectedSupplier['email'].toString()),
                if (selectedSupplier['balance'] != null)
                  _buildInfoChip('الرصيد:', '${NumberFormat("#,##0.00").format(selectedSupplier['balance'])} ر.س'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (_isLoading)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'جاري حفظ المنتج...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'حفظ المنتج',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.grey),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel, size: 20, color: Colors.grey[700]),
                        SizedBox(width: 8),
                        Text(
                          'إلغاء',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'إضافة منتج جديد',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.save, size: 22),
            onPressed: _isLoading ? null : _addProduct,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'جاري إضافة المنتج...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: 8),
              _buildImageSection(),
              _buildBasicInfoSection(),
              _buildPricingSection(),
              _buildInventorySection(),
              if (_selectedSupplierId != null) _buildSupplierInfo(),
              _buildActionButtons(),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _sellPriceController.dispose();
    _minStockController.dispose();
    _initialQuantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}