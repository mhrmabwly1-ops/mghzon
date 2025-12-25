
import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../widgets/status_badge.dart';
import 'add_sales_return_screen.dart';


class SalesReturnsScreen extends StatefulWidget {
  @override
  _SalesReturnsScreenState createState() => _SalesReturnsScreenState();
}

class _SalesReturnsScreenState extends State<SalesReturnsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _returns = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dbHelper.getSalesReturns(
          status: _filterStatus == 'all' ? null : _filterStatus
      );

      setState(() {
        _returns = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل المرتجعات: $e');
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

  Future<void> _deleteReturn(int returnId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا المرتجع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      final deleteResult = await _dbHelper.deleteSalesReturn(returnId);
      if (deleteResult['success']) {
        _loadReturns();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleteResult['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError(deleteResult['error']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مرتجعات البيع'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReturns,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadReturns();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('جميع المرتجعات')),
              PopupMenuItem(value: 'draft', child: Text('مسودة')),
              PopupMenuItem(value: 'approved', child: Text('معتمدة')),
              PopupMenuItem(value: 'cancelled', child: Text('ملغاة')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddSalesReturnScreen()),
          );
          if (result == true) {
            _loadReturns();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _returns.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد مرتجعات بيع',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadReturns,
        child: ListView.builder(
          itemCount: _returns.length,
          padding: EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final returnData = _returns[index];
            return SalesReturnCard(
              returnData: returnData,
              onTap: () => _showReturnDetails(returnData),
              onDelete: () => _deleteReturn(returnData['id']),
            );
          },
        ),
      ),
    );
  }

  void _showReturnDetails(Map<String, dynamic> returnData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SalesReturnDetailsSheet(returnData: returnData),
    );
  }
}

class SalesReturnCard extends StatelessWidget {
  final Map<String, dynamic> returnData;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SalesReturnCard({
    Key? key,
    required this.returnData,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(returnData['status']),
          child: Icon(
            Icons.assignment_return,
            color: Colors.white,
          ),
        ),
        title: Text(
          'مرتجع #${returnData['return_number']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فاتورة البيع: ${returnData['sale_invoice_number']}'),
            Text('العميل: ${returnData['customer_name'] ?? 'غير محدد'}'),
            Text('المبلغ: ${returnData['total_amount']} ريال'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: returnData['status']),
            if (returnData['status'] == 'draft') ...[
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
                iconSize: 20,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }
}

class SalesReturnDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> returnData;

  const SalesReturnDetailsSheet({Key? key, required this.returnData}) : super(key: key);

  @override
  _SalesReturnDetailsSheetState createState() => _SalesReturnDetailsSheetState();
}

class _SalesReturnDetailsSheetState extends State<SalesReturnDetailsSheet> {
  Map<String, dynamic>? _returnDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReturnDetails();
  }

  Future<void> _loadReturnDetails() async {
    final dbHelper = DatabaseHelper();
    final details = await dbHelper.getSalesReturnWithItems(widget.returnData['id']);
    setState(() {
      _returnDetails = details;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.8,
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مرتجع بيع #${widget.returnData['return_number']}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              StatusBadge(status: widget.returnData['status']),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildReturnContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnContent() {
    final salesReturn = _returnDetails!['sales_return'];
    final items = _returnDetails!['items'] as List<dynamic>;

    return Column(
      children: [
        _buildInfoRow('رقم فاتورة البيع', salesReturn['sale_invoice_number']),
        _buildInfoRow('العميل', salesReturn['customer_name'] ?? 'غير محدد'),
        _buildInfoRow('المخزن', salesReturn['warehouse_name']),
        _buildInfoRow('المبلغ الإجمالي', '${salesReturn['total_amount']} ريال'),
        _buildInfoRow('السبب', salesReturn['reason'] ?? 'غير محدد'),
        _buildInfoRow('الحالة', _getStatusText(salesReturn['status'])),

        SizedBox(height: 16),
        Divider(),
        Text('البنود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),

        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(item['product_name']),
                subtitle: Text('الكمية: ${item['quantity']} - السعر: ${item['unit_price']}'),
                trailing: Text('${item['total_price']} ريال'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved': return 'معتمدة';
      case 'cancelled': return 'ملغاة';
      default: return 'مسودة';
    }
  }
}