import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'color.dart';
import 'database_helper.dart';

class CustomersScreen extends StatefulWidget {
  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      setState(() => _isLoading = true);
      final customers = await _dbHelper.getCustomers();
      setState(() {
        _customers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل العملاء: $e');
      setState(() => _isLoading = false);
      _showSnackBar('❌ خطأ في تحميل العملاء', isError: true);
    }
  }

  void _filterCustomers() {
    if (_searchQuery.isEmpty) {
      setState(() => _filteredCustomers = _customers);
    } else {
      setState(() {
        _filteredCustomers = _customers.where((customer) {
          final name = customer['name']?.toString().toLowerCase() ?? '';
          final phone = customer['phone']?.toString().toLowerCase() ?? '';
          final email = customer['email']?.toString().toLowerCase() ?? '';
          final address = customer['address']?.toString().toLowerCase() ?? '';
          final query = _searchQuery.toLowerCase();

          return name.contains(query) ||
              phone.contains(query) ||
              email.contains(query) ||
              address.contains(query);
        }).toList();
      });
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteCustomer(int customerId, String customerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('تأكيد الحذف'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف العميل "$customerName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _dbHelper.deleteCustomer(customerId);
        if (result > 0) {
          _showSnackBar('✅ تم حذف العميل بنجاح', isError: false);
          _loadCustomers();
        }
      } catch (e) {
        _showSnackBar('❌ خطأ في حذف العميل');
      }
    }
  }

  void _showCustomerDetails(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerDetailsSheet(customer: customer),
    );
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCustomerDialog(
        onCustomerAdded: _loadCustomers,
      ),
    );
  }

  void _showEditCustomerDialog(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => AddCustomerDialog(
        customer: customer,
        onCustomerAdded: _loadCustomers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text('إدارة العملاء'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, size: 24),
            onPressed: _showAddCustomerDialog,
            tooltip: 'إضافة عميل',
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 22),
            onPressed: _loadCustomers,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          _buildSearchBar(),

          // إحصائيات سريعة
          _buildStatsHeader(),

          // قائمة العملاء
          Expanded(
            child: _buildCustomersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.grey[600]),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عميل...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _filterCustomers();
                  },
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _filterCustomers();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalCustomers = _filteredCustomers.length;
    final debitCustomers = _filteredCustomers.where((c) => (c['balance'] ?? 0) > 0).length;
    final creditCustomers = _filteredCustomers.where((c) => (c['balance'] ?? 0) < 0).length;
    final zeroBalanceCustomers = _filteredCustomers.where((c) => (c['balance'] ?? 0) == 0).length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                title: 'إجمالي',
                value: totalCustomers,
                icon: Icons.people,
                color: AppColors.primary,
              ),
              _buildStatItem(
                title: 'مدينين',
                value: debitCustomers,
                icon: Icons.arrow_upward,
                color: Colors.red,
              ),
              _buildStatItem(
                title: 'دائنون',
                value: creditCustomers,
                icon: Icons.arrow_downward,
                color: Colors.green,
              ),
              _buildStatItem(
                title: 'متوازن',
                value: zeroBalanceCustomers,
                icon: Icons.balance,
                color: Colors.blue,
              ),
            ],
          ),
          SizedBox(height: 4),
          Divider(height: 1, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildStatItem({required String title, required int value, required IconData icon, required Color color}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا توجد عملاء' : 'لم يتم العثور على نتائج',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              SizedBox(height: 8),
              Text(
                'إضغط على زر + لإضافة عميل جديد',
                style: TextStyle(color: Colors.grey[500]),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showAddCustomerDialog,
                icon: Icon(Icons.add),
                label: Text('إضافة عميل جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomers,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: _filteredCustomers.length,
        itemBuilder: (context, index) {
          final customer = _filteredCustomers[index];
          return _buildCustomerItem(customer);
        },
      ),
    );
  }

  Widget _buildCustomerItem(Map<String, dynamic> customer) {
    final balance = (customer['balance'] as num?)?.toDouble() ?? 0.0;
    final isDebit = balance > 0; // مدين (إيجابي)
    final isCredit = balance < 0; // دائن (سلبي)

    Color balanceColor = Colors.grey;
    String balanceText = 'رصيد: 0.00 ر.س';
    IconData balanceIcon = Icons.balance;

    if (isDebit) {
      balanceColor = Colors.red;
      balanceText = 'مدين: ${balance.toStringAsFixed(2)} ر.س';
      balanceIcon = Icons.arrow_upward;
    } else if (isCredit) {
      balanceColor = Colors.green;
      balanceText = 'دائن: ${balance.abs().toStringAsFixed(2)} ر.س';
      balanceIcon = Icons.arrow_downward;
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () => _showCustomerDetails(customer),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // الصورة/الأيقونة
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),

              SizedBox(width: 12),

              // المعلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer['name'] ?? 'غير معروف',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: balanceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(balanceIcon, size: 12, color: balanceColor),
                              SizedBox(width: 4),
                              Text(
                                balanceText.split(' ')[0], // فقط "مدين" أو "دائن" أو "رصيد"
                                style: TextStyle(
                                  fontSize: 10,
                                  color: balanceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4),

                    if (customer['phone'] != null)
                      _buildInfoRow(Icons.phone, customer['phone']),

                    if (customer['email'] != null)
                      _buildInfoRow(Icons.email, customer['email']),

                    SizedBox(height: 4),

                    // المبلغ
                    Row(
                      children: [
                        Text(
                          balanceText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: balanceColor,
                          ),
                        ),
                        Spacer(),
                        _buildActionButtons(customer),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey[500]),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> customer) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove_red_eye, size: 18),
          onPressed: () => _showCustomerDetails(customer),
          color: Colors.blue,
          padding: EdgeInsets.all(4),
          constraints: BoxConstraints(),
        ),
        IconButton(
          icon: Icon(Icons.edit, size: 18),
          onPressed: () => _showEditCustomerDialog(customer),
          color: Colors.orange,
          padding: EdgeInsets.all(4),
          constraints: BoxConstraints(),
        ),
        IconButton(
          icon: Icon(Icons.delete, size: 18),
          onPressed: () => _deleteCustomer(customer['id'], customer['name']),
          color: Colors.red,
          padding: EdgeInsets.all(4),
          constraints: BoxConstraints(),
        ),
      ],
    );
  }
}

class CustomerDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> customer;

  const CustomerDetailsSheet({required this.customer});

  @override
  Widget build(BuildContext context) {
    final balance = (customer['balance'] as num?)?.toDouble() ?? 0.0;
    final isDebit = balance > 0;
    final isCredit = balance < 0;

    final creditLimit = (customer['credit_limit'] as num?)?.toDouble() ?? 0.0;
    final availableCredit = creditLimit - (isDebit ? balance : 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // السحب لأسفل
          Container(
            width: 40,
            height: 5,
            margin: EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // العنوان
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.person, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  'تفاصيل العميل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // المعلومة الأساسية
                  _buildDetailSection(
                    icon: Icons.person_outline,
                    title: 'المعلومات الشخصية',
                    children: [
                      _buildDetailItem('الاسم الكامل', customer['name'] ?? 'غير معروف'),
                      if (customer['phone'] != null) _buildDetailItem('رقم الهاتف', customer['phone']),
                      if (customer['email'] != null) _buildDetailItem('البريد الإلكتروني', customer['email']),
                      if (customer['address'] != null) _buildDetailItem('العنوان', customer['address']),
                      if (customer['tax_number'] != null) _buildDetailItem('الرقم الضريبي', customer['tax_number']),
                    ],
                  ),

                  SizedBox(height: 20),

                  // المعلومات المالية
                  _buildDetailSection(
                    icon: Icons.account_balance_wallet,
                    title: 'المعلومات المالية',
                    children: [
                      _buildAmountItem(
                        'الرصيد الحالي',
                        balance,
                        isPositive: isDebit,
                        isNegative: isCredit,
                      ),

                      if (creditLimit > 0) ...[
                        SizedBox(height: 12),
                        _buildAmountItem('حد الائتمان', creditLimit),
                        _buildAmountItem(
                          'الرصيد المتاح',
                          availableCredit,
                          color: availableCredit > 0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: 20),

                  // معلومات النظام
                  _buildDetailSection(
                    icon: Icons.info_outline,
                    title: 'معلومات النظام',
                    children: [
                      if (customer['created_at'] != null)
                        _buildDetailItem('تاريخ الإضافة', _formatDate(customer['created_at'])),
                      if (customer['updated_at'] != null && customer['updated_at'] != customer['created_at'])
                        _buildDetailItem('تاريخ التحديث', _formatDate(customer['updated_at'])),
                    ],
                  ),

                  SizedBox(height: 30),

                  // أزرار الإجراءات
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                          label: Text('إغلاق'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => AddCustomerDialog(
                                customer: customer,
                                onCustomerAdded: () {},
                              ),
                            );
                          },
                          icon: Icon(Icons.edit),
                          label: Text('تعديل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({required IconData icon, required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountItem(String label, double amount, {bool isPositive = false, bool isNegative = false, Color? color}) {
    Color textColor = color ?? Colors.grey[800]!;
    if (isPositive) textColor = Colors.red;
    if (isNegative) textColor = Colors.green;

    String amountText = '${amount.abs().toStringAsFixed(2)} ر.س';
    if (isPositive) amountText = '+ $amountText';
    if (isNegative) amountText = '- $amountText';

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final formatter = Intl.withLocale('ar', () => DateFormat('yyyy/MM/dd - hh:mm a'));
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }
}

class AddCustomerDialog extends StatefulWidget {
  final Map<String, dynamic>? customer;
  final Function onCustomerAdded;

  const AddCustomerDialog({this.customer, required this.onCustomerAdded});

  @override
  _AddCustomerDialogState createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _creditLimitController = TextEditingController(text: '0.0');
  final _balanceController = TextEditingController(text: '0.0');

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.customer != null;
    if (_isEditMode) {
      _fillCustomerData();
    }
  }

  void _fillCustomerData() {
    final customer = widget.customer!;
    _nameController.text = customer['name'] ?? '';
    _phoneController.text = customer['phone']?.toString() ?? '';
    _emailController.text = customer['email']?.toString() ?? '';
    _addressController.text = customer['address']?.toString() ?? '';
    _taxNumberController.text = customer['tax_number']?.toString() ?? '';
    _creditLimitController.text = (customer['credit_limit']?.toString() ?? '0.0');
    _balanceController.text = (customer['balance']?.toString() ?? '0.0');
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final customerData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'tax_number': _taxNumberController.text.trim().isEmpty ? null : _taxNumberController.text.trim(),
        'credit_limit': double.tryParse(_creditLimitController.text.replaceAll(',', '.')) ?? 0.0,
        'balance': double.tryParse(_balanceController.text.replaceAll(',', '.')) ?? 0.0,
      };

      int result;
      if (_isEditMode) {
        result = await _dbHelper.updateCustomer(widget.customer!['id'], customerData);
      } else {
        result = await _dbHelper.insertCustomer(customerData);
      }

      if (result > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text(_isEditMode ? '✅ تم تحديث العميل بنجاح' : '✅ تم إضافة العميل بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCustomerAdded();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text(_isEditMode ? '❌ فشل في تحديث العميل' : '❌ فشل في إضافة العميل'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('خطأ في حفظ العميل: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('❌ حدث خطأ: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان
                Row(
                  children: [
                    Icon(
                      _isEditMode ? Icons.edit : Icons.add_circle,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isEditMode ? 'تعديل العميل' : 'إضافة عميل جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // الاسم
                TextFormField(
                  controller: _nameController,
                  validator: (value) => value!.trim().isEmpty ? 'يرجى إدخال اسم العميل' : null,
                  decoration: InputDecoration(
                    labelText: 'اسم العميل *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),

                SizedBox(height: 16),

                // الهاتف والبريد
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    ),

                    SizedBox(width: 16),

                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // العنوان
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    alignLabelWithHint: true,
                  ),
                ),

                SizedBox(height: 16),

                // الرقم الضريبي
                TextFormField(
                  controller: _taxNumberController,
                  decoration: InputDecoration(
                    labelText: 'الرقم الضريبي (اختياري)',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),

                SizedBox(height: 16),

                // المعلومات المالية
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المعلومات المالية',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),

                        SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _creditLimitController,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'حد الائتمان',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  hintText: '0.0',
                                ),
                              ),
                            ),

                            SizedBox(width: 16),

                            Expanded(
                              child: TextFormField(
                                controller: _balanceController,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'الرصيد الحالي',
                                  prefixIcon: Icon(Icons.account_balance_wallet),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  hintText: '0.0',
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        Text(
                          'ملاحظة: الرصيد الإيجابي يعني العميل مدين، والرصيد السلبي يعني العميل دائن',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // أزرار الحفظ والإلغاء
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, size: 18),
                            SizedBox(width: 8),
                            Text('إلغاء'),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: 16),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isEditMode ? Icons.save : Icons.add, size: 18),
                            SizedBox(width: 8),
                            Text(_isEditMode ? 'تحديث' : 'إضافة'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _creditLimitController.dispose();
    _balanceController.dispose();
    super.dispose();
  }
}