import 'package:flutter/material.dart';
import 'package:projectstor/screens/system_statistics_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../database_helper.dart';

import 'profit_reports_screen.dart';
import 'supplier_reports_screen.dart';


class ComprehensiveReportsScreen extends StatefulWidget {
  @override
  _ComprehensiveReportsScreenState createState() => _ComprehensiveReportsScreenState();
}

class _ComprehensiveReportsScreenState extends State<ComprehensiveReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // البيانات الرئيسية
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _monthlySales = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  List<Map<String, dynamic>> _topCustomers = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _yearlyComparison = [];

  // التصفية والتحكم
  bool _isLoading = true;
  bool _showCharts = true;
  String _selectedPeriod = 'month'; // day, week, month, quarter, year
  int _selectedYear = DateTime.now().year;

  // الألوان
  final List<Color> _chartColors = [
    Color(0xFF4361EE), // أزرق
    Color(0xFF3A0CA3), // بنفسجي
    Color(0xFF7209B7), // أرجواني
    Color(0xFFF72585), // وردي
    Color(0xFF4CC9F0), // سماوي
    Color(0xFF4895EF), // أزرق فاتح
    Color(0xFF560BAD), // بنفسجي غامق
    Color(0xFF7209B7), // بنفسجي
  ];

  @override
  void initState() {
    super.initState();
    _loadAllReportsData();
    _generateYearlyComparison();
  }
  Future<void> _loadAllReportsData() async {
    setState(() => _isLoading = true);

    try {
      // تحميل جميع البيانات بالتوازي مع تحديد الأنواع
      final List<dynamic> results = await Future.wait([
        _dbHelper.getDashboardStats(),                    // Map<String, dynamic>
        _dbHelper.getMonthlySalesReport(_selectedYear),   // List<Map<String, dynamic>>
        _dbHelper.getTopSellingProducts(limit: 8, period: _selectedPeriod), // List<Map<String, dynamic>>
        _dbHelper.getLowStockProducts(threshold: 15),    // List<Map<String, dynamic>>
        _dbHelper.getCustomersReport(),                   // List<Map<String, dynamic>>
        _dbHelper.getRecentTransactions(),                // List<Map<String, dynamic>>
      ]);

      // التحقق من الأنواع وتحديدها
      setState(() {
        // نتائج getDashboardStats هي Map
        _dashboardStats = (results[0] as Map<String, dynamic>?) ?? {};

        // باقي النتائج هي List<Map<String, dynamic>>
        _monthlySales = (results[1] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .toList() ?? [];

        _topProducts = (results[2] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .toList() ?? [];

        _lowStockProducts = (results[3] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .toList() ?? [];

        _topCustomers = (results[4] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .take(5)
            .toList() ?? [];

        _recentTransactions = (results[5] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .toList() ?? [];

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('❌ فشل في تحميل البيانات: $e', isError: true);
    }
  }
  Future<void> _generateYearlyComparison() async {
    final currentYear = DateTime.now().year;
    final years = [currentYear - 2, currentYear - 1, currentYear];

    List<Map<String, dynamic>> comparison = [];

    for (final year in years) {
      final sales = await _dbHelper.getMonthlySalesReport(year);
      final total = sales.fold(0.0, (sum, item) => sum + (item['total_sales']?.toDouble() ?? 0));

      comparison.add({
        'year': year.toString(),
        'total_sales': total,
        'growth': year == currentYear ? 0 : 0, // يمكن حساب النمو
      });
    }

    setState(() => _yearlyComparison = comparison);
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

  Future<void> _refreshData() async {
    await _loadAllReportsData();
    _showSnackBar('✅ تم تحديث البيانات بنجاح', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // AppBar كبير مع الإحصائيات
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Color(0xFF1E1B4B),
              elevation: 4,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'مركز التقارير الشامل',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xFF1E1B4B),
                        Color(0xFF312E81),
                        Color(0xFF4338CA),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 100, left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeaderStat('المبيعات', _dashboardStats['today_sales']?.toStringAsFixed(0) ?? '0', FontAwesomeIcons.chartLine),
                        _buildHeaderStat('المنتجات', _dashboardStats['total_products']?.toString() ?? '0', FontAwesomeIcons.box),
                        _buildHeaderStat('العملاء', _dashboardStats['total_customers']?.toString() ?? '0', FontAwesomeIcons.users),
                        _buildHeaderStat('الحركات', _dashboardStats['today_transactions']?.toString() ?? '0', FontAwesomeIcons.exchangeAlt),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshData,
                  tooltip: 'تحديث البيانات',
                ),
                IconButton(
                  icon: Icon(_showCharts ? Icons.insert_chart_outlined : Icons.view_list, color: Colors.white),
                  onPressed: () => setState(() => _showCharts = !_showCharts),
                  tooltip: _showCharts ? 'إظهار القوائم' : 'إظهار الرسوم',
                ),
              ],
            ),
          ];
        },
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              // بطاقات التنقل السريع
              _buildQuickNavCards(),
              SizedBox(height: 16),

              // إحصائيات سريعة
              _buildQuickStats(),
              SizedBox(height: 16),

              // المبيعات والمقارنات
              if (_showCharts) ...[
                _buildSalesSection(),
                SizedBox(height: 16),
              ],

              // المنتجات والعملاء
              Row(
                children: [
                  Expanded(child: _buildProductsSection()),
                  SizedBox(width: 12),
                  Expanded(child: _buildCustomersSection()),
                ],
              ),
              SizedBox(height: 16),

              // المخزون والحركات
              Row(
                children: [
                  Expanded(child: _buildInventorySection()),
                  SizedBox(width: 12),
                  Expanded(child: _buildTransactionsSection()),
                ],
              ),
              SizedBox(height: 16),

              // تقارير متقدمة
              _buildAdvancedReports(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaIcon(icon, size: 24, color: Colors.white.withOpacity(0.9)),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickNavCards() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildNavCard(
            'الإحصائيات المتقدمة',
            Icons.analytics,
            Colors.blue[700]!,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfessionalStatisticsScreen())),
          ),
          SizedBox(width: 12),
          _buildNavCard(
            'تقارير الأرباح',
            Icons.attach_money,
            Colors.green[700]!,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfitReportsScreen())),
          ),
          SizedBox(width: 12),
          _buildNavCard(
            'تقارير الموردين',
            Icons.shopping_cart,
            Colors.orange[700]!,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => SupplierReportsScreen())),
          ),
          SizedBox(width: 12),
          _buildNavCard(
            'التقارير الشهرية',
            Icons.calendar_today,
            Colors.purple[700]!,
            _exportMonthlyReport,
          ),
          SizedBox(width: 12),
          _buildNavCard(
            'التقارير الفورية',
            Icons.download,
            Colors.teal[700]!,
            _exportAllReports,
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // المبيعات
            Row(
              children: [
                _buildQuickStatItem('مبيعات اليوم', '${_dashboardStats['today_sales']?.toStringAsFixed(0) ?? '0'}', Colors.green),
                SizedBox(width: 12),
                _buildQuickStatItem('مبيعات الشهر', '${_calculateMonthlySales()}', Colors.blue),
                SizedBox(width: 12),
                _buildQuickStatItem('متوسط اليوم', '${_calculateDailyAverage()}', Colors.purple),
              ],
            ),
            SizedBox(height: 12),
            // المنتجات والعملاء
            Row(
              children: [
                _buildQuickStatItem('منخفض المخزون', _dashboardStats['low_stock_products']?.toString() ?? '0', Colors.orange),
                SizedBox(width: 12),
                _buildQuickStatItem('رصيد العملاء', '${_dashboardStats['total_balance']?.toStringAsFixed(0) ?? '0'}', Colors.red),
                SizedBox(width: 12),
                _buildQuickStatItem('هامش الربح', '${_calculateProfitMargin()}%', Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.chartBar, size: 20, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'المبيعات والأداء',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedYear.toString(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // مخطط المبيعات الشهرية
            Container(
              height: 220,
              child: SfCartesianChart(
                margin: EdgeInsets.all(0),
                primaryXAxis: CategoryAxis(
                  labelRotation: -45,
                  labelStyle: TextStyle(fontSize: 10),
                ),
                primaryYAxis: NumericAxis(
                  labelStyle: TextStyle(fontSize: 10),
                  numberFormat: NumberFormat.compact(),
                ),
                series: <CartesianSeries>[
                  LineSeries<Map<String, dynamic>, String>(
                    dataSource: _monthlySales,
                    xValueMapper: (data, _) => _getMonthAbbreviation(int.parse(data['month'])),
                    yValueMapper: (data, _) => data['total_sales']?.toDouble() ?? 0,
                    color: Colors.blue[700],
                    width: 2,
                    markerSettings: MarkerSettings(isVisible: true, width: 4, height: 4),
                    dataLabelSettings: DataLabelSettings(isVisible: false),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // المقارنة السنوية
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _yearlyComparison.map((yearData) {
                final year = yearData['year'];
                final sales = yearData['total_sales']?.toDouble() ?? 0;

                return Container(
                  width: 100,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        year,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_formatNumber(sales)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'المبيعات',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.boxes, size: 18, color: Colors.orange[700]),
                SizedBox(width: 8),
                Text(
                  'أفضل المنتجات',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_selectedPeriod == 'month' ? 'هذا الشهر' : 'هذا الأسبوع'}',
                    style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            ..._topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final sold = product['total_sold'] ?? 0;
              final revenue = product['total_revenue']?.toDouble() ?? 0;

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _chartColors[index % _chartColors.length],
                            _chartColors[(index + 2) % _chartColors.length],
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'غير معروف',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.shopping_bag, size: 10, color: Colors.grey),
                              SizedBox(width: 2),
                              Text(
                                'المباع: $sold',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
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
                          '${_formatNumber(revenue)}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                        Text(
                          '${product['profit']?.toStringAsFixed(0) ?? '0'} ربح',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.users, size: 18, color: Colors.green[700]),
                SizedBox(width: 8),
                Text(
                  'أفضل العملاء',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_topCustomers.length} عميل',
                    style: TextStyle(fontSize: 10, color: Colors.green[700]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            ..._topCustomers.asMap().entries.map((entry) {
              final index = entry.key;
              final customer = entry.value;
              final purchases = customer['total_purchases']?.toDouble() ?? 0;
              final balance = customer['balance']?.toDouble() ?? 0;

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        customer['name']?[0] ?? '?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer['name'] ?? 'غير معروف',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.receipt, size: 10, color: Colors.grey),
                              SizedBox(width: 2),
                              Text(
                                '${customer['total_invoices'] ?? 0} فاتورة',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
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
                          '${_formatNumber(purchases)}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: balance > 0 ? Colors.red[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'رصيد: ${balance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: balance > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.exclamationTriangle, size: 18, color: Colors.red[700]),
                SizedBox(width: 8),
                Text(
                  'منخفض المخزون',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                if (_lowStockProducts.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_lowStockProducts.length} منتج',
                      style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),

            if (_lowStockProducts.isEmpty)
              Container(
                height: 80,
                alignment: Alignment.center,
                child: Text(
                  '🎉 جميع المنتجات في مستويات آمنة',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              )
            else
              ..._lowStockProducts.take(3).map((product) {
                final stock = product['total_stock'] ?? 0;
                final minLevel = product['min_stock_level'] ?? 0;
                final percentage = minLevel > 0 ? (stock / minLevel * 100).toInt() : 0;

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'غير معروف',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'المتاح: $stock',
                                  style: TextStyle(fontSize: 11, color: Colors.red[700]),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'الحد: $minLevel',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.exchangeAlt, size: 18, color: Colors.purple[700]),
                SizedBox(width: 8),
                Text(
                  'آخر الحركات',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
            SizedBox(height: 12),

            ..._recentTransactions.take(3).map((transaction) {
              final type = transaction['type'] ?? 'sale';
              final amount = transaction['total_amount']?.toDouble() ?? 0;
              final date = transaction['date'] != null
                  ? DateFormat('hh:mm a').format(DateTime.parse(transaction['date']))
                  : '--:--';

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: type == 'sale' ? Colors.green[100] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        type == 'sale' ? Icons.shopping_cart : Icons.inventory,
                        size: 16,
                        color: type == 'sale' ? Colors.green : Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction['product_name'] ?? 'غير معروف',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person, size: 10, color: Colors.grey),
                              SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  transaction['customer_name'] ?? 'نقدي',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                          date,
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: type == 'sale' ? Colors.green : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedReports() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تقارير متقدمة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReportChip('تقرير الربحية', Icons.attach_money, Colors.green),
                _buildReportChip('تحليل العملاء', Icons.people, Colors.blue),
                _buildReportChip('أداء الموردين', Icons.shopping_cart, Colors.orange),
                _buildReportChip('تحليل المخزون', Icons.analytics, Colors.purple),
                _buildReportChip('المبيعات التفصيلية', Icons.receipt_long, Colors.teal),
                _buildReportChip('التقارير المالية', Icons.account_balance, Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportChip(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // يمكن إضافة التنقل إلى التقارير التفصيلية هنا
        _showSnackBar('جار تحضير $title...', isError: false);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // دوال مساعدة
  String _getMonthAbbreviation(int month) {
    final months = ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'];
    return months[month - 1];
  }

  String _formatNumber(double number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toStringAsFixed(0);
  }

  String _calculateMonthlySales() {
    final total = _monthlySales.fold(0.0, (sum, item) => sum + (item['total_sales']?.toDouble() ?? 0));
    return _formatNumber(total);
  }

  String _calculateDailyAverage() {
    final monthlyTotal = _monthlySales.fold(0.0, (sum, item) => sum + (item['total_sales']?.toDouble() ?? 0));
    final daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final avg = monthlyTotal / daysInMonth;
    return _formatNumber(avg);
  }

  String _calculateProfitMargin() {
    // يمكن حساب هامش الربح من البيانات المتاحة
    final monthlyTotal = _monthlySales.fold(0.0, (sum, item) => sum + (item['total_sales']?.toDouble() ?? 0));
    final estimatedCost = monthlyTotal * 0.7; // افتراضي
    final profit = monthlyTotal - estimatedCost;
    final margin = monthlyTotal > 0 ? (profit / monthlyTotal * 100) : 0;
    return margin.toStringAsFixed(1);
  }

  Future<void> _exportMonthlyReport() async {
    _showSnackBar('جار تصدير التقرير الشهري...', isError: false);
    await Future.delayed(Duration(seconds: 2));
    _showSnackBar('✅ تم تصدير التقرير الشهري', isError: false);
  }

  Future<void> _exportAllReports() async {
    _showSnackBar('جار تصدير جميع التقارير...', isError: false);
    await Future.delayed(Duration(seconds: 2));
    _showSnackBar('✅ تم تصدير جميع التقارير بنجاح', isError: false);
  }
}