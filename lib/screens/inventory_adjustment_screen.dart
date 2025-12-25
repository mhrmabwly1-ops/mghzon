import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../model/inventory_adjustment.dart';
import '../widgets/status_badge.dart';
import 'add_inventory_adjustment_screen.dart';

class InventoryAdjustmentScreen extends StatefulWidget {
  @override
  _InventoryAdjustmentScreenState createState() => _InventoryAdjustmentScreenState();
}

class _InventoryAdjustmentScreenState extends State<InventoryAdjustmentScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<InventoryAdjustment> _adjustments = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadAdjustments();
  }

  Future<void> _loadAdjustments() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dbHelper.getInventoryAdjustments(
          status: _filterStatus == 'all' ? null : _filterStatus
      );

      setState(() {
        _adjustments = data.map((e) => InventoryAdjustment.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل تعديلات الجرد: $e');
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

  Future<void> _deleteAdjustment(int adjustmentId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا التعديل؟'),
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
      final deleteResult = await _dbHelper.deleteInventoryAdjustment(adjustmentId);
      if (deleteResult['success']) {
        _showSuccess(deleteResult['message']);
        _loadAdjustments();
      } else {
        _showError(deleteResult['error']);
      }
    }
  }

  Future<void> _approveAdjustment(int adjustmentId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الاعتماد'),
        content: Text('هل أنت متأكد من اعتماد هذا التعديل؟'),
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
      final approveResult = await _dbHelper.approveInventoryAdjustment(adjustmentId);
      if (approveResult['success']) {
        _showSuccess(approveResult['message']);
        _loadAdjustments();
      } else {
        _showError(approveResult['error']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('جرد المخزون'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAdjustments,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadAdjustments();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('جميع التعديلات')),
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
            MaterialPageRoute(builder: (context) => AddInventoryAdjustmentScreen()),
          );
          if (result == true) {
            _loadAdjustments();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _adjustments.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد تعديلات جرد',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'انقر على زر + لإنشاء تعديل جرد جديد',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAdjustments,
        child: ListView.builder(
          itemCount: _adjustments.length,
          padding: EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final adjustment = _adjustments[index];
            return InventoryAdjustmentCard(
              adjustment: adjustment,
              onTap: () => _showAdjustmentDetails(adjustment),
              onDelete: () => _deleteAdjustment(adjustment.id!),
              onApprove: () => _approveAdjustment(adjustment.id!),
            );
          },
        ),
      ),
    );
  }

  void _showAdjustmentDetails(InventoryAdjustment adjustment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InventoryAdjustmentDetailsSheet(adjustment: adjustment),
    );
  }
}

class InventoryAdjustmentCard extends StatelessWidget {
  final InventoryAdjustment adjustment;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onApprove;

  const InventoryAdjustmentCard({
    Key? key,
    required this.adjustment,
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
          backgroundColor: _getStatusColor(adjustment.status),
          child: Icon(
            _getAdjustmentIcon(adjustment.adjustmentType),
            color: Colors.white,
          ),
        ),
        title: Text(
          'تعديل #${adjustment.adjustmentNumber}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المخزن: ${adjustment.warehouseName}'),
            Text('النوع: ${_getAdjustmentTypeText(adjustment.adjustmentType)}'),
            Text('السبب: ${adjustment.reason}'),
            Text('عدد المنتجات: ${adjustment.totalItems}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: adjustment.status),
            if (adjustment.status == 'draft') ...[
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

  IconData _getAdjustmentIcon(String type) {
    switch (type) {
      case 'increase': return Icons.add;
      case 'decrease': return Icons.remove;
      case 'correction': return Icons.edit;
      default: return Icons.inventory_2;
    }
  }

  String _getAdjustmentTypeText(String type) {
    switch (type) {
      case 'increase': return 'زيادة';
      case 'decrease': return 'نقصان';
      case 'correction': return 'تصحيح';
      default: return type;
    }
  }
}

class InventoryAdjustmentDetailsSheet extends StatefulWidget {
  final InventoryAdjustment adjustment;

  const InventoryAdjustmentDetailsSheet({Key? key, required this.adjustment}) : super(key: key);

  @override
  _InventoryAdjustmentDetailsSheetState createState() => _InventoryAdjustmentDetailsSheetState();
}

class _InventoryAdjustmentDetailsSheetState extends State<InventoryAdjustmentDetailsSheet> {
  Map<String, dynamic>? _adjustmentDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdjustmentDetails();
  }

  Future<void> _loadAdjustmentDetails() async {
    final dbHelper = DatabaseHelper();
    final details = await dbHelper.getInventoryAdjustmentWithItems(widget.adjustment.id!);
    setState(() {
      _adjustmentDetails = details;
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
                'تعديل جرد #${widget.adjustment.adjustmentNumber}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              StatusBadge(status: widget.adjustment.status),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: _buildAdjustmentContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentContent() {
    final adjustment = _adjustmentDetails!['adjustment'];
    final items = _adjustmentDetails!['items'] as List<dynamic>;

    return Column(
      children: [
        _buildInfoRow('المخزن', adjustment['warehouse_name']),
        _buildInfoRow('نوع التعديل', _getAdjustmentTypeText(adjustment['adjustment_type'])),
        _buildInfoRow('السبب', adjustment['reason']),
        _buildInfoRow('عدد المنتجات', '${adjustment['total_items']}'),
        _buildInfoRow('الحالة', _getStatusText(adjustment['status'])),

        SizedBox(height: 16),
        Divider(),
        Text('المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),

        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final difference = item['difference'] as int;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getDifferenceColor(difference),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(item['product_name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الكمية الحالية: ${item['current_quantity']}'),
                      Text('الكمية الجديدة: ${item['new_quantity']}'),
                      Text(
                        'الفرق: ${difference > 0 ? '+' : ''}$difference',
                        style: TextStyle(
                          color: _getDifferenceColor(difference),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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

  String _getAdjustmentTypeText(String type) {
    switch (type) {
      case 'increase': return 'زيادة';
      case 'decrease': return 'نقصان';
      case 'correction': return 'تصحيح';
      default: return type;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved': return 'معتمدة';
      case 'cancelled': return 'ملغاة';
      default: return 'مسودة';
    }
  }

  Color _getDifferenceColor(int difference) {
    if (difference > 0) return Colors.green;
    if (difference < 0) return Colors.red;
    return Colors.grey;
  }
}