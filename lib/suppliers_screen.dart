import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import 'color.dart';

class SuppliersScreen extends StatefulWidget {
  @override
  _SuppliersScreenState createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      setState(() => _isLoading = true);

      final suppliers = await _dbHelper.getSuppliers();

      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = suppliers;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      _showSnackBar('❌ خطأ في تحميل الموردين: ${e.toString()}', isError: true);
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshSuppliers() async {
    setState(() => _isRefreshing = true);
    await _loadSuppliers();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim());
    _filterSuppliers();
  }

  void _filterSuppliers() {
    List<Map<String, dynamic>> filtered = _suppliers;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((supplier) {
        final name = supplier['name']?.toString().toLowerCase() ?? '';
        final phone = supplier['phone']?.toString().toLowerCase() ?? '';
        final email = supplier['email']?.toString().toLowerCase() ?? '';
        final taxNumber = supplier['tax_number']?.toString().toLowerCase() ?? '';

        return name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            taxNumber.contains(query);
      }).toList();
    }

    // Filter by status
    if (_selectedFilter != 'all') {
      filtered = filtered.where((supplier) {
        switch (_selectedFilter) {
          case 'active':
            return supplier['is_active'] == 1;
          case 'inactive':
            return supplier['is_active'] == 0;
          case 'with_balance':
            return (supplier['balance'] ?? 0.0) > 0;
          case 'no_balance':
            return (supplier['balance'] ?? 0.0) == 0;
          default:
            return true;
        }
      }).toList();
    }

    setState(() => _filteredSuppliers = filtered);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _toggleSupplierStatus(int supplierId, String supplierName, bool currentStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغيير الحالة'),
        content: Text('هل تريد ${currentStatus ? 'تعطيل' : 'تفعيل'} المورد "$supplierName"؟'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange : Colors.green,
            ),
            child: Text(currentStatus ? 'تعطيل' : 'تفعيل'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _dbHelper.updateSupplier(supplierId, {
          'is_active': currentStatus ? 0 : 1,
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (result > 0) {
          _showSnackBar(
            '✅ تم ${currentStatus ? 'تعطيل' : 'تفعيل'} المورد بنجاح',
            isError: false,
          );
          await _refreshSuppliers();
        }
      } catch (e) {
        _showSnackBar('❌ خطأ في تغيير حالة المورد: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteSupplier(int supplierId, String supplierName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد الحذف'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حذف المورد:'),
            SizedBox(height: 8),
            Text(
              '"$supplierName"',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا يمكن التراجع عن هذه العملية',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Text('إلغاء', style: TextStyle(color: Colors.grey[700])),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete, size: 18),
                  SizedBox(width: 4),
                  Text('حذف'),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _dbHelper.deleteSupplier(supplierId);
        if (result > 0) {
          _showSnackBar('✅ تم حذف المورد بنجاح', isError: false);
          await _refreshSuppliers();
        } else {
          _showSnackBar('❌ فشل في حذف المورد');
        }
      } catch (e) {
        _showSnackBar('❌ خطأ في حذف المورد: ${e.toString()}');
      }
    }
  }

  void _showSupplierDetails(Map<String, dynamic> supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SupplierDetailsSheet(supplier: supplier),
    );
  }

  void _showAddSupplierDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEditSupplierDialog(
        onSupplierSaved: _refreshSuppliers,
      ),
    );
  }

  void _showEditSupplierDialog(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => AddEditSupplierDialog(
        supplier: supplier,
        onSupplierSaved: _refreshSuppliers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSupplierDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('إضافة مورد'),
        elevation: 4,
      ),
      body: Column(
        children: [
          // App Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 40, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إدارة الموردين',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          onPressed: _refreshSuppliers,
                          tooltip: 'تحديث',
                        ),
                        IconButton(
                          icon: Icon(Icons.filter_list, color: Colors.white),
                          onPressed: _showFilterOptions,
                          tooltip: 'تصفية',
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildSearchField(),
              ],
            ),
          ),

          // Statistics
          _buildStatistics(),

          // Suppliers List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshSuppliers,
              color: AppColors.primary,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredSuppliers.isEmpty
                  ? _buildEmptyState()
                  : _buildSuppliersList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث عن مورد...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: AppColors.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, size: 20),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تصفية الموردين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('الكل', 'all'),
                _buildFilterChip('نشطين فقط', 'active'),
                _buildFilterChip('غير نشطين', 'inactive'),
                _buildFilterChip('لديهم رصيد', 'with_balance'),
                _buildFilterChip('بدون رصيد', 'no_balance'),
              ],
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                backgroundColor: AppColors.primary,
              ),
              child: Text('تم', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        _filterSuppliers();
        Navigator.pop(context);
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: _selectedFilter == value ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildStatistics() {
    final totalSuppliers = _filteredSuppliers.length;
    final activeSuppliers = _filteredSuppliers.where((s) => s['is_active'] == 1).length;
    final suppliersWithBalance = _filteredSuppliers.where((s) => (s['balance'] ?? 0.0) > 0).length;
    final totalBalance = _filteredSuppliers.fold(0.0, (sum, supplier) => sum + (supplier['balance'] ?? 0.0));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatCard('المجموع', totalSuppliers.toString(), Icons.people, AppColors.primary),
          SizedBox(width: 8),
          _buildStatCard('نشطين', activeSuppliers.toString(), Icons.check_circle, Colors.green),
          SizedBox(width: 8),
          _buildStatCard('مدينين', suppliersWithBalance.toString(), Icons.money_off, Colors.orange),
          SizedBox(width: 8),
          _buildStatCard('الدين', '${totalBalance.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  SizedBox(width: 8), // ⬅️ أضف مسافة
                  Expanded( // ⬅️ أضف Expanded هنا
                    child: FittedBox( // ⬅️ أضف FittedBox
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 20),
            Text(
              'لا توجد موردين',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _searchQuery.isNotEmpty || _selectedFilter != 'all'
                    ? 'لم يتم العثور على موردين مطابقين للبحث أو الفلتر'
                    : 'قم بإضافة موردين جدد لعرضهم هنا',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
            SizedBox(height: 24),
            if (_searchQuery.isNotEmpty || _selectedFilter != 'all')
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _selectedFilter = 'all');
                  _filterSuppliers();
                },
                icon: Icon(Icons.clear_all),
                label: Text('إعادة تعيين البحث والفلتر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _showAddSupplierDialog,
                icon: Icon(Icons.add),
                label: Text('إضافة مورد جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuppliersList() {
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _filteredSuppliers.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final supplier = _filteredSuppliers[index];
        return _buildSupplierItem(supplier);
      },
    );
  }

  Widget _buildSupplierItem(Map<String, dynamic> supplier) {
    final isActive = supplier['is_active'] == 1;
    final balance = (supplier['balance'] as num?)?.toDouble() ?? 0.0;
    final hasBalance = balance > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSupplierDetails(supplier),
        onLongPress: () => _showEditSupplierDialog(supplier),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with status
                  Stack(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.local_shipping,
                          size: 28,
                          color: isActive ? Colors.blue : Colors.grey,
                        ),
                      ),
                      if (!isActive)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.block, size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 12),

                  // Supplier Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and Balance
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                supplier['name']?.toString() ?? 'غير معروف',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasBalance)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${balance.toStringAsFixed(2)} ر.س',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),

                        // Contact Info
                        if (supplier['phone'] != null)
                          Row(
                            children: [
                              Icon(Icons.phone, size: 12, color: Colors.grey),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  supplier['phone'].toString(),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                        // Email
                        if (supplier['email'] != null)
                          Row(
                            children: [
                              Icon(Icons.email, size: 12, color: Colors.grey),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  supplier['email'].toString(),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                        // Status and Actions
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle : Icons.remove_circle,
                                    size: 10,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isActive ? 'نشط' : 'غير نشط',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            _buildActionButtons(supplier, isActive),
                          ],
                        ),
                      ],
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

  Widget _buildActionButtons(Map<String, dynamic> supplier, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View Button
        IconButton(
          icon: Icon(Icons.visibility_outlined, size: 18),
          onPressed: () => _showSupplierDetails(supplier),
          style: IconButton.styleFrom(
            padding: EdgeInsets.all(4),
            minimumSize: Size(32, 32),
          ),
          tooltip: 'عرض التفاصيل',
        ),

        // Edit Button
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 18),
          onPressed: () => _showEditSupplierDialog(supplier),
          style: IconButton.styleFrom(
            padding: EdgeInsets.all(4),
            minimumSize: Size(32, 32),
          ),
          tooltip: 'تعديل',
        ),

        // Status Toggle Button
        IconButton(
          icon: Icon(isActive ? Icons.toggle_on : Icons.toggle_off, size: 20),
          onPressed: () => _toggleSupplierStatus(
            supplier['id'],
            supplier['name']?.toString() ?? 'المورد',
            isActive,
          ),
          style: IconButton.styleFrom(
            padding: EdgeInsets.all(4),
            minimumSize: Size(32, 32),
          ),
          color: isActive ? Colors.green : Colors.grey,
          tooltip: isActive ? 'تعطيل' : 'تفعيل',
        ),

        // Delete Button
        IconButton(
          icon: Icon(Icons.delete_outline, size: 18),
          onPressed: () => _deleteSupplier(
            supplier['id'],
            supplier['name']?.toString() ?? 'المورد',
          ),
          style: IconButton.styleFrom(
            padding: EdgeInsets.all(4),
            minimumSize: Size(32, 32),
          ),
          tooltip: 'حذف',
        ),
      ],
    );
  }
}

class SupplierDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailsSheet({Key? key, required this.supplier}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = supplier['is_active'] == 1;
    final balance = (supplier['balance'] as num?)?.toDouble() ?? 0.0;
    final hasBalance = balance > 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    size: 32,
                    color: isActive ? Colors.blue : Colors.grey,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier['name']?.toString() ?? 'غير معروف',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? 'نشط' : 'غير نشط',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Contact Info Section
            Text(
              'معلومات الاتصال',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),

            _buildDetailItem(
              icon: Icons.phone,
              label: 'الهاتف',
              value: supplier['phone']?.toString() ?? 'غير محدد',
              showDivider: true,
            ),

            _buildDetailItem(
              icon: Icons.email,
              label: 'البريد الإلكتروني',
              value: supplier['email']?.toString() ?? 'غير محدد',
              showDivider: true,
            ),

            _buildDetailItem(
              icon: Icons.location_on,
              label: 'العنوان',
              value: supplier['address']?.toString() ?? 'غير محدد',
              showDivider: true,
            ),

            if (supplier['tax_number'] != null)
              _buildDetailItem(
                icon: Icons.description,
                label: 'الرقم الضريبي',
                value: supplier['tax_number'].toString(),
                showDivider: true,
              ),

            // Financial Info Section
            SizedBox(height: 24),
            Text(
              'المعلومات المالية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),

            _buildDetailItem(
              icon: Icons.account_balance_wallet,
              label: 'الرصيد الحالي',
              value: '${balance.toStringAsFixed(2)} ر.س',
              valueColor: hasBalance ? Colors.red : Colors.green,
              showDivider: false,
            ),

            // Dates Section
            SizedBox(height: 24),
            Text(
              'التواريخ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),

            if (supplier['created_at'] != null)
              _buildDetailItem(
                icon: Icons.calendar_today,
                label: 'تاريخ الإضافة',
                value: _formatDate(supplier['created_at']),
                showDivider: true,
              ),

            if (supplier['updated_at'] != null)
              _buildDetailItem(
                icon: Icons.update,
                label: 'آخر تحديث',
                value: _formatDate(supplier['updated_at']),
                showDivider: false,
              ),

            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.grey[700],
              ),
              child: Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.grey[600]),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: valueColor ?? Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Colors.grey[200]),
          ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy/MM/dd - HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

class AddEditSupplierDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  final Function onSupplierSaved;

  const AddEditSupplierDialog({Key? key, this.supplier, required this.onSupplierSaved}) : super(key: key);

  @override
  _AddEditSupplierDialogState createState() => _AddEditSupplierDialogState();
}

class _AddEditSupplierDialogState extends State<AddEditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _balanceController = TextEditingController();
  final _creditLimitController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.supplier != null;
    if (_isEditMode) {
      _fillSupplierData();
    }
  }

  void _fillSupplierData() {
    final supplier = widget.supplier!;
    _nameController.text = supplier['name']?.toString() ?? '';
    _phoneController.text = supplier['phone']?.toString() ?? '';
    _emailController.text = supplier['email']?.toString() ?? '';
    _addressController.text = supplier['address']?.toString() ?? '';
    _taxNumberController.text = supplier['tax_number']?.toString() ?? '';
    _balanceController.text = supplier['balance']?.toStringAsFixed(2) ?? '';
    _creditLimitController.text = supplier['credit_limit']?.toStringAsFixed(2) ?? '';
    _isActive = supplier['is_active'] == 1;
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    // تحقق من صحة البريد الإلكتروني
    if (_emailController.text.isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(_emailController.text)) {
        _showError('يرجى إدخال بريد إلكتروني صحيح');
        return;
      }
    }

    // تحقق من صحة الرصيد
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    if (balance < 0) {
      _showError('الرصيد لا يمكن أن يكون سالباً');
      return;
    }

    // تحقق من صحة حد الائتمان
    final creditLimit = double.tryParse(_creditLimitController.text) ?? 0.0;
    if (creditLimit < 0) {
      _showError('حد الائتمان لا يمكن أن يكون سالباً');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supplierData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        'tax_number': _taxNumberController.text.trim().isNotEmpty ? _taxNumberController.text.trim() : null,
        'balance': balance,
        'credit_limit': creditLimit,
        'is_active': _isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      int result;
      if (_isEditMode) {
        result = await _dbHelper.updateSupplier(widget.supplier!['id'], supplierData);
      } else {
        result = await _dbHelper.insertSupplier(supplierData);
      }

      if (result > 0) {
        _showSuccess(_isEditMode ? 'تم تحديث المورد بنجاح' : 'تم إضافة المورد بنجاح');
        widget.onSupplierSaved();
        Navigator.pop(context);
      } else {
        _showError(_isEditMode ? 'فشل في تحديث المورد' : 'فشل في إضافة المورد');
      }
    } catch (e) {
      _showError('خطأ: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded( // ⬅️ أضف هذا لحل مشكلة overflow
              child: Text(
                message,
                maxLines: 3, // ⬅️ حدد عدد الأسطر
                overflow: TextOverflow.ellipsis, // ⬅️ إضافة ... إذا كان النص طويلاً
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating, // ⬅️ اختياري - يبدو أفضل
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // ⬅️ اختياري - حواف مستديرة
        ),
      ),
    );
  }
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    _isEditMode ? 'تعديل مورد' : 'إضافة مورد جديد',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'اسم المورد مطلوب';
                          }
                          if (value.trim().length < 2) {
                            return 'اسم المورد يجب أن يكون على الأقل حرفين';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'اسم المورد *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: Icon(Icons.person),
                        ),
                        maxLength: 100,
                      ),
                      SizedBox(height: 12),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '7XXXXXXXX',
                        ),
                        maxLength: 15,
                      ),
                      SizedBox(height: 12),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: Icon(Icons.email),
                          hintText: 'example@domain.com',
                        ),
                        maxLength: 100,
                      ),
                      SizedBox(height: 12),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'العنوان',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: Icon(Icons.location_on),
                          alignLabelWithHint: true,
                        ),
                        maxLength: 200,
                      ),
                      SizedBox(height: 12),

                      Row(
                        children: [
                          // Tax Number
                          Expanded(
                            child: TextFormField(
                              controller: _taxNumberController,
                              decoration: InputDecoration(
                                labelText: 'الرقم الضريبي',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLength: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          // Credit Limit
                          Expanded(
                            child: TextFormField(
                              controller: _creditLimitController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'حد الائتمان',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: Icon(Icons.eighteen_mp_outlined),
                                suffixText: 'ر.س',
                              ),
                              maxLength: 15,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Balance
                      TextFormField(
                        controller: _balanceController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'الرصيد الحالي',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: Icon(Icons.account_balance_wallet),
                          suffixText: 'ر.س',
                          hintText: '0.00',
                        ),
                        maxLength: 15,
                      ),
                      SizedBox(height: 16),

                      // Status
                      Row(
                        children: [
                          Checkbox(
                            value: _isActive,
                            onChanged: (value) => setState(() => _isActive = value!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          Text('المورد نشط', style: TextStyle(fontWeight: FontWeight.w500)),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _isActive ? 'نشط' : 'غير نشط',
                              style: TextStyle(
                                color: _isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 18),
                      label: Text('إلغاء'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveSupplier,
                      icon: _isLoading
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : Icon(Icons.save, size: 18),
                      label: Text(_isEditMode ? 'تحديث' : 'إضافة'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }
}