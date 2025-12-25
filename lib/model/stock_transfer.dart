class StockTransfer {
  final int? id;
  final String transferNumber;
  final int fromWarehouseId;
  final int toWarehouseId;
  final int totalItems;
  final String status;
  final DateTime transferDate;
  final String? notes;
  final DateTime createdAt;
  final String? fromWarehouseName;
  final String? toWarehouseName;
  final String? createdByName;

  StockTransfer({
    this.id,
    required this.transferNumber,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    this.totalItems = 0,
    this.status = 'draft',
    required this.transferDate,
    this.notes,
    required this.createdAt,
    this.fromWarehouseName,
    this.toWarehouseName,
    this.createdByName,
  });

  factory StockTransfer.fromMap(Map<String, dynamic> map) {
    return StockTransfer(
      id: map['id'],
      transferNumber: map['transfer_number'],
      fromWarehouseId: map['from_warehouse_id'],
      toWarehouseId: map['to_warehouse_id'],
      totalItems: map['total_items'] ?? 0,
      status: map['status'] ?? 'draft',
      transferDate: DateTime.parse(map['transfer_date']),
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      fromWarehouseName: map['from_warehouse_name'],
      toWarehouseName: map['to_warehouse_name'],
      createdByName: map['created_by_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transfer_number': transferNumber,
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'total_items': totalItems,
      'status': status,
      'transfer_date': transferDate.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class StockTransferItem {
  final int? id;
  final int stockTransferId;
  final int productId;
  final int quantity;
  final String? productName;
  final String? barcode;
  final double? sellPrice;

  StockTransferItem({
    this.id,
    required this.stockTransferId,
    required this.productId,
    required this.quantity,
    this.productName,
    this.barcode,
    this.sellPrice,
  });

  factory StockTransferItem.fromMap(Map<String, dynamic> map) {
    return StockTransferItem(
      id: map['id'],
      stockTransferId: map['stock_transfer_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      productName: map['product_name'],
      barcode: map['barcode'],
      sellPrice: map['sell_price']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stock_transfer_id': stockTransferId,
      'product_id': productId,
      'quantity': quantity,
    };
  }
}