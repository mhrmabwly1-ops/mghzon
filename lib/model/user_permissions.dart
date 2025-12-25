class UserPermissions {
  final String role;
  final Map<String, bool> permissions;

  UserPermissions({
    required this.role,
    required this.permissions,
  });

  factory UserPermissions.fromRole(String role) {
    final basePermissions = _getBasePermissions(role);
    return UserPermissions(role: role, permissions: basePermissions);
  }

  static Map<String, bool> _getBasePermissions(String role) {
    switch (role) {
      case 'admin':
        return {
          'view_dashboard': true,
          'manage_products': true,
          'manage_categories': true,
          'manage_warehouses': true,
          'manage_suppliers': true,
          'manage_customers': true,
          'create_sale_invoices': true,
          'approve_sale_invoices': true,
          'create_purchase_invoices': true,
          'approve_purchase_invoices': true,
          'manage_inventory': true,
          'manage_stock_transfers': true,
          'manage_financial': true,
          'view_reports': true,
          'manage_users': true,
          'system_settings': true,
          'delete_records': true,
          'export_data': true,
        };
      case 'manager':
        return {
          'view_dashboard': true,
          'manage_products': true,
          'manage_categories': true,
          'manage_warehouses': true,
          'manage_suppliers': true,
          'manage_customers': true,
          'create_sale_invoices': true,
          'approve_sale_invoices': true,
          'create_purchase_invoices': true,
          'approve_purchase_invoices': true,
          'manage_inventory': true,
          'manage_stock_transfers': true,
          'manage_financial': true,
          'view_reports': true,
          'manage_users': false,
          'system_settings': false,
          'delete_records': false,
          'export_data': true,
        };
      case 'warehouse':
        return {
          'view_dashboard': true,
          'manage_products': true,
          'manage_categories': false,
          'manage_warehouses': true,
          'manage_suppliers': true,
          'manage_customers': false,
          'create_sale_invoices': false,
          'approve_sale_invoices': false,
          'create_purchase_invoices': true,
          'approve_purchase_invoices': false,
          'manage_inventory': true,
          'manage_stock_transfers': true,
          'manage_financial': false,
          'view_reports': true,
          'manage_users': false,
          'system_settings': false,
          'delete_records': false,
          'export_data': false,
        };
      case 'cashier':
        return {
          'view_dashboard': true,
          'manage_products': false,
          'manage_categories': false,
          'manage_warehouses': false,
          'manage_suppliers': false,
          'manage_customers': true,
          'create_sale_invoices': true,
          'approve_sale_invoices': false,
          'create_purchase_invoices': false,
          'approve_purchase_invoices': false,
          'manage_inventory': false,
          'manage_stock_transfers': false,
          'manage_financial': true,
          'view_reports': true,
          'manage_users': false,
          'system_settings': false,
          'delete_records': false,
          'export_data': false,
        };
      case 'viewer':
        return {
          'view_dashboard': true,
          'manage_products': false,
          'manage_categories': false,
          'manage_warehouses': false,
          'manage_suppliers': false,
          'manage_customers': false,
          'create_sale_invoices': false,
          'approve_sale_invoices': false,
          'create_purchase_invoices': false,
          'approve_purchase_invoices': false,
          'manage_inventory': false,
          'manage_stock_transfers': false,
          'manage_financial': false,
          'view_reports': true,
          'manage_users': false,
          'system_settings': false,
          'delete_records': false,
          'export_data': false,
        };
      default:
        return {};
    }
  }

  bool can(String permission) {
    return permissions[permission] ?? false;
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'permissions': permissions,
    };
  }

  factory UserPermissions.fromMap(Map<String, dynamic> map) {
    return UserPermissions(
      role: map['role'],
      permissions: Map<String, bool>.from(map['permissions']),
    );
  }
}