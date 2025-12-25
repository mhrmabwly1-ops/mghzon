import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
class SaleInvoice {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final int warehouseId;
  final double totalAmount;
  final double paidAmount;
  final double discountAmount;
  final double discountPercent;
  final double taxPercent;
  final double taxAmount;
  final String status;
  final String paymentMethod;
  final String? notes;
  final DateTime invoiceDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? createdBy;
  final double totalCost;
  final double totalProfit;

  // حقول من JOIN
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? warehouseName;
  final String? createdByName;

  SaleInvoice({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.warehouseId,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.taxPercent = 15,
    this.taxAmount = 0,
    this.status = 'draft',
    this.paymentMethod = 'cash',
    this.notes,
    required this.invoiceDate,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.totalCost = 0,
    this.totalProfit = 0,

    // حقول JOIN
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.warehouseName,
    this.createdByName,
  });

  factory SaleInvoice.fromMap(Map<String, dynamic> map) {
    return SaleInvoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      customerId: map['customer_id'] as int?,
      warehouseId: map['warehouse_id'] as int? ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
      taxPercent: (map['tax_percent'] as num?)?.toDouble() ?? 15,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'draft',
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      notes: map['notes'] as String?,
      invoiceDate: map['invoice_date'] != null
          ? DateTime.parse(map['invoice_date'] as String)
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      createdBy: map['created_by'] as int?,
      // الحقول المحسوبة - ستتم إضافتها لاحقاً عند جلب بنود الفاتورة
      totalCost: 0, // ستتم حسابه لاحقاً
      totalProfit: 0, // ستتم حسابه لاحقاً

      // حقول JOIN
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      customerEmail: map['customer_email'] as String?,
      warehouseName: map['warehouse_name'] as String?,
      createdByName: map['created_by_name'] as String?,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'warehouse_id': warehouseId,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'discount_amount': discountAmount,
      'discount_percent': discountPercent,
      'tax_percent': taxPercent,
      'tax_amount': taxAmount,
      'status': status,
      'payment_method': paymentMethod,
      'notes': notes,
      'invoice_date': invoiceDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
      // لاحظ: لا نرسل totalCost و totalProfit إلى قاعدة البيانات
      // لأنهما سيتحسبان من بنود الفاتورة
    };
  }

  // Getters مفيدة
  String get customerDisplayName {
    return customerName ?? (customerId == null ? 'نقدي' : 'عميل #$customerId');
  }

  double get remainingAmount {
    return totalAmount - paidAmount;
  }

  double get paymentPercentage {
    return totalAmount > 0 ? (paidAmount / totalAmount) * 100 : 0;
  }

  String get formattedDate {
    return DateFormat('yyyy/MM/dd').format(createdAt);
  }

  String get formattedTime {
    return DateFormat('hh:mm a').format(createdAt);
  }

  String get fullFormattedDate {
    return DateFormat('yyyy/MM/dd - hh:mm a').format(createdAt);
  }

  String get invoiceDateFormatted {
    return DateFormat('yyyy/MM/dd').format(invoiceDate);
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'pending':
      case 'partial':
        return Colors.orange;
      case 'draft':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      case 'partial':
        return Icons.pending;
      case 'draft':
        return Icons.edit;
      default:
        return Icons.receipt;
    }
  }

  String get paymentMethodText {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return 'نقدي';
      case 'credit':
        return 'آجل';
      case 'transfer':
        return 'تحويل بنكي';
      default:
        return paymentMethod;
    }
  }

  IconData get paymentMethodIcon {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'credit':
        return Icons.credit_card;
      case 'transfer':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  bool get isPaid {
    return paidAmount >= totalAmount;
  }

  bool get isPartiallyPaid {
    return paidAmount > 0 && paidAmount < totalAmount;
  }

  bool get isUnpaid {
    return paidAmount == 0;
  }

  bool get isCredit {
    return paymentMethod == 'credit';
  }

  bool get canDelete {
    return status == 'draft';
  }

  bool get canEdit {
    return status == 'draft' || status == 'pending';
  }

  bool get canApprove {
    return status == 'draft' || status == 'pending';
  }

  bool get canCancel {
    return status != 'cancelled' && status != 'rejected';
  }

  // Methods
  SaleInvoice copyWith({
    int? id,
    String? invoiceNumber,
    int? customerId,
    int? warehouseId,
    double? totalAmount,
    double? paidAmount,
    double? discountAmount,
    double? discountPercent,
    double? taxPercent,
    double? taxAmount,
    String? status,
    String? paymentMethod,
    String? notes,
    DateTime? invoiceDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? createdBy,
    double? totalCost,
    double? totalProfit,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? warehouseName,
    String? createdByName,
  }) {
    return SaleInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      warehouseId: warehouseId ?? this.warehouseId,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      taxPercent: taxPercent ?? this.taxPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      totalCost: totalCost ?? this.totalCost,
      totalProfit: totalProfit ?? this.totalProfit,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      warehouseName: warehouseName ?? this.warehouseName,
      createdByName: createdByName ?? this.createdByName,
    );
  }

  @override
  String toString() {
    return 'SaleInvoice{id: $id, invoiceNumber: $invoiceNumber, total: $totalAmount, status: $status}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SaleInvoice &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SaleInvoiceItem {
  final int? id;
  final int saleInvoiceId;
  final int productId;
  final String productName;
  final String? barcode;
  final int quantity;
  final double unitPrice;
  final double costPrice;
  final double totalPrice;
  final double totalCost;
  final double profit;
  final DateTime? createdAt;

  SaleInvoiceItem({
    this.id,
    required this.saleInvoiceId,
    required this.productId,
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.totalPrice,
    required this.totalCost,
    required this.profit,
    this.createdAt,
  });

  factory SaleInvoiceItem.fromMap(Map<String, dynamic> map) {
    final unitPrice = (map['unit_price'] as num?)?.toDouble() ?? 0;
    final costPrice = (map['cost_price'] as num?)?.toDouble() ?? 0;
    final quantity = map['quantity'] as int? ?? 0;
    final totalPrice = unitPrice * quantity;
    final totalCost = costPrice * quantity;
    final profit = totalPrice - totalCost;

    return SaleInvoiceItem(
      id: map['id'] as int?,
      saleInvoiceId: map['sale_invoice_id'] as int? ?? 0,
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? 'غير معروف',
      barcode: map['barcode'] as String?,
      quantity: quantity,
      unitPrice: unitPrice,
      costPrice: costPrice,
      totalPrice: totalPrice,
      totalCost: totalCost,
      profit: profit,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sale_invoice_id': saleInvoiceId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'total_price': totalPrice,
      'total_cost': totalCost,
      'profit': profit,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  // Getters مفيدة
  double get profitMargin {
    return totalPrice > 0 ? (profit / totalPrice) * 100 : 0;
  }

  Color get profitColor {
    return profit >= 0 ? Colors.green : Colors.red;
  }

  String get formattedProfit {
    return profit >= 0
        ? '+${profit.toStringAsFixed(2)}'
        : profit.toStringAsFixed(2);
  }

  SaleInvoiceItem copyWith({
    int? id,
    int? saleInvoiceId,
    int? productId,
    String? productName,
    String? barcode,
    int? quantity,
    double? unitPrice,
    double? costPrice,
    double? totalPrice,
    double? totalCost,
    double? profit,
    DateTime? createdAt,
  }) {
    return SaleInvoiceItem(
      id: id ?? this.id,
      saleInvoiceId: saleInvoiceId ?? this.saleInvoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      totalCost: totalCost ?? this.totalCost,
      profit: profit ?? this.profit,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'SaleInvoiceItem{product: $productName, quantity: $quantity, price: $unitPrice}';
  }
}

// كلاس لنتيجة الفاتورة الكاملة مع بنودها
class SaleInvoiceWithItems {
  final SaleInvoice invoice;
  final List<SaleInvoiceItem> items;

  SaleInvoiceWithItems({
    required this.invoice,
    required this.items,
  });

  // حساب التجميعات
  double get itemsTotal {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get itemsCost {
    return items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  double get itemsProfit {
    return items.fold(0.0, (sum, item) => sum + item.profit);
  }

  int get totalItemsCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  int get uniqueProductsCount {
    return items.map((item) => item.productId).toSet().length;
  }

  // دالة للتحقق من المطابقة
  bool validate() {
    final calculatedTotal = itemsTotal - invoice.discountAmount;
    return (calculatedTotal - invoice.totalAmount).abs() < 0.01;
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'invoice': invoice.toMap(),
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory SaleInvoiceWithItems.fromJson(Map<String, dynamic> json) {
    return SaleInvoiceWithItems(
      invoice: SaleInvoice.fromMap(json['invoice']),
      items: (json['items'] as List)
          .map((item) => SaleInvoiceItem.fromMap(item))
          .toList(),
    );
  }
}

// إضافة import للـ Colors في أعلى الملف
