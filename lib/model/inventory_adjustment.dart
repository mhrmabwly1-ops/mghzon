class InventoryAdjustment {
  final int? id;
  final String adjustmentNumber;
  final int warehouseId;
  final String adjustmentType;
  final int totalItems;
  final String reason;
  final String status;
  final DateTime adjustmentDate;
  final DateTime createdAt;
  final String? warehouseName;
  final String? createdByName;

  InventoryAdjustment({
    this.id,
    required this.adjustmentNumber,
    required this.warehouseId,
    required this.adjustmentType,
    this.totalItems = 0,
    required this.reason,
    this.status = 'draft',
    required this.adjustmentDate,
    required this.createdAt,
    this.warehouseName,
    this.createdByName,
  });

  factory InventoryAdjustment.fromMap(Map<String, dynamic> map) {
    return InventoryAdjustment(
      id: map['id'],
      adjustmentNumber: map['adjustment_number'],
      warehouseId: map['warehouse_id'],
      adjustmentType: map['adjustment_type'],
      totalItems: map['total_items'] ?? 0,
      reason: map['reason'],
      status: map['status'] ?? 'draft',
      adjustmentDate: DateTime.parse(map['adjustment_date']),
      createdAt: DateTime.parse(map['created_at']),
      warehouseName: map['warehouse_name'],
      createdByName: map['created_by_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adjustment_number': adjustmentNumber,
      'warehouse_id': warehouseId,
      'adjustment_type': adjustmentType,
      'total_items': totalItems,
      'reason': reason,
      'status': status,
      'adjustment_date': adjustmentDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AdjustmentItem {
  final int? id;
  final int adjustmentId;
  final int productId;
  final int currentQuantity;
  final int newQuantity;
  final int difference;
  final String? productName;
  final String? barcode;
  final double? sellPrice;

  AdjustmentItem({
    this.id,
    required this.adjustmentId,
    required this.productId,
    required this.currentQuantity,
    required this.newQuantity,
    required this.difference,
    this.productName,
    this.barcode,
    this.sellPrice,
  });

  factory AdjustmentItem.fromMap(Map<String, dynamic> map) {
    return AdjustmentItem(
      id: map['id'],
      adjustmentId: map['adjustment_id'],
      productId: map['product_id'],
      currentQuantity: map['current_quantity'] ?? 0,
      newQuantity: map['new_quantity'] ?? 0,
      difference: map['difference'] ?? 0,
      productName: map['product_name'],
      barcode: map['barcode'],
      sellPrice: map['sell_price']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adjustment_id': adjustmentId,
      'product_id': productId,
      'current_quantity': currentQuantity,
      'new_quantity': newQuantity,
    };
  }
}