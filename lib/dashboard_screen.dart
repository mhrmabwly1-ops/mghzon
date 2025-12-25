import 'package:flutter/material.dart';
import 'package:projectstor/sales_screen.dart';
import 'package:projectstor/screens/permission_service.dart';
import 'package:projectstor/suppliers_screen.dart';
import 'package:projectstor/transactions_screen.dart';
import 'package:projectstor/warehouses_screen.dart';
//SalesScreen
import 'package:sqflite/sqflite.dart';
import ' product_list_screen.dart';
import '../screens/sales_invoices_screen.dart';
import '../screens/purchase_invoices_screen.dart';
import '../screens/sales_returns_screen.dart';
import '../screens/purchase_returns_screen.dart';
import '../screens/inventory_adjustment_screen.dart';
import '../screens/stock_transfers_screen.dart';
import '../screens/receipt_vouchers_screen.dart';
import '../screens/payment_vouchers_screen.dart';
import '../screens/cash_ledger_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/system_statistics_screen.dart';
import '../screens/profit_reports_screen.dart';
import '../screens/supplier_reports_screen.dart';
import '../screens/users_management_screen.dart';
import '../screens/login_screen.dart';
import 'add_product_screen.dart';
import 'customers_screen.dart';
import 'database_helper.dart';

class DashboardScreen extends StatefulWidget {
  final String username;
  final String role;

