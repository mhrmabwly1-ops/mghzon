import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:flutter/services.dart';
import '../database_helper.dart';

class SupplierReportsScreen extends StatefulWidget {
  @override
  _SupplierReportsScreenState createState() => _SupplierReportsScreenState();
}

class _SupplierReportsScreenState extends State<SupplierReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> _suppliers = [];
  Map<String, dynamic>? _selectedSupplier;
  Map<String, dynamic>? _supplierReport;

  bool _isLoading = false;
  bool _isGeneratingReport = false;

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: 30)),
    end: DateTime.now(),
  );

  int _selectedTab = 0;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuppliers();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final suppliers = await _dbHelper.getAllSuppliersSummary();
      setState(() {
        _suppliers = suppliers;
        _isLoading = false;
      });

      if (suppliers.isNotEmpty && _selectedSupplier == null) {
        _loadSupplierReport(suppliers.first['id']);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ خطأ في تحميل الموردين: $e');
      _showError('فشل في تحميل الموردين: $e');
    }
  }

  Future<void> _loadSupplierReport(int supplierId) async {
    if (_isGeneratingReport) return;

    setState(() => _isGeneratingReport = true);

    try {
      final report = await _dbHelper.getSupplierDetailedReport(
        supplierId,
        _dateRange.start,
        _dateRange.end,
      );

      final supplier = _suppliers.firstWhere((s) => s['id'] == supplierId);

      setState(() {
        _selectedSupplier = supplier;
        _supplierReport = report;
        _isGeneratingReport = false;
        _selectedTab = 0; // العودة للتبويب الأول
      });
    } catch (e) {
      setState(() => _isGeneratingReport = false);
      print('❌ خطأ في تحميل التقرير: $e');
      _showError('فشل في تحميل التقرير: $e');
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      if (_selectedSupplier != null) {
        _loadSupplierReport(_selectedSupplier!['id']);
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_supplierReport == null || _selectedSupplier == null) return;

    setState(() => _isGeneratingReport = true);

    try {
      final pdf = pw.Document();

      // تحميل الخط العربي
      final fontData = await rootBundle.load("assets/fonts/arabic_font.ttf");
      final arabicFont = pw.Font.ttf(fontData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: arabicFont,
          ),
          build: (pw.Context context) {
            return [
              _buildPDFHeader(arabicFont),
              _buildPDFSummary(),
              _buildPDFTransactions(),
              _buildPDFProducts(),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/supplier_report_${_selectedSupplier!['id']}.pdf");
      await file.writeAsBytes(await pdf.save());

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
      );

      _showSuccess('تم تصدير التقرير بنجاح');
    } catch (e) {
      print('❌ خطأ في تصدير PDF: $e');
      _showError('فشل في تصدير التقرير: $e');
    } finally {
      setState(() => _isGeneratingReport = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقارير الموردين'),
        centerTitle: true,
        actions: [
          if (_selectedSupplier != null)
            IconButton(
              icon: Icon(Icons.picture_as_pdf),
              onPressed: _exportToPDF,
              tooltip: 'تصدير إلى PDF',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSuppliers,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
        children: [
          // القائمة الجانبية - عرض على الشاشات الكبيرة فقط
          if (MediaQuery.of(context).size.width > 768)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(right: BorderSide(color: Colors.grey[300]!)),
              ),
              child: _buildSidePanel(),
            ),

          // المحتوى الرئيسي
          Expanded(
            child: _selectedSupplier == null
                ? _buildEmptyState()
                : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Column(
      children: [
        // الفلاتر
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    'الفترة الزمنية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDateRange(context),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'من ${_formatDate(_dateRange.start)}',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              'إلى ${_formatDate(_dateRange.end)}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // قائمة الموردين
        Expanded(
          child: ListView.separated(
            itemCount: _suppliers.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final supplier = _suppliers[index];
              final isSelected = _selectedSupplier?['id'] == supplier['id'];
              final totalPurchases = (supplier['total_purchases'] as num?)?.toDouble() ?? 0.0;

              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.indigo : Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    supplier['name']?.toString().substring(0, 1) ?? '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                title: Text(
                  supplier['name']?.toString() ?? 'مجهول',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      '${supplier['total_invoices']?.toString() ?? '0'} فاتورة',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      totalPurchases.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.indigo[800],
                      ),
                    ),
                    Text(
                      'ريال',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                selected: isSelected,
                selectedTileColor: Colors.indigo[50],
                onTap: () => _loadSupplierReport(supplier['id'] as int),
              );
            },
          ),
        ),

        // إحصائيات عامة
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            border: Border(top: BorderSide(color: Colors.indigo[100]!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إحصائيات عامة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[900],
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_suppliers.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.indigo[900],
                          ),
                        ),
                        Text(
                          'مورد',
                          style: TextStyle(fontSize: 12, color: Colors.indigo[700]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.indigo[200],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_suppliers.fold(0, (int sum, s) => sum + ((s['total_invoices'] as int?) ?? 0))}', // 🔧 التصحيح هنا
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.indigo[900],
                          ),
                        ),
                        Text(
                          'فاتورة',
                          style: TextStyle(fontSize: 12, color: Colors.indigo[700]),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 20),
          Text(
            'اختر مورداً لعرض تقريره',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          if (_suppliers.isEmpty)
            ElevatedButton(
              onPressed: _loadSuppliers,
              child: Text('تحميل الموردين'),
            ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    return Column(
      children: [
        // شريط المورد المحدد
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.indigo[50],
          child: Row(
            children: [
              // زر عرض/إخفاء القائمة الجانبية للشاشات الصغيرة
              if (MediaQuery.of(context).size.width <= 768)
                IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: _buildSidePanel(),
                      ),
                    );
                  },
                ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedSupplier!['name']?.toString() ?? 'مجهول',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[900],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'الفترة: ${_formatDate(_dateRange.start)} إلى ${_formatDate(_dateRange.end)}',
                      style: TextStyle(color: Colors.indigo[700]),
                    ),
                  ],
                ),
              ),

              if (_isGeneratingReport)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),

        // شريط التبويبات
        Container(
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabItem(0, Icons.dashboard, 'ملخص'),
                _buildTabItem(1, Icons.receipt, 'الفواتير'),
                _buildTabItem(2, Icons.inventory_2, 'المنتجات'),
                _buildTabItem(3, Icons.analytics, 'تحليلات'),
              ],
            ),
          ),
        ),

        // محتوى التقرير
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _buildTabContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;

    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () => setState(() => _selectedTab = index),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.indigo : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.grey[600],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_isGeneratingReport || _supplierReport == null) {
      return Center(child: CircularProgressIndicator());
    }

    final summary = (_supplierReport!['summary'] as Map<String, dynamic>?) ?? {};
    final supplier = _selectedSupplier!;

    switch (_selectedTab) {
      case 0: // ملخص
        return SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              // بطاقة الإحصائيات
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // إحصائيات أساسية
                      GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildStatCard(
                            'إجمالي المشتريات',
                            '${(summary['total_purchases'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            'ريال',
                            Icons.shopping_cart,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'المبلغ المدفوع',
                            '${(summary['total_paid'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            'ريال',
                            Icons.payments,
                            Colors.green,
                          ),
                          _buildStatCard(
                            'الرصيد المتبقي',
                            '${(summary['remaining_balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            'ريال',
                            Icons.account_balance_wallet,
                            Colors.orange,
                          ),
                          _buildStatCard(
                            'المنتجات المباعة',
                            '${summary['total_products_sold']?.toString() ?? '0'}',
                            'منتج',
                            Icons.inventory_2,
                            Colors.purple,
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      // إحصائيات الربحية
                      GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildStatCard(
                            'الإيرادات',
                            '${(summary['total_generated_revenue'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            'ريال',
                            Icons.trending_up,
                            Colors.teal,
                          ),
                          _buildStatCard(
                            'الأرباح',
                            '${(summary['total_generated_profit'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            'ريال',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // معلومات إضافية
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات إضافية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[900],
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildInfoItem('عدد الفواتير', '${(_supplierReport!['purchase_invoices'] as List?)?.length ?? 0}'),
                      _buildInfoItem('عدد المنتجات', '${(_supplierReport!['supplier_products'] as List?)?.length ?? 0}'),
                      _buildInfoItem('متوسط قيمة الفاتورة', '${_calculateAverageInvoice(summary).toStringAsFixed(2)} ريال'),
                      _buildInfoItem('هامش الربح', '${(summary['profit_margin'] as num?)?.toStringAsFixed(1) ?? '0.0'}%'),
                      _buildInfoItem('نسبة السداد', '${_calculatePaymentRatio(summary).toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case 1: // الفواتير
        return _buildInvoicesTab();

      case 2: // المنتجات
        return _buildProductsTab();

      case 3: // تحليلات
        return _buildAnalyticsTab();

      default:
        return Container();
    }
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: color),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            unit,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
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
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    final invoices = (_supplierReport!['purchase_invoices'] as List?) ?? [];

    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'لا توجد فواتير في هذه الفترة',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final remaining = totalAmount - paidAmount;
        final status = invoice['status']?.toString() ?? 'pending';

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getInvoiceStatusColor(status),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${invoice['invoice_number']?.toString().split('-').last ?? ''}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'فاتورة #${invoice['invoice_number']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  'التاريخ: ${_formatDisplayDate(DateTime.parse(invoice['invoice_date']?.toString() ?? DateTime.now().toString()))}',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  'المخزن: ${invoice['warehouse_name'] ?? 'غير محدد'}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${totalAmount.toStringAsFixed(2)} ر.س',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  '${paidAmount.toStringAsFixed(2)} ر.س مدفوع',
                  style: TextStyle(
                    fontSize: 11,
                    color: remaining > 0 ? Colors.orange[700] : Colors.green[700],
                  ),
                ),
                if (remaining > 0)
                  Chip(
                    label: Text('مستحق'),
                    backgroundColor: Colors.orange[100],
                    labelStyle: TextStyle(fontSize: 10),
                  ),
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('تفاصيل الفاتورة'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الرقم: ${invoice['invoice_number']}'),
                      Text('التاريخ: ${_formatDisplayDate(DateTime.parse(invoice['invoice_date']?.toString() ?? DateTime.now().toString()))}'),
                      Text('المخزن: ${invoice['warehouse_name'] ?? 'غير محدد'}'),
                      Text('الحالة: ${_getStatusText(status)}'),
                      Text('المبلغ الإجمالي: ${totalAmount.toStringAsFixed(2)} ر.س'),
                      Text('المبلغ المدفوع: ${paidAmount.toStringAsFixed(2)} ر.س'),
                      Text('المبلغ المتبقي: ${remaining.toStringAsFixed(2)} ر.س'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('إغلاق'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    final products = (_supplierReport!['top_products'] as List?) ?? [];

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 60, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'لا توجد منتجات في هذه الفترة',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columns: [
            DataColumn(label: Text('المنتج')),
            DataColumn(label: Text('الكمية المباعة')),
            DataColumn(label: Text('الإيرادات')),
            DataColumn(label: Text('الأرباح')),
            DataColumn(label: Text('الهامش')),
          ],
          rows: products.map((product) {
            final revenue = (product['revenue'] as num?)?.toDouble() ?? 0.0;
            final profit = (product['profit'] as num?)?.toDouble() ?? 0.0;
            final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;

            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name']?.toString() ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (product['barcode'] != null)
                        Text(
                          'باركود: ${product['barcode']}',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                DataCell(Text('${product['total_sold']?.toString() ?? '0'}')),
                DataCell(Text('${revenue.toStringAsFixed(2)} ر.س')),
                DataCell(Text(
                  '${profit.toStringAsFixed(2)} ر.س',
                  style: TextStyle(
                    color: profit > 0 ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                )),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getMarginColor(margin),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${margin.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final summary = (_supplierReport!['summary'] as Map<String, dynamic>?) ?? {};

    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مؤشرات الأداء',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[900],
                    ),
                  ),
                  SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildAnalyticCard(
                        'كفاءة المخزون',
                        '${_calculateInventoryEfficiency(summary).toStringAsFixed(1)}%',
                        Icons.inventory,
                        Colors.purple,
                      ),
                      _buildAnalyticCard(
                        'معدل البيع اليومي',
                        '${_calculateDailySalesRate(summary).toStringAsFixed(1)}',
                        Icons.trending_up,
                        Colors.teal,
                        unit: 'منتج/يوم',
                      ),
                      _buildAnalyticCard(
                        'متوسط الربح للمنتج',
                        '${_calculateProfitPerProduct(summary).toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                        unit: 'ريال',
                      ),
                      _buildAnalyticCard(
                        'نسبة التحصيل',
                        '${_calculatePaymentRatio(summary).toStringAsFixed(1)}%',
                        Icons.payments,
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التوصيات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[900],
                    ),
                  ),
                  SizedBox(height: 12),
                  ..._generateRecommendations(summary).map((rec) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            rec['type'] == 'positive' ? Icons.check_circle : Icons.info,
                            color: rec['type'] == 'positive' ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rec['text'],
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticCard(String title, String value, IconData icon, Color color, {String unit = ''}) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                //textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // دوال PDF محسنة مع دعم اللغة العربية
  pw.Widget _buildPDFHeader(pw.Font arabicFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'تقرير أداء المورد',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'المورد: ${_selectedSupplier!['name']}',
          style: pw.TextStyle(fontSize: 16, font: arabicFont),
        ),
        pw.Text(
          'الفترة: ${_formatDate(_dateRange.start)} إلى ${_formatDate(_dateRange.end)}',
          style: pw.TextStyle(fontSize: 14, font: arabicFont),
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildPDFSummary() {
    final summary = (_supplierReport!['summary'] as Map<String, dynamic>?) ?? {};

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ملخص الإحصائيات',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPDFStatBox('إجمالي المشتريات', '${(summary['total_purchases'] as num?)?.toStringAsFixed(2) ?? '0.00'} ر.س'),
              _buildPDFStatBox('المبلغ المدفوع', '${(summary['total_paid'] as num?)?.toStringAsFixed(2) ?? '0.00'} ر.س'),
              _buildPDFStatBox('الرصيد المتبقي', '${(summary['remaining_balance'] as num?)?.toStringAsFixed(2) ?? '0.00'} ر.س'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPDFStatBox('الأرباح المتحققة', '${(summary['total_generated_profit'] as num?)?.toStringAsFixed(2) ?? '0.00'} ر.س'),
              _buildPDFStatBox('المنتجات المباعة', '${summary['total_products_sold']?.toString() ?? '0'} منتج'),
              _buildPDFStatBox('هامش الربح', '${(summary['profit_margin'] as num?)?.toStringAsFixed(1) ?? '0.0'}%'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFStatBox(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildPDFTransactions() {
    final invoices = (_supplierReport!['purchase_invoices'] as List?) ?? [];

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'فواتير الشراء',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),

          if (invoices.isEmpty)
            pw.Text('لا توجد فواتير في هذه الفترة')
          else
            pw.Table.fromTextArray(
              context: null,
              data: [
                ['رقم الفاتورة', 'التاريخ', 'المبلغ الإجمالي', 'المبلغ المدفوع', 'الحالة'],
                ...invoices.map((invoice) {
                  return [
                    invoice['invoice_number']?.toString() ?? '',
                    _formatDisplayDate(DateTime.parse(invoice['invoice_date']?.toString() ?? DateTime.now().toString())),
                    '${((invoice['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00')} ر.س',
                    '${((invoice['paid_amount'] as num?)?.toStringAsFixed(2) ?? '0.00')} ر.س',
                    _getStatusText(invoice['status']?.toString() ?? 'pending'),
                  ];
                }).toList(),
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFProducts() {
    final products = (_supplierReport!['top_products'] as List?) ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'أداء المنتجات',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),

        if (products.isEmpty)
          pw.Text('لا توجد منتجات في هذه الفترة')
        else
          pw.Table.fromTextArray(
            context: null,
            data: [
              ['المنتج', 'الكمية المباعة', 'الإيرادات', 'الأرباح', 'الهامش %'],
              ...products.map((product) {
                final revenue = (product['revenue'] as num?)?.toDouble() ?? 0.0;
                final profit = (product['profit'] as num?)?.toDouble() ?? 0.0;
                final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;

                return [
                  product['name']?.toString() ?? '',
                  product['total_sold']?.toString() ?? '0',
                  '${revenue.toStringAsFixed(2)} ر.س',
                  '${profit.toStringAsFixed(2)} ر.س',
                  '${margin.toStringAsFixed(1)}%',
                ];
              }).toList(),
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
      ],
    );
  }

  // دوال مساعدة محسنة
  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  String _formatDisplayDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Color _getInvoiceStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved': return 'معتمدة';
      case 'pending': return 'قيد الانتظار';
      case 'cancelled': return 'ملغية';
      default: return 'مسودة';
    }
  }

  Color _getMarginColor(double margin) {
    if (margin > 30) return Colors.green;
    if (margin > 20) return Colors.blue;
    if (margin > 10) return Colors.orange;
    return Colors.red;
  }

  double _calculateAverageInvoice(Map<String, dynamic> summary) {
    final total = (summary['total_purchases'] as num?)?.toDouble() ?? 0.0;
    final invoices = (_supplierReport!['purchase_invoices'] as List?)?.length ?? 1;
    return total / invoices;
  }

  double _calculateDailySalesRate(Map<String, dynamic> summary) {
    final days = _dateRange.duration.inDays;
    final sold = (summary['total_products_sold'] as num?)?.toDouble() ?? 0.0;
    return days > 0 ? sold / days : 0.0;
  }

  double _calculateProfitPerProduct(Map<String, dynamic> summary) {
    final profit = (summary['total_generated_profit'] as num?)?.toDouble() ?? 0.0;
    final sold = (summary['total_products_sold'] as num?)?.toDouble() ?? 1.0;
    return sold > 0 ? profit / sold : 0.0;
  }

  double _calculatePaymentRatio(Map<String, dynamic> summary) {
    final paid = (summary['total_paid'] as num?)?.toDouble() ?? 0.0;
    final total = (summary['total_purchases'] as num?)?.toDouble() ?? 1.0;
    return total > 0 ? (paid / total) * 100 : 0.0;
  }

  double _calculateInventoryEfficiency(Map<String, dynamic> summary) {
    final sold = (summary['total_products_sold'] as num?)?.toDouble() ?? 0.0;
    final purchased = (summary['total_items_purchased'] as num?)?.toDouble() ?? 1.0;
    return purchased > 0 ? (sold / purchased) * 100 : 0.0;
  }

  List<Map<String, dynamic>> _generateRecommendations(Map<String, dynamic> summary) {
    final recommendations = <Map<String, dynamic>>[];
    final margin = (summary['profit_margin'] as num?)?.toDouble() ?? 0.0;
    final paymentRatio = _calculatePaymentRatio(summary);
    final balance = (summary['remaining_balance'] as num?)?.toDouble() ?? 0.0;
    final efficiency = _calculateInventoryEfficiency(summary);

    if (margin > 20) {
      recommendations.add({
        'type': 'positive',
        'text': 'هامش ربح ممتاز! يمكنك زيادة الكمية المطلوبة من هذا المورد',
      });
    } else if (margin < 5) {
      recommendations.add({
        'type': 'info',
        'text': 'هامش الربح منخفض. فكر في التفاوض على الأسعار أو البحث عن مورد بديل',
      });
    }

    if (paymentRatio < 50) {
      recommendations.add({
        'type': 'info',
        'text': 'معدل السداد منخفض. راجع سياسة السداد مع المورد',
      });
    } else if (paymentRatio > 90) {
      recommendations.add({
        'type': 'positive',
        'text': 'معدل سداد ممتاز! يمكنك التفاوض على شروط أفضل',
      });
    }

    if (balance > 5000) {
      recommendations.add({
        'type': 'info',
        'text': 'رصيد متبقي مرتفع. خطط لبرنامج سداد للرصيد المتبقي',
      });
    }

    if (efficiency < 30) {
      recommendations.add({
        'type': 'info',
        'text': 'كفاءة المخزون منخفضة. راجع كميات الطلب من منتجات هذا المورد',
      });
    }

    if (recommendations.isEmpty) {
      recommendations.add({
        'type': 'positive',
        'text': 'الأداء جيد. استمر في التعامل مع المورد بنفس السياسات',
      });
    }

    return recommendations;
  }
}