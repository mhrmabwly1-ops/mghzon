// في lib/widgets/invoice_card.dart
import 'package:flutter/material.dart';
import '../model/sale_invoice.dart';
import 'status_badge.dart';

class InvoiceCard extends StatelessWidget {
  final SaleInvoice invoice;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String type;

  const InvoiceCard({
    Key? key,
    required this.invoice,
    required this.onTap,
    required this.onDelete,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // استخدام getter آمن
    final customerName = invoice.customerName ??
        (invoice.customerId == null ? 'نقدي' : 'عميل #${invoice.customerId}');

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(invoice.status),
          child: Icon(
            type == 'sale' ? Icons.shopping_cart : Icons.inventory_2,
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
            Text(customerName),  // استخدام المتغير الآمن
            Text('المبلغ: ${invoice.totalAmount.toStringAsFixed(2)} ريال'),
            Text('التاريخ: ${_formatDate(invoice.createdAt)}'), // createdAt مؤكد أنه غير null
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: invoice.status),
            if (invoice.status == 'draft') ...[
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}