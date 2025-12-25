import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../database_helper.dart';


class ProfitReportsScreen extends StatefulWidget {
  @override
  _ProfitReportsScreenState createState() => _ProfitReportsScreenState();
}

class _ProfitReportsScreenState extends State<ProfitReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Map<String, dynamic> _profitReport = {};
  List<Map<String, dynamic>> _supplierProfits = [];
  List<Map<String, dynamic>> _productProfits = [];
  List<Map<String, dynamic>> _dailyProfits = [];
  List<Map<String, dynamic>> _profitMargins = [];

  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'summary';

  final Map<String, String> _reportTypes = {
    'summary': 'ملخص الأرباح',
    'suppliers': 'أرباح الموردين',
    'products': 'أرباح المنتجات',
    'daily': 'الأرباح اليومية',
    'margins': 'هوامش الربح',
  };

  @override
  void initState() {
    super.initState();
    _loadProfitReport();
  }

  Future<void> _loadProfitReport() async {
    setState(() => _isLoading = true);

    try {
      final profitReport = await _dbHelper.getProfitReport(_startDate, _endDate);
      final supplierProfits = await _dbHelper.getSupplierProfitReport(_startDate, _endDate);
      final productProfits = await _dbHelper.getProductProfitReport(_startDate, _endDate);
      final dailyProfits = await _dbHelper.getDailyProfitReport(_startDate, _endDate);
      final profitMargins = await _dbHelper.getProfitMarginReport();

      setState(() {
        _profitReport = profitReport as Map<String, dynamic>;
        _supplierProfits = supplierProfits;
        _productProfits = productProfits;
        _dailyProfits = dailyProfits;
        _profitMargins = profitMargins;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل تقرير الأرباح: $e');
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadProfitReport();
    }
  }

  double get _totalProfit {
    final profitStats = _profitReport['profit_stats'] ?? {};
    return profitStats['total_profit']?.toDouble() ?? 0;
  }

  double get _totalRevenue {
    final profitStats = _profitReport['profit_stats'] ?? {};
    return profitStats['total_revenue']?.toDouble() ?? 0;
  }

  double get _totalCost {
    final profitStats = _profitReport['profit_stats'] ?? {};
    return profitStats['total_cost']?.toDouble() ?? 0;
  }

  double get _profitMargin {
    return _totalRevenue > 0 ? (_totalProfit / _totalRevenue) * 100 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقارير الأرباح'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProfitReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // فلترة التاريخ ونوع التقرير
          _buildFiltersCard(),
          // بطاقات الإحصائيات السريعة
          if (_selectedReportType == 'summary') _buildProfitSummaryCards(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildSelectedReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedReportType,
                    decoration: InputDecoration(
                      labelText: 'نوع التقرير',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _reportTypes.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedReportType = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.date_range, color: Colors.teal),
                  onPressed: _selectDateRange,
                  tooltip: 'اختيار الفترة',
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'الفترة: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSummaryCards() {
    return Container(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildProfitCard(
            'إجمالي الأرباح',
            '$_totalProfit ريال',
            Icons.attach_money,
            Colors.green,
            'هامش الربح: ${_profitMargin.toStringAsFixed(1)}%',
          ),
          _buildProfitCard(
            'إجمالي الإيرادات',
            '$_totalRevenue ريال',
            Icons.trending_up,
            Colors.blue,
            '${_profitReport['sales_stats']?['total_invoices'] ?? 0} فاتورة',
          ),
          _buildProfitCard(
            'إجمالي التكلفة',
            '$_totalCost ريال',
            Icons.account_balance_wallet,
            Colors.orange,
            '${_profitReport['purchase_stats']?['total_invoices'] ?? 0} فاتورة شراء',
          ),
          _buildProfitCard(
            'صافي الربح',
            '${_totalProfit - (_profitReport['sales_stats']?['total_discount']?.toDouble() ?? 0)} ريال',
            Icons.bar_chart,
            Colors.purple,
            'بعد الخصومات',
          ),
        ],
      ),
    );
  }

  Widget _buildProfitCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      width: 180,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
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
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedReport() {
    switch (_selectedReportType) {
      case 'summary':
        return _buildSummaryReport();
      case 'suppliers':
        return _buildSuppliersReport();
      case 'products':
        return _buildProductsReport();
      case 'daily':
        return _buildDailyReport();
      case 'margins':
        return _buildMarginsReport();
      default:
        return _buildSummaryReport();
    }
  }

  Widget _buildSummaryReport() {
    final monthlyProfit = _profitReport['monthly_profit'] ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          // مخطط الأرباح الشهرية
          if (monthlyProfit.isNotEmpty) ...[
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الأرباح الشهرية',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 200,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(),
                        series: <ColumnSeries<Map<String, dynamic>, String>>[
                          ColumnSeries<Map<String, dynamic>, String>(
                            dataSource: monthlyProfit,
                            xValueMapper: (Map<String, dynamic> data, _) => _formatMonth(data['month']),
                            yValueMapper: (Map<String, dynamic> data, _) => data['profit']?.toDouble() ?? 0,
                            color: Colors.teal,
                            dataLabelSettings: DataLabelSettings(isVisible: true),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],

          // توزيع الأرباح
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'توزيع الأرباح',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 200,
                    child: SfCircularChart(
                      series: <PieSeries<Map<String, dynamic>, String>>[
                        PieSeries<Map<String, dynamic>, String>(
                          dataSource: [
                            {'name': 'الإيرادات', 'value': _totalRevenue, 'color': Colors.blue},
                            {'name': 'التكلفة', 'value': _totalCost, 'color': Colors.orange},
                            {'name': 'الربح', 'value': _totalProfit, 'color': Colors.green},
                          ],
                          xValueMapper: (Map<String, dynamic> data, _) => data['name'],
                          yValueMapper: (Map<String, dynamic> data, _) => data['value'],
                          pointColorMapper: (Map<String, dynamic> data, _) => data['color'],
                          dataLabelSettings: DataLabelSettings(isVisible: true),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersReport() {
    return ListView.builder(
      itemCount: _supplierProfits.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final supplier = _supplierProfits[index];
        final profit = supplier['generated_profit']?.toDouble() ?? 0;
        final purchases = supplier['total_purchases']?.toDouble() ?? 0;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getProfitColor(profit),
              child: Icon(
                profit > 0 ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(supplier['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${supplier['purchase_invoices'] ?? 0} فاتورة شراء'),
                Text('المشتريات: ${purchases.toStringAsFixed(2)} ريال'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${profit.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getProfitColor(profit),
                    fontSize: 16,
                  ),
                ),
                Text(
                  'ربح',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsReport() {
    return ListView.builder(
      itemCount: _productProfits.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final product = _productProfits[index];
        final profit = product['total_profit']?.toDouble() ?? 0;
        final margin = product['profit_margin']?.toDouble() ?? 0;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getMarginColor(margin),
              child: Text(
                '${margin.toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            title: Text(product['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product['category_name'] ?? 'بدون فئة'}'),
                Text('مبيع: ${product['total_sold']} - إيراد: ${product['total_revenue']?.toStringAsFixed(2)} ريال'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${profit.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getProfitColor(profit),
                  ),
                ),
                Text(
                  'ربح',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyReport() {
    return ListView.builder(
      itemCount: _dailyProfits.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final daily = _dailyProfits[index];
        final profit = daily['daily_profit']?.toDouble() ?? 0;
        final margin = daily['daily_margin']?.toDouble() ?? 0;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getProfitColor(profit),
              child: Icon(
                profit > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
                size: 18,
              ),
            ),
            title: Text(_formatDisplayDate(DateTime.parse(daily['date']))),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${daily['invoices_count']} فاتورة - ${daily['items_sold']} منتج'),
                Text('الإيراد: ${daily['daily_revenue']?.toStringAsFixed(2)} ريال'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${profit.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getProfitColor(profit),
                  ),
                ),
                Text(
                  '${margin.toStringAsFixed(1)}% هامش',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarginsReport() {
    return ListView.builder(
      itemCount: _profitMargins.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final product = _profitMargins[index];
        final margin = product['profit_margin']?.toDouble() ?? 0;
        final potentialProfit = product['potential_profit']?.toDouble() ?? 0;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getMarginColor(margin),
              child: Text(
                '${margin.toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            title: Text(product['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سعر البيع: ${product['sell_price']} - سعر الشراء: ${product['purchase_price']}'),
                Text('الربح للوحدة: ${product['profit_per_unit']?.toStringAsFixed(2)} ريال'),
                Text('المخزون: ${product['current_stock']} - ربح محتمل: ${potentialProfit.toStringAsFixed(2)} ريال'),
              ],
            ),
            trailing: Icon(
              margin > 50 ? Icons.star : margin > 25 ? Icons.trending_up : Icons.trending_flat,
              color: _getMarginColor(margin),
            ),
          ),
        );
      },
    );
  }

  Color _getProfitColor(double profit) {
    if (profit > 0) return Colors.green;
    if (profit < 0) return Colors.red;
    return Colors.grey;
  }

  Color _getMarginColor(double margin) {
    if (margin > 50) return Colors.green;
    if (margin > 25) return Colors.blue;
    if (margin > 10) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDisplayDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatMonth(String monthStr) {
    final parts = monthStr.split('-');
    if (parts.length == 2) {
      final year = parts[0];
      final month = int.parse(parts[1]);
      final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      return '${months[month - 1]}\n$year';
    }
    return monthStr;
  }
}