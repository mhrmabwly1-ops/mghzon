class PurchaseInvoice {
  final int? id;
  final String invoiceNumber;
  final int supplierId;
  final int warehouseId;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final String? notes;
  final DateTime invoiceDate;
  final DateTime createdAt;
  final String? supplierName;
  final String? warehouseName;

  PurchaseInvoice({
    this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.warehouseId,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.status = 'draft',
    this.notes,
    required this.invoiceDate,
    required this.createdAt,
    this.supplierName,
    this.warehouseName,
  });

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      supplierId: map['supplier_id'],
      warehouseId: map['warehouse_id'],
      totalAmount: map['total_amount']?.toDouble() ?? 0,
      paidAmount: map['paid_amount']?.toDouble() ?? 0,
      status: map['status'] ?? 'draft',
      notes: map['notes'],
      invoiceDate: DateTime.parse(map['invoice_date']),
      createdAt: DateTime.parse(map['created_at']),
      supplierName: map['supplier_name'],
      warehouseName: map['warehouse_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'supplier_id': supplierId,
      'warehouse_id': warehouseId,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'status': status,
      'notes': notes,
      'invoice_date': invoiceDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class PurchaseInvoiceItem {
  final int? id;
  final int purchaseInvoiceId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productName;
  final String? barcode;

  PurchaseInvoiceItem({
    this.id,
    required this.purchaseInvoiceId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productName,
    this.barcode,
  });

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceItem(
      id: map['id'],
      purchaseInvoiceId: map['purchase_invoice_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      unitPrice: map['unit_price']?.toDouble() ?? 0,
      totalPrice: map['total_price']?.toDouble() ?? 0,
      productName: map['product_name'],
      barcode: map['barcode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_invoice_id': purchaseInvoiceId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}