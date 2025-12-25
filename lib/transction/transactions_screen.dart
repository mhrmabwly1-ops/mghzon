import 'package:flutter/material.dart';
import '../color.dart';
import '../database_helper.dart';


class TransactionsScreen extends StatefulWidget {
  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await _dbHelper.getRecentTransactions();
      setState(() {
        _transactions = transactions;
        _filteredTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('خطأ في تحميل المعاملات: $e', isError: true);
    }
  }

  void _filterTransactions() {
    List<Map<String, dynamic>> filtered = _transactions;

    // Filter by type
    if (_selectedFilter != 'all') {
      filtered = filtered.where((transaction) => transaction['type'] == _selectedFilter).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((transaction) {
        final productName = transaction['product_name']?.toString().toLowerCase() ?? '';
        final customerName = transaction['customer_name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return productName.contains(query) || customerName.contains(query);
      }).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((transaction) {
        try {
          final transactionDate = DateTime.parse(transaction['date']);
          return transactionDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
                 transactionDate.isBefore(_endDate!.add(Duration(days: 1)));
        } catch (e) {
          return true;
        }
      }).toList();
    }

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      currentDate: DateTime.now(),
      saveText: 'تطبيق',
      helpText: 'اختر فترة التاريخ',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterTransactions();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = 'all';
      _searchQuery = '';
      _startDate = null;
      _endDate = null;
      _filteredTransactions = _transactions;
    });
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'sale': return Colors.green;
      case 'purchase': return Colors.blue;
      case 'return': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'sale': return Icons.shopping_cart;
      case 'purchase': return Icons.shopping_bag;
      case 'return': return Icons.undo;
      default: return Icons.receipt;
    }
  }

  String _getTransactionTypeText(String type) {
    switch (type) {
      case 'sale': return 'بيع';
      case 'purchase': return 'شراء';
      case 'return': return 'مرتجع';
      default: return 'غير معروف';
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

  Future<void> _deleteTransaction(int transactionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذه المعاملة؟'),
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
        final result = await _dbHelper.deleteTransaction(transactionId);
        if (result > 0) {
          _showSnackBar('تم حذف المعاملة بنجاح', isError: false);
          _loadTransactions();
        } else {
          _showSnackBar('فشل في حذف المعاملة');
        }
      } catch (e) {
        _showSnackBar('خطأ في حذف المعاملة: $e');
      }
    }
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => TransactionDetailsDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text('إدارة المعاملات'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          // فلاتر البحث
          _buildSearchAndFilters(),
          
          // إحصائيات سريعة
          _buildQuickStats(),
          
          // قائمة المعاملات
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : _buildTransactionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // شريط البحث
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث في المعاملات...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _filterTransactions();
              },
            ),
            SizedBox(height: 12),
            
            // الفلاتر
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    decoration: InputDecoration(
                      labelText: 'نوع المعاملة',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('جميع المعاملات')),
                      DropdownMenuItem(value: 'sale', child: Text('مبيعات')),
                      DropdownMenuItem(value: 'purchase', child: Text('مشتريات')),
                      DropdownMenuItem(value: 'return', child: Text('مرتجعات')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedFilter = value!);
                      _filterTransactions();
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _startDate == null 
                          ? 'اختر الفترة' 
                          : '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.clear, color: Colors.red),
                  onPressed: _clearFilters,
                  tooltip: 'مسح الفلاتر',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalTransactions = _filteredTransactions.length;
    final salesCount = _filteredTransactions.where((t) => t['type'] == 'sale').length;
    final purchasesCount = _filteredTransactions.where((t) => t['type'] == 'purchase').length;
    final returnsCount = _filteredTransactions.where((t) => t['type'] == 'return').length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildStatChip('الإجمالي', totalTransactions.toString(), AppColors.primary),
          ),
          Expanded(
            child: _buildStatChip('المبيعات', salesCount.toString(), Colors.green),
          ),
          Expanded(
            child: _buildStatChip('المشتريات', purchasesCount.toString(), Colors.blue),
          ),
          Expanded(
            child: _buildStatChip('المرتجعات', returnsCount.toString(), Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'لا توجد معاملات',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'قم بإضافة معاملات جديدة لعرضها هنا',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getTransactionColor(transaction['type']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getTransactionIcon(transaction['type']), 
                     color: _getTransactionColor(transaction['type']), size: 20),
        ),
        title: Text(
          transaction['product_name'] ?? 'غير معروف',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction['customer_name'] != null)
              Text('العميل: ${transaction['customer_name']}'),
            Text('الكمية: ${transaction['quantity']}'),
            Text('السعر: ${_formatPrice(transaction['unit_sell_price'] ?? transaction['unit_purchase_price'])} ر.س'),
            if (transaction['profit'] != null && transaction['profit'] != 0) 
              Text('الربح: ${_formatPrice(transaction['profit'])} ر.س', 
                   style: TextStyle(
                     color: (transaction['profit'] as double) >= 0 ? Colors.green : Colors.red,
                     fontWeight: FontWeight.bold
                   )),
            Text('التاريخ: ${_formatDateString(transaction['date'])}', 
                 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.blue, size: 20),
              onPressed: () => _showTransactionDetails(transaction),
              tooltip: 'عرض التفاصيل',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteTransaction(transaction['id']),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    final number = double.tryParse(price.toString()) ?? 0.0;
    return number.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}

class TransactionDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsDialog({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'تفاصيل المعاملة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // المعلومات الأساسية
              _buildDetailRow('المنتج', transaction['product_name'] ?? 'غير معروف'),
              _buildDetailRow('نوع المعاملة', _getTransactionTypeText(transaction['type'])),
              _buildDetailRow('الكمية', transaction['quantity']?.toString() ?? '0'),
              
              // التسعير
              if (transaction['unit_sell_price'] != null)
                _buildDetailRow('سعر البيع', '${_formatPrice(transaction['unit_sell_price'])} ر.س'),
              if (transaction['unit_purchase_price'] != null)
                _buildDetailRow('سعر الشراء', '${_formatPrice(transaction['unit_purchase_price'])} ر.س'),
              if (transaction['total_amount'] != null)
                _buildDetailRow('المبلغ الإجمالي', '${_formatPrice(transaction['total_amount'])} ر.س'),
              
              // الربح
              if (transaction['profit'] != null && transaction['profit'] != 0)
                _buildDetailRow(
                  'الربح', 
                  '${_formatPrice(transaction['profit'])} ر.س',
                  color: (transaction['profit'] as double) >= 0 ? Colors.green : Colors.red
                ),
              
              // العميل
              if (transaction['customer_name'] != null)
                _buildDetailRow('العميل', transaction['customer_name']),
              
              // التاريخ
              _buildDetailRow('التاريخ', _formatDateString(transaction['date'])),
              
              SizedBox(height: 20),
              
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.black87, fontWeight: color != null ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  String _getTransactionTypeText(String type) {
    switch (type) {
      case 'sale': return 'بيع';
      case 'purchase': return 'شراء';
      case 'return': return 'مرتجع';
      default: return 'غير معروف';
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    final number = double.tryParse(price.toString()) ?? 0.0;
    return number.toStringAsFixed(2);
  }

  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}