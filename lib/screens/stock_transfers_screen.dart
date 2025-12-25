import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../model/stock_transfer.dart';
import '../widgets/status_badge.dart';
import 'add_stock_transfer_screen.dart';

class StockTransfersScreen extends StatefulWidget {
  @override
  _StockTransfersScreenState createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<StockTransfer> _transfers = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dbHelper.getStockTransfers(
          status: _filterStatus == 'all' ? null : _filterStatus
      );

      setState(() {
        _transfers = data.map((e) => StockTransfer.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل تحويلات المخزون: $e');
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteTransfer(int transferId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا التحويل؟'),
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
      final deleteResult = await _dbHelper.deleteStockTransfer(transferId);
      if (deleteResult['success']) {
        _showSuccess(deleteResult['message']);
        _loadTransfers();
      } else {
        _showError(deleteResult['error']);
      }
    }
  }

  Future<void> _approveTransfer(int transferId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الاعتماد'),
        content: Text('هل أنت متأكد من اعتماد هذا التحويل؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('اعتماد', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (result == true) {
      final approveResult = await _dbHelper.approveStockTransfer(transferId);
      if (approveResult['success']) {
        _showSuccess(approveResult['message']);
        _loadTransfers();
      } else {
        _showError(approveResult['error']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تحويلات المخزون'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTransfers,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadTransfers();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('جميع التحويلات')),
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
            MaterialPageRoute(builder: (context) => AddStockTransferScreen()),
          );
          if (result == true) {
            _loadTransfers();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _transfers.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد تحويلات مخزون',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'انقر على زر + لإنشاء تحويل جديد',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadTransfers,
        child: ListView.builder(
          itemCount: _transfers.length,
          padding: EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final transfer = _transfers[index];
            return StockTransferCard(
              transfer: transfer,
              onTap: () => _showTransferDetails(transfer),
              onDelete: () => _deleteTransfer(transfer.id!),
              onApprove: () => _approveTransfer(transfer.id!),
            );
          },
        ),
      ),
    );
  }

  void _showTransferDetails(StockTransfer transfer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StockTransferDetailsSheet(transfer: transfer),
    );
  }
}

class StockTransferCard extends StatelessWidget {
  final StockTransfer transfer;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onApprove;

  const StockTransferCard({
    Key? key,
    required this.transfer,
    required this.onTap,
    required this.onDelete,
    required this.onApprove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(transfer.status),
          child: Icon(
            Icons.swap_horiz,
            color: Colors.white,
          ),
        ),
        title: Text(
          'تحويل #${transfer.transferNumber}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('من: ${transfer.fromWarehouseName}'),
            Text('إلى: ${transfer.toWarehouseName}'),
            Text('عدد المنتجات: ${transfer.totalItems}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: transfer.status),
            if (transfer.status == 'draft') ...[
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.check, color: Colors.green, size: 20),
                onPressed: onApprove,
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: onDelete,
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

class StockTransferDetailsSheet extends StatefulWidget {
  final StockTransfer transfer;

  const StockTransferDetailsSheet({Key? key, required this.transfer}) : super(key: key);

  @override
  _StockTransferDetailsSheetState createState() => _StockTransferDetailsSheetState();
}

class _StockTransferDetailsSheetState extends State<StockTransferDetailsSheet> {
  Map<String, dynamic>? _transferDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransferDetails();
  }

  Future<void> _loadTransferDetails() async {
    final dbHelper = DatabaseHelper();
    final details = await dbHelper.getStockTransferWithItems(widget.transfer.id!);
    setState(() {
      _transferDetails = details;
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
                'تحويل مخزون #${widget.transfer.transferNumber}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              StatusBadge(status: widget.transfer.status),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildTransferContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferContent() {
    final transfer = _transferDetails!['transfer'];
    final items = _transferDetails!['items'] as List<dynamic>;

    return Column(
      children: [
        _buildInfoRow('المخزن المصدر', transfer['from_warehouse_name']),
        _buildInfoRow('المخزن الهدف', transfer['to_warehouse_name']),
        _buildInfoRow('عدد المنتجات', '${transfer['total_items']}'),
        _buildInfoRow('الحالة', _getStatusText(transfer['status'])),
        if (transfer['notes'] != null) _buildInfoRow('ملاحظات', transfer['notes']),

        SizedBox(height: 16),
        Divider(),
        Text('المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),

        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(item['product_name']),
                  subtitle: Text('الكمية: ${item['quantity']}'),
                  trailing: Text('${item['sell_price'] ?? 0} ريال'),
                ),
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