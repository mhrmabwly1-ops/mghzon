class ReceiptVoucher {
  final int? id;
  final String voucherNumber;
  final int? customerId;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;
  final String? notes;
  final String? referenceType;
  final int? referenceId;
  final DateTime createdAt;
  final String? customerName;
  final String? createdByName;

  ReceiptVoucher({
    this.id,
    required this.voucherNumber,
    this.customerId,
    required this.amount,
    this.paymentMethod = 'cash',
    required this.paymentDate,
    this.notes,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
    this.customerName,
    this.createdByName,
  });

  factory ReceiptVoucher.fromMap(Map<String, dynamic> map) {
    return ReceiptVoucher(
      id: map['id'],
      voucherNumber: map['voucher_number'],
      customerId: map['customer_id'],
      amount: map['amount']?.toDouble() ?? 0,
      paymentMethod: map['payment_method'] ?? 'cash',
      paymentDate: DateTime.parse(map['payment_date']),
      notes: map['notes'],
      referenceType: map['reference_type'],
      referenceId: map['reference_id'],
      createdAt: DateTime.parse(map['created_at']),
      customerName: map['customer_name'],
      createdByName: map['created_by_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'voucher_number': voucherNumber,
      'customer_id': customerId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_date': paymentDate.toIso8601String(),
      'notes': notes,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}