import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // تمت الإضافة
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// استيراد فئة قاعدة البيانات
import 'database_helper.dart';
import 'settings_store.dart';
// استيراد الألوان
import 'app_colors.dart';
import 'invoice_numbering_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SettingsStore _store = SettingsStore();
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _advancedSettings = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _confirmDeleteController = TextEditingController();
  bool _deleteConfirmed = false;

  @override
  void initState() {
    super.initState();
    // initialize local view of settings from central store
    _store.addListener(_onStoreChanged);
    if (!_store.initialized) {
      _store.load();
    }
    _loadAllSettings();
  }

  void _onStoreChanged() {
    setState(() {
      _settings = _store.settings;
      _advancedSettings = _store.advancedSettings;
      _isLoading = false;
    });
  }

  // دالة لتحميل جميع الإعدادات من قاعدة البيانات (محدثة)
  Future<void> _loadAllSettings() async {
    setState(() => _isLoading = true);
    try {
      // تحميل الإعدادات العامة من قاعدة البيانات
      final companySetting = await _dbHelper.getSetting('company_name');
      if (companySetting.isNotEmpty) {
        _settings['company_name'] = companySetting['setting_value'];
      } else {
        _settings['company_name'] = 'شركة إدارة المخزون'; // قيمة افتراضية
      }

      final currencySetting = await _dbHelper.getSetting('default_currency');
      if (currencySetting.isNotEmpty) {
        _settings['default_currency'] = currencySetting['setting_value'];
      } else {
        _settings['default_currency'] = 'ريال'; // قيمة افتراضية
      }

      final taxSetting = await _dbHelper.getSetting('default_tax_rate');
      if (taxSetting.isNotEmpty) {
        _settings['default_tax_rate'] = double.tryParse(taxSetting['setting_value']) ?? 15.0;
      } else {
        _settings['default_tax_rate'] = 15.0; // قيمة افتراضية
      }

      final notificationsSetting = await _dbHelper.getSetting('enable_notifications');
      if (notificationsSetting.isNotEmpty) {
        _settings['enable_notifications'] = notificationsSetting['setting_value'] == '1';
      } else {
        _settings['enable_notifications'] = true; // قيمة افتراضية
      }

      // تحميل الإعدادات المتقدمة من قاعدة البيانات
      final languageSetting = await _dbHelper.getAdvancedSetting('app_language');
      if (languageSetting.isNotEmpty) {
        _advancedSettings['app_language'] = languageSetting['setting_value'];
      } else {
        _advancedSettings['app_language'] = 'العربية'; // قيمة افتراضية
      }

      final themeSetting = await _dbHelper.getAdvancedSetting('app_theme');
      if (themeSetting.isNotEmpty) {
        _advancedSettings['app_theme'] = themeSetting['setting_value'];
      } else {
        _advancedSettings['app_theme'] = 'فاتح'; // قيمة افتراضية
      }

      final trackSerialSetting = await _dbHelper.getAdvancedSetting('track_serial_numbers');
      if (trackSerialSetting.isNotEmpty) {
        _advancedSettings['track_serial_numbers'] = trackSerialSetting['setting_value'] == '1';
      } else {
        _advancedSettings['track_serial_numbers'] = false; // قيمة افتراضية
      }

      final trackExpirySetting = await _dbHelper.getAdvancedSetting('track_expiry_dates');
      if (trackExpirySetting.isNotEmpty) {
        _advancedSettings['track_expiry_dates'] = trackExpirySetting['setting_value'] == '1';
      } else {
        _advancedSettings['track_expiry_dates'] = false; // قيمة افتراضية
      }

      final autoPrintSetting = await _dbHelper.getAdvancedSetting('auto_print_invoice');
      if (autoPrintSetting.isNotEmpty) {
        _advancedSettings['auto_print_invoice'] = autoPrintSetting['setting_value'] == '1';
      } else {
        _advancedSettings['auto_print_invoice'] = false; // قيمة افتراضية
      }

      final autoPurchaseSetting = await _dbHelper.getAdvancedSetting('auto_purchase_orders');
      if (autoPurchaseSetting.isNotEmpty) {
        _advancedSettings['auto_purchase_orders'] = autoPurchaseSetting['setting_value'] == '1';
      } else {
        _advancedSettings['auto_purchase_orders'] = false; // قيمة افتراضية
      }

      final emailReportsSetting = await _dbHelper.getAdvancedSetting('email_reports');
      if (emailReportsSetting.isNotEmpty) {
        _advancedSettings['email_reports'] = emailReportsSetting['setting_value'] == '1';
      } else {
        _advancedSettings['email_reports'] = false; // قيمة افتراضية
      }

      final twoFactorSetting = await _dbHelper.getAdvancedSetting('two_factor_auth');
      if (twoFactorSetting.isNotEmpty) {
        _advancedSettings['two_factor_auth'] = twoFactorSetting['setting_value'] == '1';
      } else {
        _advancedSettings['two_factor_auth'] = false; // قيمة افتراضية
      }

      final ipRestrictionSetting = await _dbHelper.getAdvancedSetting('ip_restriction');
      if (ipRestrictionSetting.isNotEmpty) {
        _advancedSettings['ip_restriction'] = ipRestrictionSetting['setting_value'] == '1';
      } else {
        _advancedSettings['ip_restriction'] = false; // قيمة افتراضية
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الإعدادات: ${e.toString()}')),
      );
    }
  }

  // دالة لتحديث إعداد معين وحفظه في قاعدة البيانات (محدثة)
  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _dbHelper.updateSetting(key, value);
      setState(() {
        _settings[key] = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم حفظ الإعداد بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في حفظ الإعداد: ${e.toString()}')),
      );
    }
  }

  // دالة لتحديث إعداد متقدم (محدثة)
  Future<void> _updateAdvancedSetting(String key, dynamic value) async {
    try {
      await _dbHelper.updateAdvancedSetting(key, value);
      setState(() {
        _advancedSettings[key] = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تحديث الإعداد المتقدم')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تحديث الإعداد: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _searchController.dispose();
    _confirmDeleteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الإعدادات المتقدمة'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllSettings,
            tooltip: 'تحديث الإعدادات',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط البحث
            _buildSearchBar(),
            SizedBox(height: 20),

            // 1. الإعدادات العامة
            _buildSectionHeader('الإعدادات العامة', Icons.settings),
            _buildGeneralSettings(),
            SizedBox(height: 20),

            // 2. المنتجات والمخزون
            _buildSectionHeader('المنتجات والمخزون', Icons.inventory),
            _buildProductInventorySettings(),
            SizedBox(height: 20),

            // 3. المبيعات والفواتير
            _buildSectionHeader('المبيعات والفواتير', Icons.receipt),
            _buildSalesInvoiceSettings(),
            SizedBox(height: 20),

            // 4. المشتريات والموردين
            _buildSectionHeader('المشتريات والموردين', Icons.shopping_cart),
            _buildPurchaseSupplierSettings(),
            SizedBox(height: 20),

            // 5. التقارير والتحليلات
            _buildSectionHeader('التقارير والتحليلات', Icons.analytics),
            _buildReportsAnalyticsSettings(),
            SizedBox(height: 20),

            // 6. الأمان والمستخدمون
            _buildSectionHeader('الأمان والمستخدمون', Icons.security),
            _buildSecurityUserSettings(),
            SizedBox(height: 20),

            // 7. التخصيص والمظهر
            _buildSectionHeader('التخصيص والمظهر', Icons.palette),
            _buildCustomizationSettings(),
            SizedBox(height: 20),

            // 8. الصيانة والإدارة
            _buildSectionHeader('الصيانة والإدارة', Icons.build),
            _buildMaintenanceSettings(),
            SizedBox(height: 20),

            // 9. النسخ الاحتياطي والاستعادة
            _buildSectionHeader('النسخ الاحتياطي والاستعادة', Icons.backup),
            _buildBackupRestoreSection(),
            SizedBox(height: 20),

            // 10. حذف قاعدة البيانات (خطر)
            _buildSectionHeader('خيارات خطيرة', Icons.dangerous),
            _buildDangerZone(),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- ويدجت البحث والعناوين ---
  Widget _buildSearchBar() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث في الإعدادات...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  // يمكن إضافة منطق البحث هنا
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // --- دوال بناء أقسام الإعدادات ---

  Widget _buildGeneralSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'اسم الشركة',
              value: _settings['company_name'] ?? 'شركة إدارة المخزون',
              icon: Icons.business,
              onTap: _showEditCompanyDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'العملة الافتراضية',
              value: _settings['default_currency'] ?? 'ريال',
              icon: Icons.monetization_on,
              onTap: _showEditCurrencyDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'الضرائب الافتراضية',
              value: '${_settings['default_tax_rate'] ?? 15.0}%',
              icon: Icons.percent,
              onTap: _showEditTaxDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('التنبيهات والإشعارات'),
              subtitle: Text('عرض تنبيهات المخزون المنخفض'),
              secondary: Icon(Icons.notifications_active, color: AppColors.primary),
              value: _settings['enable_notifications'] ?? true,
              onChanged: (value) => _updateSetting('enable_notifications', value ? '1' : '0'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInventorySettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'وحدات القياس',
              value: 'إدارة وحدات القياس',
              icon: Icons.straighten,
              onTap: _showUnitsDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'إعدادات الباركود',
              value: 'تكوين الباركود والماسح الضوئي',
              icon: Icons.qr_code_scanner,
              onTap: _showBarcodeSettings,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('تتبع الأرقام التسلسلية'),
              subtitle: Text('تفعيل تتبع الأرقام التسلسلية للمنتجات'),
              secondary: Icon(Icons.confirmation_number, color: AppColors.primary),
              value: _advancedSettings['track_serial_numbers'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('track_serial_numbers', value ? '1' : '0'),
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('تتبع تاريخ انتهاء الصلاحية'),
              subtitle: Text('تفعيل تتبع تواريخ انتهاء الصلاحية'),
              secondary: Icon(Icons.calendar_today, color: AppColors.primary),
              value: _advancedSettings['track_expiry_dates'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('track_expiry_dates', value ? '1' : '0'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesInvoiceSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'ترقيم الفواتير',
              value: 'تكوين نمط ترقيم الفواتير',
              icon: Icons.format_list_numbered,
              onTap: _showInvoiceNumberingDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'شروط الدفع',
              value: 'إدارة شروط الدفع للعملاء',
              icon: Icons.payment,
              onTap: _showPaymentTermsDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'سياسات الإرجاع',
              value: 'تحديد شروط ومدة الإرجاع',
              icon: Icons.assignment_return,
              onTap: _showReturnPoliciesDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('طباعة تلقائية'),
              subtitle: Text('طباعة الفاتورة تلقائياً بعد إنشائها'),
              secondary: Icon(Icons.print, color: AppColors.primary),
              value: _advancedSettings['auto_print_invoice'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('auto_print_invoice', value ? '1' : '0'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseSupplierSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'شروط الدفع للموردين',
              value: 'إدارة شروط الدفع',
              icon: Icons.account_balance,
              onTap: _showSupplierPaymentTermsDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('طلب الشراء التلقائي'),
              subtitle: Text('إنشاء طلبات شراء عند وصول المخزون للحد الأدنى'),
              secondary: Icon(Icons.shopping_basket, color: AppColors.primary),
              value: _advancedSettings['auto_purchase_orders'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('auto_purchase_orders', value ? '1' : '0'),
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'تقييم الموردين',
              value: 'معايير تقييم أداء الموردين',
              icon: Icons.star_rate,
              onTap: _showSupplierEvaluationSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsAnalyticsSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'التقارير المجدولة',
              value: 'جدولة إرسال التقارير',
              icon: Icons.schedule_send,
              onTap: _showScheduledReportsDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('إرسال التقارير عبر البريد'),
              subtitle: Text('تفعيل إرسال التقارير عبر البريد الإلكتروني'),
              secondary: Icon(Icons.email, color: AppColors.primary),
              value: _advancedSettings['email_reports'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('email_reports', value ? '1' : '0'),
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'صيغ التصدير',
              value: 'اختيار صيغ التصدير الافتراضية',
              icon: Icons.file_download,
              onTap: _showExportFormatsDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityUserSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'إدارة المستخدمين',
              value: 'إضافة، تعديل، وحذف المستخدمين',
              icon: Icons.people,
              onTap: _showUsersManagement,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'سياسات كلمات المرور',
              value: 'تكوين متطلبات كلمات المرور',
              icon: Icons.lock,
              onTap: _showPasswordPolicyDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('المصادقة الثنائية'),
              subtitle: Text('تفعيل المصادقة الثنائية للمستخدمين'),
              secondary: Icon(Icons.verified_user, color: AppColors.primary),
              value: _advancedSettings['two_factor_auth'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('two_factor_auth', value ? '1' : '0'),
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('تقييد عنوان IP'),
              subtitle: Text('تقييد الوصول بعناوين IP محددة'),
              secondary: Icon(Icons.network_check, color: AppColors.primary),
              value: _advancedSettings['ip_restriction'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('ip_restriction', value ? '1' : '0'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'لغة التطبيق',
              value: _advancedSettings['app_language'] ?? 'العربية',
              icon: Icons.language,
              onTap: _showLanguageDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'مظهر الواجهة',
              value: _advancedSettings['app_theme'] ?? 'فاتح',
              icon: Icons.palette,
              onTap: _showThemeDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'تنسيق التاريخ',
              value: 'تحديد تنسيق التاريخ والوقت',
              icon: Icons.date_range,
              onTap: _showDateTimeFormatDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'تنسيق العملة',
              value: 'تحديد تنسيق الأرقام والعملة',
              icon: Icons.attach_money,
              onTap: _showNumberFormatDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'فحص سلامة قاعدة البيانات',
              value: 'فحص الأخطاء والمشاكل',
              icon: Icons.health_and_safety,
              onTap: _checkDatabaseIntegrity,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'ضغط قاعدة البيانات',
              value: 'تحسين الأداء وتقليل المساحة',
              icon: Icons.compress,
              onTap: _compressDatabase,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'إعادة بناء الفهارس',
              value: 'تحسين سرعة البحث والاستعلامات',
              icon: Icons.build,
              onTap: _rebuildIndexes,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'إحصائيات قاعدة البيانات',
              value: 'عرض معلومات وحجم البيانات',
              icon: Icons.storage,
              onTap: _showDatabaseStats,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupRestoreSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.backup, size: 24),
              label: Text('إنشاء نسخة احتياطية الآن', style: TextStyle(fontSize: 16)),
              onPressed: _createBackupNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.restore, size: 24),
              label: Text('استعادة من نسخة احتياطية', style: TextStyle(fontSize: 16)),
              onPressed: _restoreBackup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.download, size: 24),
              label: Text('تصدير البيانات إلى JSON', style: TextStyle(fontSize: 16)),
              onPressed: _exportDatabaseToJson,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.red, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '⚠️ تحذير: هذه الإجراءات لا يمكن التراجع عنها!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 15),

            // مسح جميع البيانات
            ElevatedButton.icon(
              icon: Icon(Icons.delete_sweep, size: 24),
              label: Text('مسح جميع البيانات', style: TextStyle(fontSize: 16)),
              onPressed: _showClearDataConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),

            // إعادة تعيين قاعدة البيانات
            ElevatedButton.icon(
              icon: Icon(Icons.restart_alt, size: 24),
              label: Text('إعادة تعيين قاعدة البيانات', style: TextStyle(fontSize: 16)),
              onPressed: _showResetDatabaseConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),

            // حذف قاعدة البيانات بالكامل
            ElevatedButton.icon(
              icon: Icon(Icons.delete_forever, size: 24),
              label: Text('حذف قاعدة البيانات بالكامل', style: TextStyle(fontSize: 16)),
              onPressed: _showDeleteDatabaseConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // --- دوال النوافذ المنبثقة (Dialogs) الحقيقية ---

  void _showEditCompanyDialog() {
    final TextEditingController _controller = TextEditingController(
        text: _settings['company_name'] ?? 'شركة إدارة المخزون'
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل اسم الشركة'),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'اسم الشركة',
            border: OutlineInputBorder(),
            hintText: 'أدخل اسم الشركة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                _updateSetting('company_name', _controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditCurrencyDialog() {
    final List<String> currencies = ['ريال', 'درهم', 'دينار', 'دولار', 'يورو', 'جنيه'];
    String selectedCurrency = _settings['default_currency'] ?? 'ريال';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختر العملة الافتراضية'),
            content: Container(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  return RadioListTile<String>(
                    title: Text(currency),
                    value: currency,
                    groupValue: selectedCurrency,
                    onChanged: (value) {
                      setState(() {
                        selectedCurrency = value!;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateSetting('default_currency', selectedCurrency);
                  Navigator.pop(context);
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTaxDialog() {
    final TextEditingController _controller = TextEditingController(
        text: (_settings['default_tax_rate'] ?? 15.0).toString()
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل نسبة الضريبة الافتراضية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'نسبة الضريبة (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            SizedBox(height: 10),
            Text(
              'القيمة الحالية: ${_settings['default_tax_rate'] ?? 15.0}%',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final taxRate = double.tryParse(_controller.text) ?? 0.0;
              if (taxRate >= 0 && taxRate <= 100) {
                _updateSetting('default_tax_rate', taxRate.toString());
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('يجب أن تكون نسبة الضريبة بين 0 و 100')),
                );
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showUnitsDialog() async {
    try {
      final units = await _dbHelper.getUnits();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.straighten, color: AppColors.primary),
              SizedBox(width: 10),
              Text('إدارة وحدات القياس'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: units.isEmpty
                      ? Center(
                    child: Text(
                      'لا توجد وحدات قياس',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, index) {
                      final unit = units[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(unit['name']),
                          subtitle: Text(
                            unit['abbreviation'] ?? '',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showEditUnitDialog(unit);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteUnitConfirmation(unit);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10),
                Divider(),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('إضافة وحدة جديدة'),
                  onPressed: _showAddUnitDialog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل وحدات القياس: ${e.toString()}')),
      );
    }
  }

  void _showAddUnitDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController abbreviationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة وحدة قياس جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'اسم الوحدة',
                border: OutlineInputBorder(),
                hintText: 'مثال: كيلوجرام',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: abbreviationController,
              decoration: InputDecoration(
                labelText: 'الاختصار (اختياري)',
                border: OutlineInputBorder(),
                hintText: 'مثال: كج',
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
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.insertUnit({
                    'name': nameController.text.trim(),
                    'abbreviation': abbreviationController.text.trim().isNotEmpty
                        ? abbreviationController.text.trim()
                        : null,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم إضافة الوحدة بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة الوحدات
                  _showUnitsDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في إضافة الوحدة: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditUnitDialog(Map<String, dynamic> unit) {
    final TextEditingController nameController = TextEditingController(text: unit['name']);
    final TextEditingController abbreviationController = TextEditingController(
        text: unit['abbreviation'] ?? ''
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل وحدة القياس'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'اسم الوحدة',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: abbreviationController,
              decoration: InputDecoration(
                labelText: 'الاختصار',
                border: OutlineInputBorder(),
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
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.updateUnit(unit['id'], {
                    'name': nameController.text.trim(),
                    'abbreviation': abbreviationController.text.trim(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم تحديث الوحدة بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة الوحدات
                  _showUnitsDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في تحديث الوحدة: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUnitConfirmation(Map<String, dynamic> unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف وحدة "${unit['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteUnit(unit['id']);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ تم حذف الوحدة بنجاح')),
                );

                Navigator.pop(context);
                // إعادة تحميل قائمة الوحدات
                _showUnitsDialog();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ خطأ في حذف الوحدة: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showBarcodeSettings() async {
    try {
      final settings = await _dbHelper.getBarcodeSettings();

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('إعدادات الباركود'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // نوع الباركود
                      DropdownButtonFormField<String>(
                        value: settings['barcode_type'] ?? 'CODE128',
                        decoration: InputDecoration(
                          labelText: 'نوع الباركود',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: 'CODE128', child: Text('CODE128')),
                          DropdownMenuItem(value: 'CODE39', child: Text('CODE39')),
                          DropdownMenuItem(value: 'EAN13', child: Text('EAN13')),
                          DropdownMenuItem(value: 'EAN8', child: Text('EAN8')),
                          DropdownMenuItem(value: 'UPC-A', child: Text('UPC-A')),
                          DropdownMenuItem(value: 'QR', child: Text('QR كود')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            settings['barcode_type'] = value;
                          });
                        },
                      ),
                      SizedBox(height: 15),

                      // أبعاد الباركود
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: (settings['width'] ?? 2).toString(),
                              decoration: InputDecoration(
                                labelText: 'العرض',
                                border: OutlineInputBorder(),
                                suffixText: 'مم',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['width'] = int.tryParse(value) ?? 2;
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: (settings['height'] ?? 100).toString(),
                              decoration: InputDecoration(
                                labelText: 'الطول',
                                border: OutlineInputBorder(),
                                suffixText: 'مم',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['height'] = int.tryParse(value) ?? 100;
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),

                      // خيارات إضافية
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text('إظهار السعر'),
                                subtitle: Text('عرض سعر المنتج أسفل الباركود'),
                                value: (settings['include_price'] ?? 0) == 1,
                                onChanged: (value) {
                                  setState(() {
                                    settings['include_price'] = value ? 1 : 0;
                                  });
                                },
                              ),
                              Divider(),
                              SwitchListTile(
                                title: Text('إظهار الاسم'),
                                subtitle: Text('عرض اسم المنتج أسفل الباركود'),
                                value: (settings['include_name'] ?? 1) == 1,
                                onChanged: (value) {
                                  setState(() {
                                    settings['include_name'] = value ? 1 : 0;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _dbHelper.updateBarcodeSettings(settings);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ تم حفظ إعدادات الباركود')),
                      );

                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ خطأ في الحفظ: ${e.toString()}')),
                      );
                    }
                  },
                  child: Text('حفظ الإعدادات'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل إعدادات الباركود: ${e.toString()}')),
      );
    }
  }

  void _showLanguageDialog() {
    final List<String> languages = ['العربية', 'English', 'Français', 'Español'];
    String selectedLang = _advancedSettings['app_language'] ?? 'العربية';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختر لغة التطبيق'),
            content: Container(
              width: double.maxFinite,
              height: 250,
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  return RadioListTile<String>(
                    title: Text(lang),
                    value: lang,
                    groupValue: selectedLang,
                    onChanged: (value) {
                      setState(() {
                        selectedLang = value!;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateAdvancedSetting('app_language', selectedLang);
                  Navigator.pop(context);
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showThemeDialog() {
    final List<String> themes = ['فاتح', 'داكن', 'تلقائي بالنظام'];
    String selectedTheme = _advancedSettings['app_theme'] ?? 'فاتح';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختر مظهر الواجهة'),
            content: Container(
              width: double.maxFinite,
              height: 200,
              child: ListView.builder(
                itemCount: themes.length,
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  return RadioListTile<String>(
                    title: Text(theme),
                    value: theme,
                    groupValue: selectedTheme,
                    onChanged: (value) {
                      setState(() {
                        selectedTheme = value!;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateAdvancedSetting('app_theme', selectedTheme);
                  Navigator.pop(context);
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  // دوال النوافذ المنبثقة للترقيم وشروط الدفع وسياسات الإرجاع
  void _showInvoiceNumberingDialog() async {
    try {
      final numberingSettings = await _dbHelper.getInvoiceNumbering();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.format_list_numbered, color: AppColors.primary),
              SizedBox(width: 10),
              Text('إعدادات ترقيم الفواتير'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: numberingSettings.length,
              itemBuilder: (context, index) {
                final setting = numberingSettings[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(_getInvoiceTypeDisplayName(setting['invoice_type'])),
                    subtitle: Text('الرقم الحالي: ${setting['current_number']}'),
                    trailing: Icon(Icons.edit, color: Colors.blue),
                    onTap: () {
                      _showEditInvoiceNumberingDialog(setting);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل إعدادات الترقيم: ${e.toString()}')),
      );
    }
  }

  void _showPaymentTermsDialog() async {
    try {
      final paymentTerms = await _dbHelper.getPaymentTerms();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payment, color: AppColors.primary),
              SizedBox(width: 10),
              Text('شروط الدفع'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: paymentTerms.isEmpty
                      ? Center(
                    child: Text(
                      'لا توجد شروط دفع',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: paymentTerms.length,
                    itemBuilder: (context, index) {
                      final term = paymentTerms[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(term['name']),
                          subtitle: Text('فترة السداد: ${term['due_days']} يوم'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showEditPaymentTermDialog(term);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeletePaymentTermConfirmation(term);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10),
                Divider(),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('إضافة شرط دفع جديد'),
                  onPressed: _showAddPaymentTermDialog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل شروط الدفع: ${e.toString()}')),
      );
    }
  }

  void _showReturnPoliciesDialog() async {
    try {
      final returnPolicies = await _dbHelper.getReturnPolicies();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment_return, color: AppColors.primary),
              SizedBox(width: 10),
              Text('سياسات الإرجاع'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: returnPolicies.isEmpty
                      ? Center(
                    child: Text(
                      'لا توجد سياسات إرجاع',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: returnPolicies.length,
                    itemBuilder: (context, index) {
                      final policy = returnPolicies[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(policy['name']),
                          subtitle: Text('فترة الإرجاع: ${policy['return_days']} يوم'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showEditReturnPolicyDialog(policy);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteReturnPolicyConfirmation(policy);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10),
                Divider(),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('إضافة سياسة إرجاع جديدة'),
                  onPressed: _showAddReturnPolicyDialog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل سياسات الإرجاع: ${e.toString()}')),
      );
    }
  }

  void _showUsersManagement() async {
    try {
      final users = await _dbHelper.getUsers();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.people, color: AppColors.primary),
              SizedBox(width: 10),
              Text('إدارة المستخدمين'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: users.isEmpty
                      ? Center(
                    child: Text(
                      'لا يوجد مستخدمون',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(user['name']),
                          subtitle: Text('${user['username']} - ${_getRoleDisplayName(user['role'])}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showEditUserDialog(user);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteUserConfirmation(user);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10),
                Divider(),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('إضافة مستخدم جديد'),
                  onPressed: _showAddUserDialog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المستخدمين: ${e.toString()}')),
      );
    }
  }

  // دوال النسخ الاحتياطي
  Future<void> _createBackupNow() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري إنشاء نسخة احتياطية...')),
      );

      final backupPath = await _dbHelper.createBackup();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('✅ تم إنشاء النسخة الاحتياطية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم حفظ النسخة الاحتياطية بنجاح في:'),
              SizedBox(height: 10),
              SelectableText(
                backupPath,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 20),
              Text('تاريخ النسخ: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.share),
              label: Text('مشاركة'),
              onPressed: () async {
                final file = File(backupPath);
                if (await file.exists()) {
                  await Share.shareXFiles([XFile(backupPath)], text: 'نسخة احتياطية من قاعدة البيانات');
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في إنشاء النسخة الاحتياطية: ${e.toString()}')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    // في تطبيق حقيقي، يمكن استخدام file_picker لاختيار ملف
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('استعادة نسخة احتياطية'),
        content: Text('هذه الميزة تتطلب إضافة حزمة file_picker. سيتم تنفيذها في نسخة لاحقة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDatabaseToJson() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري تصدير البيانات...')),
      );

      final exportPath = await _dbHelper.exportDatabaseToJson();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('✅ تم تصدير البيانات بنجاح'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم حفظ ملف التصدير في:'),
              SizedBox(height: 10),
              SelectableText(
                exportPath,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 20),
              Text('يمكنك مشاركة هذا الملف أو حفظه كنسخة احتياطية.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.share),
              label: Text('مشاركة'),
              onPressed: () async {
                final file = File(exportPath);
                if (await file.exists()) {
                  await Share.shareXFiles([XFile(exportPath)], text: 'تصدير بيانات من قاعدة البيانات');
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تصدير البيانات: ${e.toString()}')),
      );
    }
  }

  // تعديل دوال الصيانة والإدارة
  Future<void> _checkDatabaseIntegrity() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري فحص سلامة قاعدة البيانات...')),
      );

      await _dbHelper.checkDatabaseIntegrity();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم فحص قاعدة البيانات بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في فحص قاعدة البيانات: ${e.toString()}')),
      );
    }
  }

  Future<void> _compressDatabase() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري ضغط قاعدة البيانات...')),
      );

      await _dbHelper.compressDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم ضغط قاعدة البيانات بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في ضغط قاعدة البيانات: ${e.toString()}')),
      );
    }
  }

  Future<void> _rebuildIndexes() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري إعادة بناء الفهارس...')),
      );

      await _dbHelper.rebuildIndexes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم إعادة بناء الفهارس بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في إعادة بناء الفهارس: ${e.toString()}')),
      );
    }
  }

  Future<void> _showDatabaseStats() async {
    try {
      final stats = await _dbHelper.getDatabaseStats();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.storage, color: AppColors.primary),
              SizedBox(width: 10),
              Text('إحصائيات قاعدة البيانات'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إجمالي الجداول: ${stats['total_tables']}'),
              SizedBox(height: 10),
              Text('إجمالي السجلات: ${stats['total_records']}'),
              SizedBox(height: 10),
              Text('حجم قاعدة البيانات: ${(stats['database_size'] / (1024 * 1024)).toStringAsFixed(2)} ميجابايت'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في جلب إحصائيات قاعدة البيانات: ${e.toString()}')),
      );
    }
  }

  // تعديل دوال الحذف الخطرة
  void _showClearDataConfirmation() {
    _confirmDeleteController.clear();
    _deleteConfirmed = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('تأكيد مسح جميع البيانات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ تحذير: هذا الإجراء سيحذف جميع البيانات من قاعدة البيانات ما عدا الإعدادات الأساسية والمستخدمين.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'للتأكيد، يرجى كتابة "مسح البيانات" في الحقل أدناه:',
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _confirmDeleteController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'اكتب "مسح البيانات" للتأكيد',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _deleteConfirmed = value.trim() == 'مسح البيانات';
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: _deleteConfirmed ? () async {
                  try {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('جاري مسح البيانات...')),
                    );

                    await _dbHelper.clearAllData();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ تم مسح جميع البيانات بنجاح')),
                    );

                    // إعادة تحميل الإعدادات
                    _loadAllSettings();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ خطأ في مسح البيانات: ${e.toString()}')),
                    );
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                ),
                child: Text('مسح البيانات'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetDatabaseConfirmation() {
    _confirmDeleteController.clear();
    _deleteConfirmed = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('تأكيد إعادة تعيين قاعدة البيانات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ تحذير: هذا الإجراء سيحذف جميع البيانات ويعيد قاعدة البيانات إلى حالتها الأولية مع البيانات الأساسية فقط.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'للتأكيد، يرجى كتابة "إعادة تعيين" في الحقل أدناه:',
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _confirmDeleteController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'اكتب "إعادة تعيين" للتأكيد',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _deleteConfirmed = value.trim() == 'إعادة تعيين';
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: _deleteConfirmed ? () async {
                  try {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('جاري إعادة تعيين قاعدة البيانات...')),
                    );

                    await _dbHelper.resetDatabase();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ تم إعادة تعيين قاعدة البيانات بنجاح')),
                    );

                    // إعادة تحميل الإعدادات
                    _loadAllSettings();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ خطأ في إعادة تعيين قاعدة البيانات: ${e.toString()}')),
                    );
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text('إعادة تعيين'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDatabaseConfirmation() {
    _confirmDeleteController.clear();
    _deleteConfirmed = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('تأكيد حذف قاعدة البيانات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ تحذير: هذا الإجراء سيحذف قاعدة البيانات بالكامل وستحتاج إلى إعادة تثبيت التطبيق لاستخدامه مرة أخرى.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'للتأكيد، يرجى كتابة "حذف قاعدة البيانات" في الحقل أدناه:',
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _confirmDeleteController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'اكتب "حذف قاعدة البيانات" للتأكيد',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _deleteConfirmed = value.trim() == 'حذف قاعدة البيانات';
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: _deleteConfirmed ? () async {
                  try {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('جاري حذف قاعدة البيانات...')),
                    );

                    await _dbHelper._dbHelper.deleteDatabase();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ تم حذف قاعدة البيانات بنجاح')),
                    );

                    // إغلاق التطبيق
                    SystemNavigator.pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ خطأ في حذف قاعدة البيانات: ${e.toString()}')),
                    );
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                ),
                child: Text('حذف قاعدة البيانات'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- دوال مساعدة للنوافذ المنبثقة ---

  String _getInvoiceTypeDisplayName(String type) {
    switch (type) {
      case 'sale':
        return 'فواتير البيع';
      case 'purchase':
        return 'فواتير الشراء';
      case 'sale_return':
        return 'مرتجعات البيع';
      case 'purchase_return':
        return 'مرتجعات الشراء';
      case 'stock_transfer':
        return 'تحويلات المخزون';
      case 'inventory_adjustment':
        return 'تعديلات الجرد';
      default:
        return type;
    }
  }

  void _showEditInvoiceNumberingDialog(Map<String, dynamic> setting) {
    final TextEditingController prefixController = TextEditingController(text: setting['prefix'] ?? '');
    final TextEditingController suffixController = TextEditingController(text: setting['suffix'] ?? '');
    final TextEditingController numberLengthController = TextEditingController(text: (setting['number_length'] ?? 5).toString());
    String resetFrequency = setting['reset_frequency'] ?? 'never';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('تعديل إعدادات ترقيم ${_getInvoiceTypeDisplayName(setting['invoice_type'])}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: prefixController,
                    decoration: InputDecoration(
                      labelText: 'بادئة الرقم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: suffixController,
                    decoration: InputDecoration(
                      labelText: 'لاحقة الرقم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: numberLengthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'طول الرقم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: resetFrequency,
                    decoration: InputDecoration(
                      labelText: 'تكرار إعادة التعيين',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'never', child: Text('لا يتم إعادة التعيين')),
                      DropdownMenuItem(value: 'daily', child: Text('يومياً')),
                      DropdownMenuItem(value: 'weekly', child: Text('أسبوعياً')),
                      DropdownMenuItem(value: 'monthly', child: Text('شهرياً')),
                      DropdownMenuItem(value: 'yearly', child: Text('سنوياً')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        resetFrequency = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _dbHelper.updateInvoiceNumbering(setting['id'], {
                      'prefix': prefixController.text.trim(),
                      'suffix': suffixController.text.trim(),
                      'number_length': int.tryParse(numberLengthController.text) ?? 5,
                      'reset_frequency': resetFrequency,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ تم تحديث إعدادات الترقيم')),
                    );

                    Navigator.pop(context);
                    // إعادة تحميل قائمة الإعدادات
                    _showInvoiceNumberingDialog();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ خطأ في تحديث الإعدادات: ${e.toString()}')),
                    );
                  }
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPaymentTermDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController dueDaysController = TextEditingController(text: '0');
    final TextEditingController discountPercentController = TextEditingController(text: '0');
    final TextEditingController discountDaysController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة شرط دفع جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الشرط',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: dueDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'فترة السداد (بالأيام)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: discountPercentController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'نسبة الخصم (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: discountDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'فترة الخصم (بالأيام)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.insertPaymentTerm({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'due_days': int.tryParse(dueDaysController.text) ?? 0,
                    'discount_percent': double.tryParse(discountPercentController.text) ?? 0.0,
                    'discount_days': int.tryParse(discountDaysController.text) ?? 0,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم إضافة شرط الدفع بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة شروط الدفع
                  _showPaymentTermsDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في إضافة شرط الدفع: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditPaymentTermDialog(Map<String, dynamic> term) {
    final TextEditingController nameController = TextEditingController(text: term['name']);
    final TextEditingController descriptionController = TextEditingController(text: term['description'] ?? '');
    final TextEditingController dueDaysController = TextEditingController(text: term['due_days'].toString());
    final TextEditingController discountPercentController = TextEditingController(text: term['discount_percent'].toString());
    final TextEditingController discountDaysController = TextEditingController(text: term['discount_days'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل شرط الدفع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الشرط',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: dueDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'فترة السداد (بالأيام)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: discountPercentController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'نسبة الخصم (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: discountDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'فترة الخصم (بالأيام)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.updatePaymentTerm(term['id'], {
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'due_days': int.tryParse(dueDaysController.text) ?? 0,
                    'discount_percent': double.tryParse(discountPercentController.text) ?? 0.0,
                    'discount_days': int.tryParse(discountDaysController.text) ?? 0,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم تحديث شرط الدفع بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة شروط الدفع
                  _showPaymentTermsDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في تحديث شرط الدفع: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeletePaymentTermConfirmation(Map<String, dynamic> term) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف شرط الدفع "${term['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbHelper.deletePaymentTerm(term['id']);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ تم حذف شرط الدفع بنجاح')),
                );

                Navigator.pop(context);
                // إعادة تحميل قائمة شروط الدفع
                _showPaymentTermsDialog();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ خطأ في حذف شرط الدفع: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showAddReturnPolicyDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController returnDaysController = TextEditingController(text: '0');
    final TextEditingController restockingFeeController = TextEditingController(text: '0');
    final TextEditingController conditionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة سياسة إرجاع جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم السياسة',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: returnDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'فترة الإرجاع (بالأيام)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: restockingFeeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'رسوم إعادة التخزين (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: conditionsController,
                decoration: InputDecoration(
                  labelText: 'شروط الإرجاع',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.insertReturnPolicy({
                    'name': nameController.text.trim(),
                    'return_days': int.tryParse(returnDaysController.text) ?? 0,
                    'restocking_fee': double.tryParse(restockingFeeController.text) ?? 0.0,
                    'conditions': conditionsController.text.trim(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم إضافة سياسة الإرجاع بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة سياسات الإرجاع
                  _showReturnPoliciesDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في إضافة سياسة الإرجاع: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditReturnPolicyDialog(Map<String, dynamic> policy) {
    final TextEditingController nameController = TextEditingController(text: policy['name']);
    final TextEditingController returnDaysController = TextEditingController(text: policy['return_days'].toString());
    final TextEditingController restockingFeeController = TextEditingController(text: policy['restocking_fee'].toString());
    final TextEditingController conditionsController = TextEditingController(text: policy['conditions'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل سياسة الإرجاع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم السياسة',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: returnDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'فترة الإرجاع (بالأيام)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: restockingFeeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'رسوم إعادة التخزين (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: conditionsController,
                decoration: InputDecoration(
                  labelText: 'شروط الإرجاع',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.updateReturnPolicy(policy['id'], {
                    'name': nameController.text.trim(),
                    'return_days': int.tryParse(returnDaysController.text) ?? 0,
                    'restocking_fee': double.tryParse(restockingFeeController.text) ?? 0.0,
                    'conditions': conditionsController.text.trim(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم تحديث سياسة الإرجاع بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة سياسات الإرجاع
                  _showReturnPoliciesDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في تحديث سياسة الإرجاع: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteReturnPolicyConfirmation(Map<String, dynamic> policy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف سياسة الإرجاع "${policy['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteReturnPolicy(policy['id']);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ تم حذف سياسة الإرجاع بنجاح')),
                );

                Navigator.pop(context);
                // إعادة تحميل قائمة سياسات الإرجاع
                _showReturnPoliciesDialog();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ خطأ في حذف سياسة الإرجاع: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'manager':
        return 'مدير';
      case 'warehouse':
        return 'مسؤول مخزون';
      case 'cashier':
        return 'أمين صندوق';
      case 'viewer':
        return 'مشاهد';
      default:
        return role;
    }
  }

  void _showAddUserDialog() {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    String selectedRole = 'cashier';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('إضافة مستخدم جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'الدور',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'admin', child: Text('مدير النظام')),
                      DropdownMenuItem(value: 'manager', child: Text('مدير')),
                      DropdownMenuItem(value: 'warehouse', child: Text('مسؤول مخزون')),
                      DropdownMenuItem(value: 'cashier', child: Text('أمين صندوق')),
                      DropdownMenuItem(value: 'viewer', child: Text('مشاهد')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (usernameController.text.trim().isNotEmpty &&
                      passwordController.text.trim().isNotEmpty &&
                      nameController.text.trim().isNotEmpty) {
                    try {
                      await _dbHelper.insertUser({
                        'username': usernameController.text.trim(),
                        'password': passwordController.text.trim(),
                        'name': nameController.text.trim(),
                        'role': selectedRole,
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ تم إضافة المستخدم بنجاح')),
                      );

                      Navigator.pop(context);
                      // إعادة تحميل قائمة المستخدمين
                      _showUsersManagement();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ خطأ في إضافة المستخدم: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final TextEditingController usernameController = TextEditingController(text: user['username']);
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController nameController = TextEditingController(text: user['name']);
    String selectedRole = user['role'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('تعديل بيانات المستخدم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور (اتركها فارغة إذا لم ترد تغييرها)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'الدور',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'admin', child: Text('مدير النظام')),
                      DropdownMenuItem(value: 'manager', child: Text('مدير')),
                      DropdownMenuItem(value: 'warehouse', child: Text('مسؤول مخزون')),
                      DropdownMenuItem(value: 'cashier', child: Text('أمين صندوق')),
                      DropdownMenuItem(value: 'viewer', child: Text('مشاهد')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (usernameController.text.trim().isNotEmpty &&
                      nameController.text.trim().isNotEmpty) {
                    try {
                      final userData = {
                        'username': usernameController.text.trim(),
                        'name': nameController.text.trim(),
                        'role': selectedRole,
                      };

                      // إضافة كلمة المرور فقط إذا تم إدخالها
                      if (passwordController.text.trim().isNotEmpty) {
                        userData['password'] = passwordController.text.trim();
                      }

                      await _dbHelper.updateUser(user['id'], userData);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ تم تحديث بيانات المستخدم بنجاح')),
                      );

                      Navigator.pop(context);
                      // إعادة تحميل قائمة المستخدمين
                      _showUsersManagement();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ خطأ في تحديث بيانات المستخدم: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteUserConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المستخدم "${user['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteUser(user['id']);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ تم حذف المستخدم بنجاح')),
                );

                Navigator.pop(context);
                // إعادة تحميل قائمة المستخدمين
                _showUsersManagement();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ خطأ في حذف المستخدم: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showPasswordPolicyDialog() async {
    // هذه الدالة ستنقل إلى شاشة سياسات كلمات المرور
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PasswordPolicyScreen()),
    );
  }

  void _showScheduledReportsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('التقارير المجدولة'),
        content: Text('هذه الميزة قيد التطوير وستكون متاحة في الإصدارات القادمة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showExportFormatsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('صيغ التصدير'),
        content: Text('هذه الميزة قيد التطوير وستكون متاحة في الإصدارات القادمة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showDateTimeFormatDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تنسيق التاريخ والوقت'),
        content: Text('هذه الميزة قيد التطوير وستكون متاحة في الإصدارات القادمة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showNumberFormatDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تنسيق الأرقام والعملة'),
        content: Text('هذه الميزة قيد التطوير وستكون متاحة في الإصدارات القادمة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSupplierPaymentTermsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('شروط الدفع للموردين'),
        content: Text('هذه الميزة قيد التطوير وستكون متاحة في الإصدارات القادمة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSupplierEvaluationSettings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تقييم الموردين'),
        content: Text('هذه الميزة قيد التطوير وستكون متاحة في الإصدارات القادمة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }


}