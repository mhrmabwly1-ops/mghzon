import 'package:flutter/material.dart';

import '../../widgets/invoice_card.dart';
import '../../widgets/status_badge.dart';
import '../database_helper.dart';
import '../model/sale_invoice.dart';
import 'add_saleInvoice_screen.dart';


class SalesInvoicesScreen extends StatefulWidget {
  @override
  _SalesInvoicesScreenState createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<SaleInvoice> _invoices = [];
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
      final data = await _dbHelper.getSaleInvoices(
          status: _filterStatus == 'all' ? null : _filterStatus
      );

      setState(() {
        _invoices = data.map((e) => SaleInvoice.fromMap(e)).toList();
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
      final deleteResult = await _dbHelper.deleteSaleInvoice(invoiceId);
      if (deleteResult['success']) {
        _showSuccess(deleteResult['message']);
        _loadInvoices();
      } else {
        _showError(deleteResult['error']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فواتير البيع'),
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
            MaterialPageRoute(builder: (context) => AddSaleInvoiceScreen()),
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
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد فواتير بيع',
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
            return InvoiceCard(
              invoice: invoice,
              onTap: () => _showInvoiceDetails(invoice),
              onDelete: () => _deleteInvoice(invoice.id!),
              type: 'sale',
            );
          },
        ),
      ),
    );
  }

  void _showInvoiceDetails(SaleInvoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceDetailsSheet(invoice: invoice),
    );
  }
}

class InvoiceDetailsSheet extends StatefulWidget {
  final SaleInvoice invoice;

  const InvoiceDetailsSheet({Key? key, required this.invoice}) : super(key: key);

  @override
  _InvoiceDetailsSheetState createState() => _InvoiceDetailsSheetState();
}

class _InvoiceDetailsSheetState extends State<InvoiceDetailsSheet> {
  Map<String, dynamic>? _invoiceDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    final dbHelper = DatabaseHelper();
    final details = await dbHelper.getSaleInvoiceWithItems(widget.invoice.id!);
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
                'فاتورة #${widget.invoice.invoiceNumber}',
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
        _buildInfoRow('العميل', invoice['customer_name'] ?? 'غير محدد'),
        _buildInfoRow('المخزن', invoice['warehouse_name']),
        _buildInfoRow('طريقة الدفع', _getPaymentMethodText(invoice['payment_method'])),
        _buildInfoRow('المبلغ الإجمالي', '${invoice['total_amount']} ريال'),
        _buildInfoRow('المبلغ المدفوع', '${invoice['paid_amount']} ريال'),
        _buildInfoRow('الخصم', '${invoice['discount']} ريال'),

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
                subtitle: Text('الكمية: ${item['quantity']}'),
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

  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'cash': return 'نقدي';
      case 'credit': return 'آجل';
      case 'transfer': return 'تحويل';
      default: return method;
    }
  }
}