  DashboardScreen({required this.username, required this.role});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PermissionService _permissionService = PermissionService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  int _selectedTab = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    print('🎯 بدء تحميل لوحة التحكم للمستخدم: ${widget.username}');
   // _initializePermissions();
    _loadDashboardData();
  }

  Future<void> _initializePermissions() async {
    try {
       _permissionService.setUserPermissions(widget.role);
      print('✅ تم تعيين صلاحيات المستخدم: ${_permissionService.roleName}');
    } catch (e) {
      print('❌ خطأ في تعيين الصلاحيات: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);
      print('📊 جاري تحميل بيانات الداشبورد...');

      // استخدام دالة معدلة لتجنب أخطاء التحويل
      final stats = await _getDashboardStatsSafe();
      print('📈 بيانات الإحصائيات المستلمة: $stats');

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل بيانات الداشبورد: $e');
      setState(() => _isLoading = false);
      _showError('فشل في تحميل البيانات: $e');
    }
  }

  Future<Map<String, dynamic>> _getDashboardStatsSafe() async {
    try {
      final db = await _dbHelper.database;

      // جمع البيانات بشكل آمن
      return {
        'total_products': await _getCountSafe(db, 'products'),
        'total_customers': await _getCountSafe(db, 'customers'),
        'total_suppliers': await _getCountSafe(db, 'suppliers'),
        'total_warehouses': await _getCountSafe(db, 'warehouses'),
        'today_sales': await _getAmountSafe(db, 'sale_invoices'),
        'today_purchases': await _getAmountSafe(db, 'purchase_invoices'),
        'cash_balance': await _getCashBalanceSafe(db),
        'today_profit': 0.0,
        'low_stock_products': await _getLowStockCountSafe(db),
        'today_transactions': await _getTodayTransactionsSafe(db),
      };
    } catch (e) {
      print('⚠️ خطأ في جمع الإحصائيات: $e');
      return {
        'total_products': 0,
        'total_customers': 0,
        'total_suppliers': 0,
        'total_warehouses': 0,
        'today_sales': 0.0,
        'today_purchases': 0.0,
        'cash_balance': 0.0,
        'today_profit': 0.0,
        'low_stock_products': 0,
        'today_transactions': 0,
      };
    }
  }

  Future<int> _getCountSafe(Database db, String table) async {
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table WHERE is_active = 1');
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      print('⚠️ خطأ في حساب $table: $e');
      return 0;
    }
  }

  Future<double> _getAmountSafe(Database db, String table) async {
    try {
      final result = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount), 0) as amount 
        FROM $table 
        WHERE status = "approved" AND date(created_at) = date("now")
      ''');
      final value = result.first['amount'];
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return 0.0;
    } catch (e) {
      print('⚠️ خطأ في حساب مبلغ $table: $e');
      return 0.0;
    }
  }

  Future<double> _getCashBalanceSafe(Database db) async {
    try {
      final result = await db.rawQuery('SELECT COALESCE(balance_after, 0) as balance FROM cash_ledger ORDER BY id DESC LIMIT 1');
      final value = result.first['balance'];
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return 0.0;
    } catch (e) {
      print('⚠️ خطأ في حساب رصيد الصندوق: $e');
      return 0.0;
    }
  }

  Future<int> _getLowStockCountSafe(Database db) async {
    try {
      final result = await db.rawQuery('''
        SELECT COUNT(DISTINCT p.id) as count 
        FROM products p 
        JOIN warehouse_stock ws ON p.id = ws.product_id 
        WHERE p.is_active = 1 AND p.min_stock_level > 0 
        AND ws.quantity <= p.min_stock_level
      ''');
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      print('⚠️ خطأ في حساب المنتجات منخفضة المخزون: $e');
      return 0;
    }
  }

  Future<int> _getTodayTransactionsSafe(Database db) async {
    try {
      final result = await db.rawQuery('''
        SELECT (
          SELECT COUNT(*) FROM sale_invoices WHERE date(created_at) = date("now")
        ) + (
          SELECT COUNT(*) FROM purchase_invoices WHERE date(created_at) = date("now")
        ) as count
      ''');
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      print('⚠️ خطأ في حساب المعاملات اليومية: $e');
      return 0;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
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
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    await _loadDashboardData();
    setState(() => _isRefreshing = false);
    _showSuccess('تم تحديث البيانات بنجاح');
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد تسجيل الخروج'),
          ],
        ),
        content: Text('هل أنت متأكد من تسجيل الخروج من النظام؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _buildDashboardContent(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFF4A1D96),
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.dashboard, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً، ${widget.username}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _permissionService.roleName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: _isRefreshing
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshData,
          tooltip: 'تحديث البيانات',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                _showUserProfile();
                break;
              case 'users':
                if (_permissionService.canManageUsers) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UsersManagementScreen()));
                }
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Color(0xFF4A1D96), size: 18),
                  SizedBox(width: 8),
                  Text('الملف الشخصي'),
                ],
              ),
            ),
            if (_permissionService.canManageUsers)
              PopupMenuItem(
                value: 'users',
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('إدارة المستخدمين'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4A1D96)),
            SizedBox(height: 20),
            Text('جاري تحميل البيانات...', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      backgroundColor: Color(0xFF4A1D96),
      color: Colors.white,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // البطاقات الإحصائية الرئيسية
            _buildMainStatsCards(),

            // بطاقات سريعة
            _buildQuickStatsCards(),

            // الخدمات حسب التبويب المختار
            _buildServicesSection(),

            SizedBox(height: 80), // مساحة للتبويب السفلي
          ],
        ),
      ),
    );
  }

  Widget _buildMainStatsCards() {
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF4A1D96), Color(0xFF7E3BAF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // التاريخ واليوم مضغوط
          Container(
            margin: EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${now.day}/${now.month}/${now.year}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
                Text(
                  dayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // بطاقات أفقي صغيرة جداً
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSmallMainCard('المنتجات', '${_stats['total_products'] ?? 0}', Icons.inventory_2),
                SizedBox(width: 6),
                _buildSmallMainCard('العملاء', '${_stats['total_customers'] ?? 0}', Icons.people),
                SizedBox(width: 6),
                _buildSmallMainCard('الموردين', '${_stats['total_suppliers'] ?? 0}', Icons.local_shipping),
                SizedBox(width: 6),
                _buildSmallMainCard('المخازن', '${_stats['total_warehouses'] ?? 0}', Icons.warehouse),

                //TransactionsScreen
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMainCard(String title, String value, IconData icon) {
    return Container(
      width: 85, // عرض صغير جداً
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCards() {
    final quickStats = [
      if (_permissionService.canCreateSaleInvoices)
        _buildQuickStatCard(
          'مبيعات اليوم',
          '${(_stats['today_sales'] ?? 0).toStringAsFixed(0)} ر.س',
          Icons.attach_money,
          Colors.green,
        ),
      if (_permissionService.canCreatePurchaseInvoices)
        _buildQuickStatCard(
          'مشتريات اليوم',
          '${(_stats['today_purchases'] ?? 0).toStringAsFixed(0)} ر.س',
          Icons.shopping_cart,
          Colors.blue,
        ),
      if (_permissionService.canManageFinancial)
        _buildQuickStatCard(
          'رصيد الصندوق',
          '${(_stats['cash_balance'] ?? 0).toStringAsFixed(0)} ر.س',
          Icons.account_balance_wallet,
          Colors.orange,
        ),
      if (_permissionService.canManageInventory)
        _buildQuickStatCard(
          'منخفض المخزون',
          '${_stats['low_stock_products'] ?? 0}',
          Icons.warning,
          Colors.red,
        ),
    ];

    if (quickStats.isEmpty) return SizedBox();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإحصائيات اليومية',
            style: TextStyle(
              fontSize: 16, // تصغير حجم الخط
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          // استبدال SingleChildScrollView بـ Wrap لتفادي الـ overflow
          Wrap(
            spacing: 12, // المسافة الأفقية
            runSpacing: 12, // المسافة العمودية
            children: quickStats,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 24, // نصف الشاشة ناقص الـ padding
      constraints: BoxConstraints(minWidth: 140, maxWidth: 180), // تحديد الحد الأدنى والأقصى
      padding: EdgeInsets.all(12), // تقليل الـ padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // تقليل زوايا التدوير
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6), // تصغير حجم الأيقونة
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16, // تصغير حجم القيمة
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11, // تصغير حجم العنوان
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
//SalesScreen
  Widget _buildServicesSection() {
    final services = _getServicesByTab();

    if (services.isEmpty) {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'لا توجد خدمات متاحة',
              style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'لا تمتلك صلاحيات للوصول إلى خدمات هذا القسم',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getTabTitle(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) => services[index],
          ),
        ],
      ),
    );
  }

  List<Widget> _getServicesByTab() {
    switch (_selectedTab) {
      case 0: // المنتجات والمخزون
        return [
          if (_permissionService.canManageProducts)
            _buildServiceButton('المنتجات', Icons.inventory_2, Colors.blue, ProductListScreen()),
          if (_permissionService.canManageProducts)
            _buildServiceButton('إضافة منتج', Icons.add_circle, Colors.green, AddProductScreen()),
          if (_permissionService.canManageWarehouses)
            _buildServiceButton('المخازن', Icons.warehouse, Colors.orange, WarehousesScreen()),
          if (_permissionService.canManageInventory)
            _buildServiceButton('جرد المخزون', Icons.inventory, Colors.purple, InventoryAdjustmentScreen()),
          if (_permissionService.canManageInventory)
            _buildServiceButton('تحويل المخزون', Icons.compare_arrows, Colors.teal, StockTransfersScreen()),
        ];

      case 1: // المبيعات والعملاء
        return [
          if (_permissionService.canCreateSaleInvoices)
            _buildServiceButton('فواتير البيع', Icons.receipt_long, Colors.green, SalesInvoicesScreen()),
          if (_permissionService.canCreateSaleInvoices)
            _buildServiceButton('مرتجعات البيع', Icons.undo, Colors.orange, SalesReturnsScreen()),
          if (_permissionService.canManageCustomers)
            _buildServiceButton('العملاء', Icons.people, Colors.blue, CustomersScreen()),
        ];

      case 2: // المشتريات والموردين
        return [
          if (_permissionService.canCreatePurchaseInvoices)
            _buildServiceButton('فواتير الشراء', Icons.shopping_cart, Colors.purple, PurchaseInvoicesScreen()),
          if (_permissionService.canCreatePurchaseInvoices)
            _buildServiceButton('مرتجعات الشراء', Icons.reply, Colors.red, PurchaseReturnsScreen()),
          if (_permissionService.canManageSuppliers)
            _buildServiceButton('الموردين', Icons.local_shipping, Colors.amber, SuppliersScreen()),
        ];

      case 3: // الشؤون المالية
        return [
          if (_permissionService.canManageFinancial)
            _buildServiceButton('سندات القبض', Icons.payments, Colors.green, ReceiptVouchersScreen()),
          if (_permissionService.canManageFinancial)
            _buildServiceButton('سندات الصرف', Icons.money_off, Colors.red, PaymentVouchersScreen()),
          if (_permissionService.canManageFinancial)
            _buildServiceButton('سجل الصندوق', Icons.account_balance_wallet, Colors.blue, CashLedgerScreen()),
        ];

      case 4: // التقارير والإحصائيات
        return [
          if (_permissionService.canViewReports)
            _buildServiceButton('التقارير', Icons.analytics, Colors.purple, ComprehensiveReportsScreen()),
          if (_permissionService.canViewReports)
            _buildServiceButton('إحصائيات', Icons.show_chart, Colors.blue, ProfessionalStatisticsScreen()),
          if (_permissionService.canViewReports)
            _buildServiceButton('تقارير الأرباح', Icons.trending_up, Colors.green, ProfitReportsScreen()),
          if (_permissionService.canViewReports)
            _buildServiceButton('تقارير الموردين', Icons.business, Colors.orange, SupplierReportsScreen()),
          if (_permissionService.canViewReports)
            _buildServiceButton('تقارير المعاملات', Icons.business, Colors.orange, TransactionsScreen()),
          if (_permissionService.canViewReports)
            _buildServiceButton(' شاشه الكاشير', Icons.business, Colors.orange, SalesScreen()),
        ];

      default:
        return [];
    }
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case 0: return 'المنتجات والمخزون';
      case 1: return 'المبيعات والعملاء';
      case 2: return 'المشتريات والموردين';
      case 3: return 'الشؤون المالية';
      case 4: return 'التقارير والإحصائيات';
      default: return 'الخدمات';
    }
  }

  Widget _buildServiceButton(String title, IconData icon, Color color, Widget screen) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _buildNavItem('منتجات', Icons.inventory_2, 0),
            _buildNavItem('مبيعات', Icons.sell, 1),
            _buildNavItem('مشتريات', Icons.shopping_cart, 2),
            _buildNavItem('مالية', Icons.monetization_on, 3),
            _buildNavItem('تقارير', Icons.analytics, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String title, IconData icon, int index) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Color(0xFF4A1D96) : Colors.grey[600],
                ),
                SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Color(0xFF4A1D96) : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'manager': return Colors.orange;
      case 'warehouse': return Colors.blue;
      case 'cashier': return Colors.green;
      case 'viewer': return Colors.grey[600]!;
      default: return Color(0xFF4A1D96);
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'الإثنين';
      case 2: return 'الثلاثاء';
      case 3: return 'الأربعاء';
      case 4: return 'الخميس';
      case 5: return 'الجمعة';
      case 6: return 'السبت';
      case 7: return 'الأحد';
      default: return '';
    }
  }

  void _showUserProfile() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF4A1D96).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(Icons.person, size: 30, color: Color(0xFF4A1D96)),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.username,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _permissionService.roleName,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Text('الصلاحيات المتاحة:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildPermissionChips(),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A1D96),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('إغلاق', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPermissionChips() {
    final chips = <Widget>[];

    if (_permissionService.canManageProducts)
      chips.add(_buildPermissionChip('إدارة المنتجات', Colors.blue));
    if (_permissionService.canManageCustomers)
      chips.add(_buildPermissionChip('إدارة العملاء', Colors.green));
    if (_permissionService.canManageSuppliers)
      chips.add(_buildPermissionChip('إدارة الموردين', Colors.orange));
    if (_permissionService.canManageWarehouses)
      chips.add(_buildPermissionChip('إدارة المخازن', Colors.purple));
    if (_permissionService.canManageUsers)
      chips.add(_buildPermissionChip('إدارة المستخدمين', Colors.red));
    if (_permissionService.canViewReports)
      chips.add(_buildPermissionChip('عرض التقارير', Colors.teal));

    return chips;
  }

  Widget _buildPermissionChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}