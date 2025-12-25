import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../model/purchase_invoice.dart';
import '../widgets/invoice_card.dart';
import '../widgets/status_badge.dart';
import 'add_purchase_invoice_screen.dart';

class PurchaseInvoicesScreen extends StatefulWidget {
  @override
  _PurchaseInvoicesScreenState createState() => _PurchaseInvoicesScreenState();
}

class _PurchaseInvoicesScreenState extends State<PurchaseInvoicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<PurchaseInvoice> _invoices = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dbHelper.getPurchaseInvoices(
        status: _filterStatus == 'all' ? null : _filterStatus
      );

      setState(() {
        _invoices = data.map((e) => PurchaseInvoice.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل الفواتير: $e');
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

  Future<void> _deleteInvoice(int invoiceId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذه الفاتورة؟'),
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
      final deleteResult = await _dbHelper.deletePurchaseInvoice(invoiceId);
      if (deleteResult['success']) {
        _showSuccess(deleteResult['message']);
        _loadInvoices();
      } else {
        _showError(deleteResult['error']);
      }
    }
  }

  Future<void> _approveInvoice(int invoiceId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الاعتماد'),
        content: Text('هل أنت متأكد من اعتماد هذه الفاتورة؟'),
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
      final approveResult = await _dbHelper.approvePurchaseInvoice(invoiceId);
      if (approveResult['success']) {
        _showSuccess(approveResult['message']);
        _loadInvoices();
      } else {
        _showError(approveResult['error']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فواتير الشراء'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInvoices,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadInvoices();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('جميع الفواتير')),
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
            MaterialPageRoute(builder: (context) => AddPurchaseInvoiceScreen()),
          );
          if (result == true) {
            _loadInvoices();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد فواتير شراء',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'انقر على زر + لإنشاء فاتورة جديدة',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInvoices,
                  child: ListView.builder(
                    itemCount: _invoices.length,
                    padding: EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      return PurchaseInvoiceCard(
                        invoice: invoice,
                        onTap: () => _showInvoiceDetails(invoice),
                        onDelete: () => _deleteInvoice(invoice.id!),
                        onApprove: () => _approveInvoice(invoice.id!),
                      );
                    },
                  ),
                ),
    );
  }

  void _showInvoiceDetails(PurchaseInvoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PurchaseInvoiceDetailsSheet(invoice: invoice),
    );
  }
}

class PurchaseInvoiceCard extends StatelessWidget {
  final PurchaseInvoice invoice;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onApprove;

  const PurchaseInvoiceCard({
    Key? key,
    required this.invoice,
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
          backgroundColor: _getStatusColor(invoice.status),
          child: Icon(
            Icons.inventory_2,
            color: Colors.white,
          ),
        ),
        title: Text(
          'فاتورة #${invoice.invoiceNumber}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invoice.supplierName ?? 'بدون مورد'),
            Text('المبلغ: ${invoice.totalAmount} ريال'),
            Text('التاريخ: ${_formatDate(invoice.createdAt)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: invoice.status),
            if (invoice.status == 'draft') ...[
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class PurchaseInvoiceDetailsSheet extends StatefulWidget {
  final PurchaseInvoice invoice;

  const PurchaseInvoiceDetailsSheet({Key? key, required this.invoice}) : super(key: key);

  @override
  _PurchaseInvoiceDetailsSheetState createState() => _PurchaseInvoiceDetailsSheetState();
}

class _PurchaseInvoiceDetailsSheetState extends State<PurchaseInvoiceDetailsSheet> {
  Map<String, dynamic>? _invoiceDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    final dbHelper = DatabaseHelper();
    final details = await dbHelper.getPurchaseInvoiceWithItems(widget.invoice.id!);
    setState(() {
      _invoiceDetails = details;
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
                      'فاتورة شراء #${widget.invoice.invoiceNumber}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    StatusBadge(status: widget.invoice.status),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: _buildInvoiceContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildInvoiceContent() {
    final invoice = _invoiceDetails!['invoice'];
    final items = _invoiceDetails!['items'] as List<dynamic>;

    return Column(
      children: [
        _buildInfoRow('المورد', invoice['supplier_name']),
        _buildInfoRow('المخزن', invoice['warehouse_name']),
        _buildInfoRow('المبلغ الإجمالي', '${invoice['total_amount']} ريال'),
        _buildInfoRow('المبلغ المدفوع', '${invoice['paid_amount']} ريال'),
        _buildInfoRow('الحالة', _getStatusText(invoice['status'])),

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