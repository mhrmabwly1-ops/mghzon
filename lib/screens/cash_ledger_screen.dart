import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../model/cash_ledger.dart';

class CashLedgerScreen extends StatefulWidget {
  @override
  _CashLedgerScreenState createState() => _CashLedgerScreenState();
}

class _CashLedgerScreenState extends State<CashLedgerScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<CashLedger> _transactions = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  double _currentBalance = 0;
  double _totalIncome = 0;
  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final transactionsData = await _dbHelper.getCashLedger(
        startDate: _startDate,
        endDate: _endDate,
      );
      final balance = await _dbHelper.getCurrentCashBalance();

      // حساب الإحصائيات
      double income = 0;
      double expenses = 0;

      for (final transaction in transactionsData) {
        if (transaction['transaction_type'] == 'receipt' ||
            transaction['transaction_type'] == 'opening_balance') {
          income += transaction['amount'] as double;
        } else if (transaction['transaction_type'] == 'payment') {
          expenses += transaction['amount'] as double;
        }
      }

      setState(() {
        _transactions = transactionsData.map((e) => CashLedger.fromMap(e)).toList();
        _currentBalance = balance;
        _totalIncome = income;
        _totalExpenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل سجل الصندوق: $e');
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _addOpeningBalance() async {
    final amountController = TextEditingController();
    final dateController = TextEditingController(text: _formatDate(DateTime.now()));

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة رصيد افتتاحي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  dateController.text = _formatDate(picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'التاريخ',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateController.text),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                _showError('يرجى إدخال مبلغ صحيح');
                return;
              }

              final result = await _dbHelper.addOpeningBalance(amount, DateTime.now());
              if (result['success']) {
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _showError(result['error']);
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل الصندوق'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: Icon(Icons.account_balance_wallet),
            onPressed: _addOpeningBalance,
          ),
        ],
      ),
      body: Column(
        children: [
          // إحصائيات الصندوق
          _buildBalanceStats(),
          // فلترة التاريخ
          _buildDateFilterCard(),
          // قائمة المعاملات
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد معاملات في الصندوق',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                itemCount: _transactions.length,
                padding: EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return CashTransactionCard(transaction: transaction);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStats() {
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'الرصيد الحالي',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              '$_currentBalance ريال',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _currentBalance >= 0 ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'إجمالي الإيرادات',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      '$_totalIncome ريال',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'إجمالي المصروفات',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      '$_totalExpenses ريال',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الفترة:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
              style: TextStyle(color: Colors.blue),
            ),
            Chip(
              label: Text('${_transactions.length} معاملة'),
              backgroundColor: Colors.purple.withOpacity(0.1),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class CashTransactionCard extends StatelessWidget {
  final CashLedger transaction;

  const CashTransactionCard({
    Key? key,
    required this.transaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.transactionType == 'receipt' ||
        transaction.transactionType == 'opening_balance';

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green : Colors.red,
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white,
          ),
        ),
        title: Text(
          _getTransactionTypeText(transaction.transactionType),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.description != null) Text(transaction.description!),
            Text('التاريخ: ${_formatDate(transaction.transactionDate)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${transaction.amount} ريال',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            Text(
              'الرصيد: ${transaction.balanceAfter} ريال',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _getTransactionTypeText(String type) {
    switch (type) {
      case 'receipt': return 'سند قبض';
      case 'payment': return 'سند صرف';
      case 'opening_balance': return 'رصيد افتتاحي';
      default: return type;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}