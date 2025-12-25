class CashLedger {
  final int? id;
  final String transactionType;
  final double amount;
  final double balanceAfter;
  final String? referenceType;
  final int? referenceId;
  final String? description;
  final DateTime transactionDate;
  final DateTime createdAt;
  final String? createdByName;

  CashLedger({
    this.id,
    required this.transactionType,
    required this.amount,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    this.description,
    required this.transactionDate,
    required this.createdAt,
    this.createdByName,
  });

  factory CashLedger.fromMap(Map<String, dynamic> map) {
    return CashLedger(
      id: map['id'],
      transactionType: map['transaction_type'],
      amount: map['amount']?.toDouble() ?? 0,
      balanceAfter: map['balance_after']?.toDouble() ?? 0,
      referenceType: map['reference_type'],
      referenceId: map['reference_id'],
      description: map['description'],
      transactionDate: DateTime.parse(map['transaction_date']),
      createdAt: DateTime.parse(map['created_at']),
      createdByName: map['created_by_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_type': transactionType,
      'amount': amount,
      'balance_after': balanceAfter,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}