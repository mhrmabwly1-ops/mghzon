
import '../model/user_permissions.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  UserPermissions? _currentPermissions;
  String _currentUserRole = 'viewer';

  void setUserPermissions(String role) {
    _currentUserRole = role;
    _currentPermissions = UserPermissions.fromRole(role);
  }

  bool can(String permission) {
    return _currentPermissions?.can(permission) ?? false;
  }

  String get currentRole => _currentUserRole;

  // دوال مساعدة للتحقق من الصلاحيات الشائعة
  bool get canViewDashboard => can('view_dashboard');
  bool get canManageProducts => can('manage_products');
  bool get canManageCategories => can('manage_categories');
  bool get canManageWarehouses => can('manage_warehouses');
  bool get canManageSuppliers => can('manage_suppliers');
  bool get canManageCustomers => can('manage_customers');
  bool get canCreateSaleInvoices => can('create_sale_invoices');
  bool get canApproveSaleInvoices => can('approve_sale_invoices');
  bool get canCreatePurchaseInvoices => can('create_purchase_invoices');
  bool get canApprovePurchaseInvoices => can('approve_purchase_invoices');
  bool get canManageInventory => can('manage_inventory');
  bool get canManageStockTransfers => can('manage_stock_transfers');
  bool get canManageFinancial => can('manage_financial');
  bool get canViewReports => can('view_reports');
  bool get canManageUsers => can('manage_users');
  bool get canAccessSystemSettings => can('system_settings');
  bool get canDeleteRecords => can('delete_records');
  bool get canExportData => can('export_data');

  // الحصول على اسم الدور بالعربية
  String get roleName {
    switch (_currentUserRole) {
      case 'admin': return 'مدير النظام';
      case 'manager': return 'مدير';
      case 'warehouse': return 'أمين مخزن';
      case 'cashier': return 'كاشير';
      case 'viewer': return 'مشرف';
      default: return 'مستخدم';
    }
  }

  // الحصول على لون الدور
  String get roleColor {
    switch (_currentUserRole) {
      case 'admin': return '#FF0000';
      case 'manager': return '#FF9800';
      case 'warehouse': return '#2196F3';
      case 'cashier': return '#4CAF50';
      case 'viewer': return '#9E9E9E';
      default: return '#607D8B';
    }
  }
}