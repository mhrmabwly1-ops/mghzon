import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static Database? _db;

  // دوال المساعدة
  double safeParseDouble(dynamic value) => _safeParse<double>(value, 0.0);
  int safeParseInt(dynamic value) => _safeParse<int>(value, 0);

  T _safeParse<T>(dynamic value, T defaultValue) {
    if (value == null) return defaultValue;

    if (T == double) {
      if (value is double) return value as T;
      if (value is int) return value.toDouble() as T;
      if (value is String) return double.tryParse(value) as T? ?? defaultValue;
    }

    if (T == int) {
      if (value is int) return value as T;
      if (value is double) return value.toInt() as T;
      if (value is String) return int.tryParse(value) as T? ?? defaultValue;
    }

    return defaultValue;
  }

  Future<Database> get database async => _db ??= await initDb();

  Future<Database> initDb() async {
    String path = join(await getDatabasesPath(), 'inventory_system_v2.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _createAllTables,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  Future<void> _createAllTables(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    // 1. جدول المستخدمين (يجب إنشاؤه أولاً لأنه مرجع في جداول أخرى)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT CHECK(role IN ('admin', 'manager', 'warehouse', 'cashier', 'viewer')) DEFAULT 'cashier',
        permissions TEXT,
        is_active INTEGER DEFAULT 1,
        last_login TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. صلاحيات المستخدمين
    await db.execute('''
      CREATE TABLE user_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        permission_key TEXT NOT NULL,
        granted INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 3. جدول المخازن
    await db.execute('''
      CREATE TABLE warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        code TEXT UNIQUE,
        address TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 4. جدول الموردين
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        credit_limit REAL DEFAULT 0.0,
        balance REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 5. جدول العملاء
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        balance REAL DEFAULT 0,
        credit_limit REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 6. جدول الفئات
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        parent_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (parent_id) REFERENCES categories (id)
      )
    ''');

    // 7. جدول المنتجات
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        category_id INTEGER,
        supplier_id INTEGER,
        unit TEXT DEFAULT 'قطعة',
        purchase_price REAL DEFAULT 0,
        sell_price REAL DEFAULT 0,
        cost_price REAL DEFAULT 0,
        min_stock_level INTEGER DEFAULT 0,
        initial_quantity INTEGER DEFAULT 0,
        current_quantity INTEGER DEFAULT 0,
        last_purchase_date TEXT,
        image_path TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // 8. جدول حركات المنتجات
    await db.execute('''
      CREATE TABLE product_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_id INTEGER,
        movement_type TEXT CHECK(movement_type IN ('purchase', 'sale', 'return', 'adjustment', 'transfer')) NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL,
        total_amount REAL,
        reference_type TEXT,
        reference_id INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // 9. جدول المعاملات
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('sale', 'purchase', 'return')),
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        supplier_id INTEGER,
        supplier_name TEXT,
        quantity INTEGER NOT NULL,
        unit_sell_price REAL,
        unit_purchase_price REAL,
        profit REAL,
        total_amount REAL NOT NULL,
        date TEXT NOT NULL,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // 10. جدول مخزون المنتجات في المخازن
    await db.execute('''
      CREATE TABLE warehouse_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER DEFAULT 0 CHECK(quantity >= 0),
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        UNIQUE(warehouse_id, product_id)
      )
    ''');

    // 11. جدول فواتير الشراء
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        total_amount REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled', 'partial')) DEFAULT 'draft',
        notes TEXT,
        invoice_date TEXT NOT NULL,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (created_by) REFERENCES users (id),
        FOREIGN KEY (approved_by) REFERENCES users (id)
      )
    ''');

    // 12. جدول بنود فواتير الشراء
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 13. جدول مرتجعات الشراء
    await db.execute('''
      CREATE TABLE purchase_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT UNIQUE NOT NULL,
        purchase_invoice_id INTEGER NOT NULL,
        supplier_id INTEGER,
        warehouse_id INTEGER NOT NULL,
        total_amount REAL DEFAULT 0,
        reason TEXT,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        return_date TEXT NOT NULL,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (created_by) REFERENCES users (id),
        FOREIGN KEY (approved_by) REFERENCES users (id)
      )
    ''');

    // 14. جدول بنود مرتجعات الشراء
    await db.execute('''
      CREATE TABLE purchase_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (purchase_return_id) REFERENCES purchase_returns (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 15. جدول فواتير البيع
    await db.execute('''
      CREATE TABLE sale_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        warehouse_id INTEGER NOT NULL,
        sub_total REAL NOT NULL DEFAULT 0 CHECK(sub_total >= 0),
        discount_amount REAL DEFAULT 0 CHECK(discount_amount >= 0),
        discount_percent REAL DEFAULT 0 CHECK(discount_percent BETWEEN 0 AND 100),
        tax_amount REAL DEFAULT 0 CHECK(tax_amount >= 0),
        tax_percent REAL DEFAULT 0 CHECK(tax_percent BETWEEN 0 AND 100),
        total_amount REAL NOT NULL DEFAULT 0 CHECK(total_amount >= 0),
        paid_amount REAL DEFAULT 0 CHECK(paid_amount >= 0),
        remaining_amount REAL DEFAULT 0 CHECK(remaining_amount >= 0),
        due_date TEXT,
        transfer_reference TEXT,
        transfer_bank TEXT,
        transfer_date TEXT,
        guarantee_details TEXT,
        cash_received INTEGER DEFAULT 0,
        transfer_confirmed INTEGER DEFAULT 0,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'transfer', 'credit')),
        status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN (
          'draft', 'pending', 'approved', 'cancelled', 'partial', 'refunded'
        )),
        notes TEXT,
        invoice_date TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        approved_by INTEGER,
        approved_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE RESTRICT,
        FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE RESTRICT,
        FOREIGN KEY (approved_by) REFERENCES users (id) ON DELETE SET NULL,
        CHECK(paid_amount <= total_amount),
        CHECK(total_amount = sub_total - discount_amount + tax_amount)
      )
    ''');

    // 16. جدول بنود فواتير البيع
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit_price REAL NOT NULL CHECK(unit_price >= 0),
        cost_price REAL NOT NULL CHECK(cost_price >= 0),
        discount_amount REAL DEFAULT 0 CHECK(discount_amount >= 0),
        discount_percent REAL DEFAULT 0 CHECK(discount_percent BETWEEN 0 AND 100),
        tax_amount REAL DEFAULT 0 CHECK(tax_amount >= 0),
        tax_percent REAL DEFAULT 0 CHECK(tax_percent BETWEEN 0 AND 100),
        net_price REAL DEFAULT 0,
        total_price REAL DEFAULT 0,
        profit REAL DEFAULT 0,
        total_cost REAL DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sale_invoice_id) REFERENCES sale_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT,
        UNIQUE(sale_invoice_id, product_id),
        CHECK(discount_amount <= unit_price),
        CHECK(unit_price >= cost_price)
      )
    ''');

    // 17. جدول مرتجعات البيع
    await db.execute('''
      CREATE TABLE sale_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT UNIQUE NOT NULL,
        sale_invoice_id INTEGER NOT NULL,
        customer_id INTEGER,
        warehouse_id INTEGER NOT NULL,
        total_amount REAL DEFAULT 0,
        reason TEXT,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        return_date TEXT NOT NULL,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sale_invoice_id) REFERENCES sale_invoices (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (created_by) REFERENCES users (id),
        FOREIGN KEY (approved_by) REFERENCES users (id)
      )
    ''');

    // 18. جدول بنود مرتجعات البيع
    await db.execute('''
      CREATE TABLE sale_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sale_return_id) REFERENCES sale_returns (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 19. جدول سندات القبض
    await db.execute('''
      CREATE TABLE receipt_vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT CHECK(payment_method IN ('cash', 'transfer', 'check')) DEFAULT 'cash',
        payment_date TEXT NOT NULL,
        notes TEXT,
        reference_type TEXT CHECK(reference_type IN ('invoice', 'advance', 'other')),
        reference_id INTEGER,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // 20. جدول سندات الصرف
    await db.execute('''
      CREATE TABLE payment_vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT CHECK(payment_method IN ('cash', 'transfer', 'check')) DEFAULT 'cash',
        payment_date TEXT NOT NULL,
        notes TEXT,
        reference_type TEXT CHECK(reference_type IN ('invoice', 'expense', 'salary', 'other')),
        reference_id INTEGER,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // 21. جدول تحويلات المخزون
    await db.execute('''
      CREATE TABLE stock_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_number TEXT UNIQUE NOT NULL,
        from_warehouse_id INTEGER NOT NULL,
        to_warehouse_id INTEGER NOT NULL,
        total_items INTEGER DEFAULT 0,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        transfer_date TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (from_warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (to_warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (created_by) REFERENCES users (id),
        FOREIGN KEY (approved_by) REFERENCES users (id)
      )
    ''');

    // 22. جدول بنود تحويلات المخزون
    await db.execute('''
      CREATE TABLE stock_transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_transfer_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (stock_transfer_id) REFERENCES stock_transfers (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 23. جدول تعديلات الجرد
    await db.execute('''
      CREATE TABLE inventory_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        adjustment_number TEXT UNIQUE NOT NULL,
        warehouse_id INTEGER NOT NULL,
        adjustment_type TEXT CHECK(adjustment_type IN ('increase', 'decrease', 'correction')) NOT NULL,
        total_items INTEGER DEFAULT 0,
        reason TEXT NOT NULL,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        adjustment_date TEXT NOT NULL,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (created_by) REFERENCES users (id),
        FOREIGN KEY (approved_by) REFERENCES users (id)
      )
    ''');

    // 24. جدول بنود تعديلات الجرد
    await db.execute('''
      CREATE TABLE adjustment_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        adjustment_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        current_quantity INTEGER NOT NULL,
        new_quantity INTEGER NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (adjustment_id) REFERENCES inventory_adjustments (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 25. جدول سجل الصندوق
    await db.execute('''
      CREATE TABLE cash_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_type TEXT CHECK(transaction_type IN ('receipt', 'payment', 'opening_balance')) NOT NULL,
        amount REAL NOT NULL,
        balance_after REAL NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // 26. جدول سجل التدقيق
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        table_name TEXT,
        record_id INTEGER,
        description TEXT,
        old_values TEXT,
        new_values TEXT,
        ip_address TEXT,
        user_agent TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // 27. جدول التنبيهات
    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alert_type TEXT CHECK(alert_type IN ('low_stock', 'expiry', 'payment_due', 'system')) NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        priority TEXT CHECK(priority IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
        is_read INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        expires_at TEXT
      )
    ''');

    // إنشاء الفهارس
    await _createIndexes(db);

    // إضافة البيانات الأساسية
    await _seedInitialData(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_warehouse_stock_product ON warehouse_stock(product_id)');
    await db.execute('CREATE INDEX idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)');
    await db.execute('CREATE INDEX idx_purchase_invoice_date ON purchase_invoices(invoice_date)');
    await db.execute('CREATE INDEX idx_sale_invoice_date ON sale_invoices(invoice_date)');
    await db.execute('CREATE INDEX idx_audit_log_created_at ON audit_log(created_at)');
    await db.execute('CREATE INDEX idx_cash_ledger_date ON cash_ledger(transaction_date)');
    await db.execute('CREATE INDEX idx_sale_invoice_customer ON sale_invoices(customer_id)');
    await db.execute('CREATE INDEX idx_sale_invoice_date_status ON sale_invoices(invoice_date, status)');
    await db.execute('CREATE INDEX idx_product_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_alerts_read ON alerts(is_read, priority)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
  }

  Future<void> _seedInitialData(Database db) async {
    // إضافة مخزن افتراضي
    await db.insert('warehouses', {
      'name': 'المخزن الرئيسي',
      'code': 'MAIN',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    // إضافة مستخدم مدير
    await db.insert('users', {
      'username': 'admin',
      'password': _hashPassword('admin123'), // تشفير كلمة المرور
      'name': 'مدير النظام',
      'role': 'admin',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    // إضافة رصيد افتتاحي للصندوق
    await db.insert('cash_ledger', {
      'transaction_type': 'opening_balance',
      'amount': 10000.0,
      'balance_after': 10000.0,
      'description': 'رصيد افتتاحي',
      'transaction_date': DateTime.now().toIso8601String(),
      'created_by': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  String _hashPassword(String password) {
    // تشفير بسيط (في التطبيق الحقيقي استخدم مكتبة تشفير أقوى)
    var bytes = utf8.encode(password + 'salt_12345');
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ========== دوال إحصائيات Dashboard ==========
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;

    final totalProducts = await db.rawQuery('SELECT COUNT(*) as count FROM products WHERE is_active = 1');
    final totalCustomers = await db.rawQuery('SELECT COUNT(*) as count FROM customers WHERE is_active = 1');
    final totalSuppliers = await db.rawQuery('SELECT COUNT(*) as count FROM suppliers WHERE is_active = 1');
    final totalWarehouses = await db.rawQuery('SELECT COUNT(*) as count FROM warehouses WHERE is_active = 1');

    final todaySales = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as amount 
      FROM sale_invoices 
      WHERE status = "approved" AND date(invoice_date) = date("now")
    ''');

    final todayPurchases = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as amount 
      FROM purchase_invoices 
      WHERE status = "approved" AND date(invoice_date) = date("now")
    ''');

    final lowStockProducts = await db.rawQuery('''
      SELECT COUNT(DISTINCT p.id) as count 
      FROM products p 
      JOIN warehouse_stock ws ON p.id = ws.product_id 
      WHERE p.is_active = 1 AND p.min_stock_level > 0 AND ws.quantity <= p.min_stock_level
    ''');

    final totalAlerts = await db.rawQuery('SELECT COUNT(*) as count FROM alerts WHERE is_read = 0');
    final todayTransactions = await db.rawQuery('''
      SELECT COUNT(*) as count FROM (
        SELECT id FROM sale_invoices WHERE date(created_at) = date("now")
        UNION ALL
        SELECT id FROM purchase_invoices WHERE date(created_at) = date("now")
      )
    ''');

    final cashBalanceResult = await db.rawQuery('''
      SELECT balance_after FROM cash_ledger ORDER BY id DESC LIMIT 1
    ''');
    final cashBalance = cashBalanceResult.isNotEmpty ? cashBalanceResult.first['balance_after'] as double : 0.0;

    final todayProfit = await db.rawQuery('''
      SELECT COALESCE(SUM(si.quantity * (si.unit_price - si.cost_price)), 0) as profit
      FROM sale_items si
      JOIN sale_invoices s ON si.sale_invoice_id = s.id
      WHERE s.status = 'approved' AND date(s.invoice_date) = date('now')
    ''');

    final pendingInvoices = await db.rawQuery('''
      SELECT COUNT(*) as count FROM sale_invoices WHERE status = 'draft'
    ''');

    return {
      'total_products': totalProducts.first['count'] as int,
      'total_customers': totalCustomers.first['count'] as int,
      'total_suppliers': totalSuppliers.first['count'] as int,
      'total_warehouses': totalWarehouses.first['count'] as int,
      'today_sales': todaySales.first['amount'] as double,
      'today_purchases': todayPurchases.first['amount'] as double,
      'low_stock_products': lowStockProducts.first['count'] as int,
      'total_alerts': totalAlerts.first['count'] as int,
      'today_transactions': todayTransactions.first['count'] as int,
      'cash_balance': cashBalance,
      'today_profit': todayProfit.first['profit'] as double,
      'pending_invoices': pendingInvoices.first['count'] as int,
    };
  }

  // ========== دوال إدارة المخازن ==========
  Future<int> insertWarehouse(Map<String, dynamic> warehouse) async {
    final db = await database;
    return await db.insert('warehouses', {
      ...warehouse,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getWarehouses() async {
    final db = await database;
    return await db.query('warehouses',
        where: 'is_active = 1',
        orderBy: 'name ASC'
    );
  }

  Future<int> updateWarehouse(int id, Map<String, dynamic> warehouse) async {
    final db = await database;
    return await db.update(
      'warehouses',
      warehouse,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWarehouse(int id) async {
    final db = await database;
    return await db.update(
      'warehouses',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== دوال إدارة المنتجات ==========
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final productId = await db.insert('products', {
      ...product,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // إضافة السجل في جميع المخازن
    final warehouses = await getWarehouses();
    for (final warehouse in warehouses) {
      await db.insert('warehouse_stock', {
        'warehouse_id': warehouse['id'],
        'product_id': productId,
        'quantity': product['initial_quantity'] ?? 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return productId;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE p.is_active = 1 
      ORDER BY p.name ASC
    ''');
  }

  Future<Map<String, dynamic>?> getProductStock(int productId, int warehouseId) async {
    final db = await database;
    final result = await db.query(
      'warehouse_stock',
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    return await db.update(
      'products',
      {
        ...product,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProduct(int productId) async {
    final db = await database;
    return await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE p.barcode = ? AND p.is_active = 1
    ''', [barcode]);
    return result.isNotEmpty ? result.first : null;
  }

  // ========== دوال إدارة العملاء ==========
  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    return await db.insert('customers', {
      ...customer,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    final db = await database;
    return await db.update(
      'customers',
      {
        ...customer,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.update(
      'customers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return await db.query('customers',
        where: 'is_active = 1',
        orderBy: 'name ASC'
    );
  }

  Future<Map<String, dynamic>?> getCustomer(int id) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ========== دوال إدارة الموردين ==========
  Future<int> insertSupplier(Map<String, dynamic> supplier) async {
    final db = await database;
    return await db.insert('suppliers', {
      ...supplier,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateSupplier(int id, Map<String, dynamic> supplier) async {
    final db = await database;
    return await db.update(
      'suppliers',
      {
        ...supplier,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return await db.update(
      'suppliers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await database;
    return await db.query(
      'suppliers',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
  }

  // ========== دوال الفئات ==========
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('categories', {
      ...category,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
//الدوال الناقصة ===================================================================
  Future<void> updateProductStockForSale(int productId, int warehouseId, int quantity) async {
    final db = await database;

    await db.transaction((txn) async {
      // تحديث جدول المنتجات
      final product = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (product.isNotEmpty) {
        final currentQty = product.first['current_quantity'] as int;
        final newQty = currentQty - quantity;

        await txn.update(
          'products',
          {
            'current_quantity': newQty,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      // تحديث مخزون المخزن
      final warehouseStock = await txn.query(
        'warehouse_stock',
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId],
      );

      if (warehouseStock.isNotEmpty) {
        final currentStock = warehouseStock.first['quantity'] as int;
        final newStock = currentStock - quantity;

        await txn.update(
          'warehouse_stock',
          {
            'quantity': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [productId, warehouseId],
        );
      }
    });
  }
  Future<Map<String, dynamic>> createPurchaseInvoiceWithItems(
      Map<String, dynamic> invoice,
      List<Map<String, dynamic>> items,
      int userId  // أضف userId كمعامل
      ) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم الفاتورة
        final invoiceNumber = 'P${DateTime.now().millisecondsSinceEpoch}';

        // 2. إدخال الفاتورة
        final invoiceId = await txn.insert('purchase_invoices', {
          ...invoice,
          'invoice_number': invoiceNumber,
          'created_by': userId,  // استخدام userId
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود وتحديث المخزون
        double totalAmount = 0;
        for (final item in items) {
          final totalPrice = (item['quantity'] as int) * (item['unit_price'] as double);
          totalAmount += totalPrice;

          await txn.insert('purchase_items', {
            ...item,
            'purchase_invoice_id': invoiceId,
            'total_price': totalPrice,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث تكلفة المنتج (cost_price) إذا كانت موجودة
          if (item['cost_price'] != null) {
            await txn.update(
              'products',
              {
                'cost_price': item['cost_price'],
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [item['product_id']],
            );
          }

          // 5. تحديث مخزون المنتج (الجزء الأساسي)
          await _updateProductStock(
              txn,
              item['product_id'] as int,
              invoice['warehouse_id'] as int,
              item['quantity'] as int,
              true  // زيادة
          );
        }

        // 6. تحديث المبلغ الإجمالي
        await txn.update(
          'purchase_invoices',
          {'total_amount': totalAmount},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        return {
          'success': true,
          'invoice_id': invoiceId,
          'invoice_number': invoiceNumber,
          'total_amount': totalAmount,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء الفاتورة: ${e.toString()}'
      };
    }
  }
  Future<void> updateCustomerBalance(int customerId, double amount, bool isIncrease) async {
    final db = await database;

    await db.transaction((txn) async {
      final customer = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
      );

      if (customer.isNotEmpty) {
        final currentBalance = customer.first['balance'] as double;
        final newBalance = isIncrease ? currentBalance + amount : currentBalance - amount;

        await txn.update(
          'customers',
          {
            'balance': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [customerId],
        );
      }
    });
  }
  Future<List<Map<String, dynamic>>> getWarehouseStockForAdjustment(int warehouseId) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      p.min_stock_level,
      COALESCE(ws.quantity, 0) as current_quantity,
      c.name as category_name
    FROM products p
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id AND ws.warehouse_id = ?
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE p.is_active = 1
    ORDER BY p.name ASC
  ''', [warehouseId]);
  }
  Future<List<Map<String, dynamic>>> getWarehouseStockForTransfer(int warehouseId) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      p.min_stock_level,
      COALESCE(ws.quantity, 0) as current_quantity,
      c.name as category_name
    FROM products p
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id AND ws.warehouse_id = ?
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE p.is_active = 1 AND COALESCE(ws.quantity, 0) > 0
    ORDER BY p.name ASC
  ''', [warehouseId]);
  }
  Future<Map<String, dynamic>> addOpeningBalance(double amount, DateTime date) async {
    final db = await database;

    try {
      // الحصول على آخر رصيد
      final lastBalanceResult = await db.rawQuery(
          'SELECT balance_after FROM cash_ledger ORDER BY id DESC LIMIT 1'
      );

      double currentBalance = 0;
      if (lastBalanceResult.isNotEmpty) {
        currentBalance = lastBalanceResult.first['balance_after'] as double;
      }

      final newBalance = currentBalance + amount;

      await db.insert('cash_ledger', {
        'transaction_type': 'opening_balance',
        'amount': amount,
        'balance_after': newBalance,
        'reference_type': 'opening_balance',
        'reference_id': 0,
        'description': 'رصيد افتتاحي',
        'transaction_date': date.toIso8601String(),
        'created_by': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'تم إضافة الرصيد الافتتاحي بنجاح',
        'new_balance': newBalance
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إضافة الرصيد الافتتاحي: ${e.toString()}'
      };
    }
  }
  Future<Map<String, dynamic>> deleteInventoryAdjustment(int adjustmentId) async {
    final db = await database;

    try {
      final adjustment = await db.query(
        'inventory_adjustments',
        where: 'id = ?',
        whereArgs: [adjustmentId],
      );

      if (adjustment.isEmpty) {
        return {'success': false, 'error': 'تعديل الجرد غير موجود'};
      }

      if (adjustment.first['status'] != 'draft') {
        return {'success': false, 'error': 'لا يمكن حذف تعديل معتمد'};
      }

      await db.transaction((txn) async {
        // حذف بنود التعديل
        await txn.delete(
          'adjustment_items',
          where: 'adjustment_id = ?',
          whereArgs: [adjustmentId],
        );

        // حذف التعديل الرئيسي
        await txn.delete(
          'inventory_adjustments',
          where: 'id = ?',
          whereArgs: [adjustmentId],
        );
      });

      return {'success': true, 'message': 'تم حذف تعديل الجرد بنجاح'};
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف تعديل الجرد: ${e.toString()}'};
    }
  }
  Future<Map<String, dynamic>> approveInventoryAdjustment(int adjustmentId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // جلب التعديل
        final adjustment = await txn.query(
          'inventory_adjustments',
          where: 'id = ? AND status = ?',
          whereArgs: [adjustmentId, 'draft'],
        );

        if (adjustment.isEmpty) {
          throw Exception('تعديل الجرد غير موجود أو غير قابل للاعتماد');
        }

        // جلب بنود التعديل
        final items = await txn.query(
          'adjustment_items',
          where: 'adjustment_id = ?',
          whereArgs: [adjustmentId],
        );

        final warehouseId = adjustment.first['warehouse_id'];

        // تحديث المخزون للبنود
        for (final item in items) {
          await _updateProductStockForAdjustment(
            txn,
            item['product_id'] as int,
            warehouseId as int,
            item['new_quantity'] as int,
          );
        }

        // تحديث حالة التعديل
        await txn.update(
          'inventory_adjustments',
          {
            'status': 'approved',
            'approved_by': 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [adjustmentId],
        );

        // تسجيل في سجل التدقيق
        await txn.insert('audit_log', {
          'user_id': 1,
          'action': 'APPROVE_INVENTORY_ADJUSTMENT',
          'table_name': 'inventory_adjustments',
          'record_id': adjustmentId,
          'description': 'تم اعتماد تعديل الجرد رقم ${adjustment.first['adjustment_number']}',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      return {
        'success': true,
        'message': 'تم اعتماد تعديل الجرد بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد تعديل الجرد: ${e.toString()}'
      };
    }
  }
  Future<Map<String, dynamic>?> getInventoryAdjustmentWithItems(int adjustmentId) async {
    final db = await database;

    final adjustment = await db.rawQuery('''
    SELECT ia.*, 
           w.name as warehouse_name,
           u.name as created_by_name,
           u2.name as approved_by_name
    FROM inventory_adjustments ia
    LEFT JOIN warehouses w ON ia.warehouse_id = w.id
    LEFT JOIN users u ON ia.created_by = u.id
    LEFT JOIN users u2 ON ia.approved_by = u2.id
    WHERE ia.id = ?
  ''', [adjustmentId]);

    if (adjustment.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT ai.*, 
           p.name as product_name,
           p.barcode,
           p.sell_price,
           p.purchase_price,
           ws.quantity as current_stock
    FROM adjustment_items ai
    JOIN products p ON ai.product_id = p.id
    LEFT JOIN warehouse_stock ws ON ai.product_id = ws.product_id AND ws.warehouse_id = ?
    WHERE ai.adjustment_id = ?
  ''', [adjustment.first['warehouse_id'], adjustmentId]);

    return {
      'adjustment': adjustment.first,
      'items': items,
    };
  }
  Future<Map<String, dynamic>> deletePaymentVoucher(int voucherId) async {
    final db = await database;

    try {
      final voucher = await db.query(
        'payment_vouchers',
        where: 'id = ?',
        whereArgs: [voucherId],
      );

      if (voucher.isEmpty) {
        return {'success': false, 'error': 'السند غير موجود'};
      }

      final supplierId = (voucher.first['supplier_id'] as int?);
      final amount = (voucher.first['amount'] as num?)?.toDouble() ?? 0.0;

      await db.transaction((txn) async {
        // التراجع عن تحديث رصيد المورد
        if (supplierId != null) {
          await _updateSupplierBalance(
            txn,
            supplierId,
            amount,
            true, // زيادة الدائن
          );
        }

        // حذف السند
        await txn.delete(
          'payment_vouchers',
          where: 'id = ?',
          whereArgs: [voucherId],
        );
      });

      return {'success': true, 'message': 'تم حذف سند الصرف بنجاح'};
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف سند الصرف: ${e.toString()}'};
    }
  }
  Future<List<Map<String, dynamic>>> getSupplierProfitReport(DateTime startDate, DateTime endDate) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      s.id,
      s.name,
      s.phone,
      COUNT(pi.id) as purchase_invoices,
      COALESCE(SUM(pi.total_amount), 0) as total_purchases,
      COALESCE(SUM(pi.paid_amount), 0) as total_paid,
      (
        SELECT COALESCE(SUM(si.quantity * (si.unit_price - si.cost_price)), 0)
        FROM sale_items si
        JOIN sale_invoices sinv ON si.sale_invoice_id = sinv.id
        JOIN products p ON si.product_id = p.id
        WHERE p.id IN (
          SELECT product_id FROM purchase_items WHERE purchase_invoice_id IN (
            SELECT id FROM purchase_invoices WHERE supplier_id = s.id
          )
        )
        AND sinv.status = 'approved'
        AND date(sinv.invoice_date) BETWEEN ? AND ?
      ) as generated_profit
    FROM suppliers s
    LEFT JOIN purchase_invoices pi ON s.id = pi.supplier_id 
      AND pi.status = 'approved'
      AND date(pi.invoice_date) BETWEEN ? AND ?
    WHERE s.is_active = 1
    GROUP BY s.id
    ORDER BY generated_profit DESC
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate),
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);
  }
  Future<List<Map<String, dynamic>>> getProductProfitReport(DateTime startDate, DateTime endDate) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      c.name as category_name,
      SUM(si.quantity) as total_sold,
      SUM(si.quantity * si.unit_price) as total_revenue,
      SUM(si.quantity * si.cost_price) as total_cost,
      SUM(si.quantity * (si.unit_price - si.cost_price)) as total_profit,
      AVG(si.unit_price - si.cost_price) as avg_profit_per_unit,
      (SUM(si.quantity * (si.unit_price - si.cost_price)) / SUM(si.quantity * si.unit_price)) * 100 as profit_margin
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    JOIN products p ON si.product_id = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE s.status = 'approved' 
      AND date(s.invoice_date) BETWEEN ? AND ?
    GROUP BY p.id
    HAVING total_sold > 0
    ORDER BY total_profit DESC
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);
  }
  Future<List<Map<String, dynamic>>> getDailyProfitReport(DateTime startDate, DateTime endDate) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      date(s.invoice_date) as date,
      COUNT(DISTINCT s.id) as invoices_count,
      SUM(si.quantity) as items_sold,
      SUM(si.quantity * si.unit_price) as daily_revenue,
      SUM(si.quantity * si.cost_price) as daily_cost,
      SUM(si.quantity * (si.unit_price - si.cost_price)) as daily_profit,
      (SUM(si.quantity * (si.unit_price - si.cost_price)) / SUM(si.quantity * si.unit_price)) * 100 as daily_margin
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    WHERE s.status = 'approved' 
      AND date(s.invoice_date) BETWEEN ? AND ?
    GROUP BY date(s.invoice_date)
    ORDER BY date(s.invoice_date) DESC
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);
  }
  Future<List<Map<String, dynamic>>> getProfitMarginReport() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.purchase_price,
      p.cost_price,
      p.sell_price,
      (p.sell_price - p.cost_price) as profit_per_unit,
      ((p.sell_price - p.cost_price) / p.cost_price) * 100 as profit_margin,
      COALESCE(SUM(ws.quantity), 0) as current_stock,
      (COALESCE(SUM(ws.quantity), 0) * (p.sell_price - p.cost_price)) as potential_profit
    FROM products p
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
    WHERE p.is_active = 1 AND p.cost_price > 0
    GROUP BY p.id
    ORDER BY profit_margin DESC
  ''');
  }
  Future<Map<String, dynamic>> deleteReceiptVoucher(int voucherId) async {
    final db = await database;

    try {
      final voucher = await db.query(
        'receipt_vouchers',
        where: 'id = ?',
        whereArgs: [voucherId],
      );

      if (voucher.isEmpty) {
        return {'success': false, 'error': 'السند غير موجود'};
      }

      final customerId = (voucher.first['customer_id'] as int?);
      final amount = (voucher.first['amount'] as num?)?.toDouble() ?? 0.0;

      await db.transaction((txn) async {
        // التراجع عن تحديث رصيد العميل
        if (customerId != null) {
          await _updateCustomerBalance(
            txn,
            customerId,
            amount,
            true, // زيادة المدين
          );
        }

        // حذف السند
        await txn.delete(
          'receipt_vouchers',
          where: 'id = ?',
          whereArgs: [voucherId],
        );
      });

      return {'success': true, 'message': 'تم حذف سند القبض بنجاح'};
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف سند القبض: ${e.toString()}'};
    }
  }
  Future<List<Map<String, dynamic>>> getCustomersReport() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      c.id,
      c.name,
      c.phone,
      c.balance,
      COUNT(si.id) as total_invoices,
      COALESCE(SUM(si.total_amount), 0) as total_purchases,
      MAX(si.invoice_date) as last_purchase_date,
      AVG(si.total_amount) as avg_purchase
    FROM customers c
    LEFT JOIN sale_invoices si ON c.id = si.customer_id AND si.status = 'approved'
    WHERE c.is_active = 1
    GROUP BY c.id
    ORDER BY total_purchases DESC
  ''');
  }
  Future<Map<String, dynamic>?> getSalesReturnWithItems(int returnId) async {
    final db = await database;

    final salesReturn = await db.rawQuery('''
    SELECT sr.*, 
           si.invoice_number as sale_invoice_number,
           c.name as customer_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM sale_returns sr
    LEFT JOIN sale_invoices si ON sr.sale_invoice_id = si.id
    LEFT JOIN customers c ON sr.customer_id = c.id
    LEFT JOIN warehouses w ON sr.warehouse_id = w.id
    LEFT JOIN users u ON sr.created_by = u.id
    WHERE sr.id = ?
  ''', [returnId]);

    if (salesReturn.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT sri.*, 
           p.name as product_name,
           p.barcode,
           p.sell_price
    FROM sale_return_items sri
    JOIN products p ON sri.product_id = p.id
    WHERE sri.sale_return_id = ?
  ''', [returnId]);

    return {
      'sales_return': salesReturn.first,
      'items': items,
    };
  }
  Future<Map<String, dynamic>?> getStockTransferWithItems(int transferId) async {
    final db = await database;

    final transfer = await db.rawQuery('''
    SELECT st.*, 
           w1.name as from_warehouse_name,
           w2.name as to_warehouse_name,
           u.name as created_by_name
    FROM stock_transfers st
    LEFT JOIN warehouses w1 ON st.from_warehouse_id = w1.id
    LEFT JOIN warehouses w2 ON st.to_warehouse_id = w2.id
    LEFT JOIN users u ON st.created_by = u.id
    WHERE st.id = ?
  ''', [transferId]);

    if (transfer.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT sti.*, 
           p.name as product_name,
           p.barcode,
           p.sell_price
    FROM stock_transfer_items sti
    JOIN products p ON sti.product_id = p.id
    WHERE sti.stock_transfer_id = ?
  ''', [transferId]);

    return {
      'transfer': transfer.first,
      'items': items,
    };
  }
  Future<Map<String, dynamic>> deleteStockTransfer(int transferId) async {
    final db = await database;

    try {
      final transfer = await db.query(
        'stock_transfers',
        where: 'id = ?',
        whereArgs: [transferId],
      );

      if (transfer.isEmpty) {
        return {'success': false, 'error': 'تحويل المخزون غير موجود'};
      }

      if (transfer.first['status'] != 'draft') {
        return {'success': false, 'error': 'لا يمكن حذف تحويل معتمد'};
      }

      await db.transaction((txn) async {
        // التراجع عن تحديث المخزون
        final items = await txn.query(
          'stock_transfer_items',
          where: 'stock_transfer_id = ?',
          whereArgs: [transferId],
        );

        for (final item in items) {
          final productId = item['product_id'] as int;
          final quantity = item['quantity'] as int;
          final fromWarehouseId = transfer.first['from_warehouse_id'] as int;
          final toWarehouseId = transfer.first['to_warehouse_id'] as int;

          // إعادة الكمية للمخزن المصدر
          await _updateProductStock(
            txn,
            productId,
            fromWarehouseId,
            quantity,
            true,
          );

          // سحب الكمية من المخزن الهدف
          await _updateProductStock(
            txn,
            productId,
            toWarehouseId,
            quantity,
            false,
          );
        }

        // حذف بنود التحويل
        await txn.delete(
          'stock_transfer_items',
          where: 'stock_transfer_id = ?',
          whereArgs: [transferId],
        );

        // حذف التحويل الرئيسي
        await txn.delete(
          'stock_transfers',
          where: 'id = ?',
          whereArgs: [transferId],
        );
      });

      return {'success': true, 'message': 'تم حذف تحويل المخزون بنجاح'};
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف تحويل المخزون: ${e.toString()}'};
    }
  }
  Future<Map<String, dynamic>> getSupplierDetailedReport(
      int supplierId, DateTime startDate, DateTime endDate) async {
    final db = await database;

    // معلومات المورد الأساسية
    final supplierInfo = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [supplierId],
    );

    if (supplierInfo.isEmpty) {
      return {'error': 'المورد غير موجود'};
    }

    // فواتير الشراء من المورد
    final purchaseInvoices = await db.rawQuery('''
    SELECT 
      pi.*,
      w.name as warehouse_name,
      u.name as created_by_name
    FROM purchase_invoices pi
    LEFT JOIN warehouses w ON pi.warehouse_id = w.id
    LEFT JOIN users u ON pi.created_by = u.id
    WHERE pi.supplier_id = ? 
      AND pi.status = 'approved'
      AND date(pi.invoice_date) BETWEEN ? AND ?
    ORDER BY pi.invoice_date DESC
  ''', [
      supplierId,
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // جمع إحصائيات الفواتير
    double totalPurchases = 0.0;
    double totalPaid = 0.0;
    int totalItems = 0;

    for (final invoice in purchaseInvoices) {
      totalPurchases += (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalPaid += (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;

      final itemsCount = await db.rawQuery('''
      SELECT COUNT(*) as count FROM purchase_items 
      WHERE purchase_invoice_id = ?
    ''', [invoice['id']]);

      totalItems += itemsCount.isNotEmpty ? (itemsCount.first['count'] as int) : 0;
    }

    // المنتجات المشتراة من المورد
    final supplierProducts = await db.rawQuery('''
    SELECT DISTINCT
      p.id,
      p.name,
      p.barcode,
      p.purchase_price,
      p.sell_price,
      p.cost_price,
      (SELECT SUM(quantity) FROM purchase_items WHERE product_id = p.id AND purchase_invoice_id IN (
        SELECT id FROM purchase_invoices WHERE supplier_id = ?
      )) as total_purchased_quantity,
      (SELECT COALESCE(SUM(quantity), 0) FROM sale_items WHERE product_id = p.id AND sale_invoice_id IN (
        SELECT id FROM sale_invoices WHERE status = 'approved'
      )) as total_sold_quantity
    FROM products p
    WHERE p.id IN (
      SELECT DISTINCT product_id FROM purchase_items WHERE purchase_invoice_id IN (
        SELECT id FROM purchase_invoices WHERE supplier_id = ?
      )
    )
  ''', [supplierId, supplierId]);

    return {
      'supplier_info': supplierInfo.first,
      'purchase_invoices': purchaseInvoices,
      'summary': {
        'total_purchases': totalPurchases,
        'total_paid': totalPaid,
        'remaining_balance': totalPurchases - totalPaid,
        'total_items_purchased': totalItems,
        'total_products': supplierProducts.length,
      },
      'supplier_products': supplierProducts,
    };
  }
  Future<List<Map<String, dynamic>>> getSuppliersReport() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      s.id,
      s.name,
      s.phone,
      s.balance,
      COUNT(pi.id) as total_invoices,
      COALESCE(SUM(pi.total_amount), 0) as total_purchases,
      COALESCE(SUM(pi.paid_amount), 0) as total_paid,
      MAX(pi.invoice_date) as last_purchase_date,
      AVG(pi.total_amount) as avg_purchase
    FROM suppliers s
    LEFT JOIN purchase_invoices pi ON s.id = pi.supplier_id AND pi.status = 'approved'
    WHERE s.is_active = 1
    GROUP BY s.id
    ORDER BY total_purchases DESC
  ''');
  }
  Future<Map<String, dynamic>> approveStockTransfer(int transferId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // التحقق من وجود التحويل وحالة المسودة
        final transfer = await txn.query(
          'stock_transfers',
          where: 'id = ? AND status = ?',
          whereArgs: [transferId, 'draft'],
        );

        if (transfer.isEmpty) {
          throw Exception('تحويل المخزون غير موجود أو غير قابل للاعتماد');
        }

        // جلب بنود التحويل
        final items = await txn.query(
          'stock_transfer_items',
          where: 'stock_transfer_id = ?',
          whereArgs: [transferId],
        );

        final fromWarehouseId = transfer.first['from_warehouse_id'] as int;
        final toWarehouseId = transfer.first['to_warehouse_id'] as int;

        // التحقق من توفر الكميات في المخزن المصدر
        for (final item in items) {
          final stock = await txn.query(
            'warehouse_stock',
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [item['product_id'], fromWarehouseId],
          );

          if (stock.isEmpty) {
            throw Exception('لا يوجد مخزون للمنتج: ${item['product_id']} في المخزن المصدر');
          }

          final availableQty = stock.first['quantity'] as int;
          final requiredQty = item['quantity'] as int;

          if (availableQty < requiredQty) {
            throw Exception(
              'الكمية غير متوفرة للمنتج: ${item['product_id']} — المتاح: $availableQty — المطلوب: $requiredQty',
            );
          }
        }

        // تطبيق التحويل: خصم من المصدر وإضافة للهدف
        for (final item in items) {
          final productId = item['product_id'] as int;
          final quantity = item['quantity'] as int;

          // خصم من المخزن المصدر
          await _updateProductStock(
            txn,
            productId,
            fromWarehouseId,
            quantity,
            false,
          );

          // إضافة للمخزن الهدف
          await _updateProductStock(
            txn,
            productId,
            toWarehouseId,
            quantity,
            true,
          );
        }

        // تحديث حالة التحويل
        await txn.update(
          'stock_transfers',
          {
            'status': 'approved',
            'approved_by': 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [transferId],
        );

        // تسجيل في سجل التدقيق
        await txn.insert('audit_log', {
          'user_id': 1,
          'action': 'APPROVE_STOCK_TRANSFER',
          'table_name': 'stock_transfers',
          'record_id': transferId,
          'description': 'تم اعتماد تحويل المخزون رقم ${transfer.first['transfer_number']}',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      return {
        'success': true,
        'message': 'تم اعتماد تحويل المخزون بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد تحويل المخزون: ${e.toString()}'
      };
    }
  }
  Future<List<Map<String, dynamic>>> getProductsWithDetails() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.*,
      c.name as category_name,
      s.name as supplier_name,
      s.phone as supplier_phone,
      s.email as supplier_email,
      COALESCE(SUM(ws.quantity), 0) as warehouse_quantity,
      (
        SELECT COUNT(*) FROM product_movements 
        WHERE product_id = p.id
      ) as movements_count,
      (
        SELECT SUM(quantity) FROM sale_items 
        WHERE product_id = p.id 
        AND sale_invoice_id IN (
          SELECT id FROM sale_invoices WHERE status = 'approved'
        )
      ) as total_sold,
      (
        SELECT SUM(quantity) FROM purchase_items 
        WHERE product_id = p.id
        AND purchase_invoice_id IN (
          SELECT id FROM purchase_invoices WHERE status = 'approved'
        )
      ) as total_purchased
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN suppliers s ON p.supplier_id = s.id
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
    WHERE p.is_active = 1
    GROUP BY p.id
    ORDER BY p.name ASC
  ''');
  }
  Future<Map<String, dynamic>> updateSupplierBalance(int supplierId, double amount, bool isIncrease) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // التحقق من وجود المورد
        final supplier = await txn.query(
          'suppliers',
          where: 'id = ? AND is_active = 1',
          whereArgs: [supplierId],
        );

        if (supplier.isEmpty) {
          throw Exception('المورد غير موجود أو غير مفعل');
        }

        // حساب الرصيد الجديد
        final currentBalance = supplier.first['balance'] as double;
        final newBalance = isIncrease ? currentBalance + amount : currentBalance - amount;

        // تحديث رصيد المورد
        await txn.update(
          'suppliers',
          {
            'balance': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [supplierId],
        );

        // تسجيل الحركة في سجل التدقيق
        await txn.insert('audit_log', {
          'user_id': 1,
          'action': 'UPDATE_SUPPLIER_BALANCE',
          'table_name': 'suppliers',
          'record_id': supplierId,
          'description': 'تم ${isIncrease ? 'زيادة' : 'تقليل'} رصيد المورد $supplierId بمبلغ $amount',
          'old_values': jsonEncode({'balance': currentBalance}),
          'new_values': jsonEncode({'balance': newBalance}),
          'created_at': DateTime.now().toIso8601String(),
        });

        // إذا كان المبلغ سالباً (المورد مدين)، تحقق من تجاوز حد الائتمان
        if (newBalance > (supplier.first['credit_limit'] as double)) {
          // إنشاء تنبيه
          await txn.insert('alerts', {
            'alert_type': 'payment_due',
            'title': 'تجاوز حد الائتمان',
            'message': 'المورد ${supplier.first['name']} تجاوز حد الائتمان. الرصيد الحالي: $newBalance',
            'reference_type': 'supplier',
            'reference_id': supplierId,
            'priority': 'high',
            'is_read': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      });

      return {
        'success': true,
        'message': 'تم تحديث رصيد المورد بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في تحديث رصيد المورد: ${e.toString()}'
      };
    }
  }
  Future<Map<String, dynamic>> getSupplierStats(int supplierId) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT 
      COUNT(*) as total_invoices,
      COALESCE(SUM(total_amount), 0) as total_purchases,
      COALESCE(SUM(paid_amount), 0) as total_paid,
      COALESCE(MAX(invoice_date), 'لا توجد فواتير') as last_purchase_date,
      COALESCE(AVG(total_amount), 0) as avg_purchase_amount,
      (
        SELECT COUNT(DISTINCT product_id) 
        FROM purchase_items 
        WHERE purchase_invoice_id IN (
          SELECT id FROM purchase_invoices 
          WHERE supplier_id = ? AND status = 'approved'
        )
      ) as unique_products_count,
      (
        SELECT COALESCE(SUM(quantity), 0)
        FROM purchase_items 
        WHERE purchase_invoice_id IN (
          SELECT id FROM purchase_invoices 
          WHERE supplier_id = ? AND status = 'approved'
        )
      ) as total_items_purchased
    FROM purchase_invoices 
    WHERE supplier_id = ? AND status = 'approved'
  ''', [supplierId, supplierId, supplierId]);

    return result.isNotEmpty ? result.first : {
      'total_invoices': 0,
      'total_purchases': 0.0,
      'total_paid': 0.0,
      'last_purchase_date': 'لا توجد فواتير',
      'avg_purchase_amount': 0.0,
      'unique_products_count': 0,
      'total_items_purchased': 0
    };
  }
  Future<Map<String, dynamic>> getWarehouseStockSummaryAll() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT 
      COUNT(DISTINCT p.id) as total_products,
      SUM(ws.quantity) as total_quantity,
      SUM(ws.quantity * p.sell_price) as total_value,
      SUM(CASE WHEN ws.quantity <= p.min_stock_level AND ws.quantity > 0 THEN 1 ELSE 0 END) as low_stock_products,
      SUM(CASE WHEN ws.quantity = 0 THEN 1 ELSE 0 END) as out_of_stock_products,
      COUNT(DISTINCT ws.warehouse_id) as active_warehouses
    FROM warehouse_stock ws
    JOIN products p ON ws.product_id = p.id
    JOIN warehouses w ON ws.warehouse_id = w.id
    WHERE p.is_active = 1 AND w.is_active = 1
  ''');

    final warehouseStats = await db.rawQuery('''
    SELECT 
      w.id,
      w.name,
      COUNT(DISTINCT ws.product_id) as products_count,
      SUM(ws.quantity) as total_quantity,
      SUM(ws.quantity * p.sell_price) as total_value
    FROM warehouses w
    LEFT JOIN warehouse_stock ws ON w.id = ws.warehouse_id
    LEFT JOIN products p ON ws.product_id = p.id
    WHERE w.is_active = 1
    GROUP BY w.id
    ORDER BY w.name
  ''');

    return {
      'summary': result.isNotEmpty ? result.first : {},
      'warehouse_stats': warehouseStats,
    };
  }
  Future<Map<String, dynamic>> updateWarehouseStock(int warehouseId, int productId, int quantity) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // 1. التحقق من وجود المنتج والمخزن
        final product = await txn.query(
          'products',
          where: 'id = ? AND is_active = 1',
          whereArgs: [productId],
        );

        if (product.isEmpty) {
          throw Exception('المنتج غير موجود أو غير مفعل');
        }

        final warehouse = await txn.query(
          'warehouses',
          where: 'id = ? AND is_active = 1',
          whereArgs: [warehouseId],
        );

        if (warehouse.isEmpty) {
          throw Exception('المخزن غير موجود أو غير مفعل');
        }

        // 2. الحصول على المخزون الحالي
        final stockResult = await txn.query(
          'warehouse_stock',
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [productId, warehouseId],
        );

        final int currentQuantity = stockResult.isNotEmpty
            ? (stockResult.first['quantity'] as int?) ?? 0
            : 0;

        // 3. حساب الفرق للتسجيل في الحركات
        final int difference = quantity - currentQuantity;
        final String movementType = difference > 0 ? 'increase' : 'decrease';

        // 4. تحديث أو إدخال السجل في warehouse_stock
        if (stockResult.isNotEmpty) {
          await txn.update(
            'warehouse_stock',
            {
              'quantity': quantity,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [productId, warehouseId],
          );
        } else {
          await txn.insert('warehouse_stock', {
            'warehouse_id': warehouseId,
            'product_id': productId,
            'quantity': quantity,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        // 5. تحديث الكمية الإجمالية للمنتج في جدول products
        final totalStockResult = await txn.rawQuery('''
        SELECT COALESCE(SUM(quantity), 0) as total_quantity 
        FROM warehouse_stock 
        WHERE product_id = ?
      ''', [productId]);

        final int totalQuantity = totalStockResult.isNotEmpty
            ? (totalStockResult.first['total_quantity'] as int?) ?? 0
            : 0;

        await txn.update(
          'products',
          {
            'current_quantity': totalQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [productId],
        );

        // 6. تسجيل الحركة في product_movements
        if (difference != 0) {
          await txn.insert('product_movements', {
            'product_id': productId,
            'movement_type': 'adjustment',
            'quantity': difference,
            'notes': 'تحديث يدوي لمخزون المخزن ${warehouse.first['name']} من $currentQuantity إلى $quantity',
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        // 7. تسجيل في سجل التدقيق
        await txn.insert('audit_log', {
          'user_id': 1, // TODO: استبدل بـ ID المستخدم الحقيقي
          'action': 'UPDATE_WAREHOUSE_STOCK',
          'table_name': 'warehouse_stock',
          'record_id': productId,
          'description': 'تم تحديث مخزون المنتج ${product.first['name']} (ID: $productId) في المخزن ${warehouse.first['name']} (ID: $warehouseId) من $currentQuantity إلى $quantity',
          'old_values': jsonEncode({'quantity': currentQuantity}),
          'new_values': jsonEncode({'quantity': quantity}),
          'created_at': DateTime.now().toIso8601String(),
        });

        // 8. التحقق من مستوى المخزون الأدنى وإنشاء تنبيه إذا لزم الأمر
        final int minStockLevel = product.first['min_stock_level'] as int;
        if (quantity <= minStockLevel && quantity > 0) {
          await txn.insert('alerts', {
            'alert_type': 'low_stock',
            'title': 'تنبيه مخزون منخفض',
            'message': 'المنتج ${product.first['name']} وصل لمستوى المخزون الأدنى ($quantity) في المخزن ${warehouse.first['name']}',
            'reference_type': 'product',
            'reference_id': productId,
            'priority': quantity == 0 ? 'critical' : 'high',
            'is_read': 0,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now().add(Duration(days: 7)).toIso8601String(),
          });
        }

        // 9. إذا كان المخزون أصبح صفراً، إنشاء تنبيه نَفَاذ
        if (quantity == 0 && currentQuantity > 0) {
          await txn.insert('alerts', {
            'alert_type': 'low_stock',
            'title': 'نفاذ المخزون',
            'message': 'المنتج ${product.first['name']} نفذ من المخزن ${warehouse.first['name']}',
            'reference_type': 'product',
            'reference_id': productId,
            'priority': 'critical',
            'is_read': 0,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now().add(Duration(days: 3)).toIso8601String(),
          });
        }
      });

      return {
        'success': true,
        'message': 'تم تحديث مخزون المخزن بنجاح',
        'data': {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'new_quantity': quantity,
        }
      };
    } catch (e) {
      print('❌ خطأ في updateWarehouseStock: $e');

      return {
        'success': false,
        'error': 'فشل في تحديث مخزون المخزن: ${e.toString()}',
        'error_details': e.toString(),
      };
    }
  }
  Future<int> updateCategory(int id, Map<String, dynamic> category) async {
    final db = await database;
    return await db.update(
      'categories',
      {
        ...category,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.update(
      'categories',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== دوال فواتير الشراء ==========
  Future<List<Map<String, dynamic>>> getPurchaseInvoices({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
      SELECT pi.*, 
             s.name as supplier_name,
             w.name as warehouse_name,
             u.name as created_by_name
      FROM purchase_invoices pi
      LEFT JOIN suppliers s ON pi.supplier_id = s.id
      LEFT JOIN warehouses w ON pi.warehouse_id = w.id
      LEFT JOIN users u ON pi.created_by = u.id
      WHERE $whereClause
      ORDER BY pi.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>?> getPurchaseInvoiceWithItems(int invoiceId) async {
    final db = await database;

    final invoice = await db.rawQuery('''
      SELECT pi.*, 
             s.name as supplier_name,
             w.name as warehouse_name,
             u.name as created_by_name
      FROM purchase_invoices pi
      LEFT JOIN suppliers s ON pi.supplier_id = s.id
      LEFT JOIN warehouses w ON pi.warehouse_id = w.id
      LEFT JOIN users u ON pi.created_by = u.id
      WHERE pi.id = ?
    ''', [invoiceId]);

    if (invoice.isEmpty) return null;

    final items = await db.rawQuery('''
      SELECT pi.*, 
             p.name as product_name,
             p.barcode,
             p.sell_price
      FROM purchase_items pi
      JOIN products p ON pi.product_id = p.id
      WHERE pi.purchase_invoice_id = ?
    ''', [invoiceId]);

    return {
      'invoice': invoice.first,
      'items': items,
    };
  }



  Future<Map<String, dynamic>> deletePurchaseInvoice(int invoiceId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'purchase_invoices',
        where: 'id = ? AND status = ?',
        whereArgs: [invoiceId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف الفاتورة بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف فاتورة معتمدة'};
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف الفاتورة: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> approvePurchaseInvoice(int invoiceId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // تحديث حالة الفاتورة
        await txn.update(
          'purchase_invoices',
          {
            'status': 'approved',
            'approved_by': 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
      });

      return {
        'success': true,
        'message': 'تم اعتماد الفاتورة بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد الفاتورة: ${e.toString()}'
      };
    }
  }

  // ========== دوال فواتير البيع ==========
  Future<List<Map<String, dynamic>>> getSaleInvoices({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
      SELECT si.*, 
             c.name as customer_name,
             w.name as warehouse_name,
             u.name as created_by_name
      FROM sale_invoices si
      LEFT JOIN customers c ON si.customer_id = c.id
      LEFT JOIN warehouses w ON si.warehouse_id = w.id
      LEFT JOIN users u ON si.created_by = u.id
      WHERE $whereClause
      ORDER BY si.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>?> getSaleInvoiceWithItems(int invoiceId) async {
    final db = await database;

    final invoice = await db.rawQuery('''
      SELECT si.*, 
             c.name as customer_name,
             w.name as warehouse_name,
             u.name as created_by_name
      FROM sale_invoices si
      LEFT JOIN customers c ON si.customer_id = c.id
      LEFT JOIN warehouses w ON si.warehouse_id = w.id
      LEFT JOIN users u ON si.created_by = u.id
      WHERE si.id = ?
    ''', [invoiceId]);

    if (invoice.isEmpty) return null;

    final items = await db.rawQuery('''
      SELECT si.*, 
             p.name as product_name,
             p.barcode,
             p.sell_price,
             p.purchase_price
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_invoice_id = ?
    ''', [invoiceId]);

    return {
      'invoice': invoice.first,
      'items': items,
    };
  }

  Future<Map<String, dynamic>> createSaleInvoiceWithItems(
      Map<String, dynamic> invoice,
      List<Map<String, dynamic>> items
      ) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. التحقق من رقم الفاتورة
        final invoiceNumber = invoice['invoice_number'] as String?;
        if (invoiceNumber == null || invoiceNumber.isEmpty) {
          throw Exception('رقم الفاتورة مطلوب');
        }

        // 2. حساب المبالغ
        double subTotal = 0;
        double totalCost = 0;

        for (final item in items) {
          final quantity = item['quantity'] as int;
          final unitPrice = item['unit_price'] as double;
          final costPrice = item['cost_price'] as double? ?? 0.0;

          subTotal += quantity * unitPrice;
          totalCost += quantity * costPrice;
        }

        // 3. حساب الخصم والضريبة
        final discountAmount = (invoice['discount_amount'] as double?) ?? 0.0;
        final taxPercent = (invoice['tax_percent'] as double?) ?? 0.0;
        final taxAmount = (subTotal - discountAmount) * (taxPercent / 100);
        final totalAmount = subTotal - discountAmount + taxAmount;
        final paidAmount = (invoice['paid_amount'] as double?) ?? 0.0;
        final remainingAmount = totalAmount - paidAmount;

        // 4. إدخال الفاتورة
        final invoiceId = await txn.insert('sale_invoices', {
          'invoice_number': invoiceNumber,
          'customer_id': invoice['customer_id'],
          'warehouse_id': invoice['warehouse_id'],
          'payment_method': invoice['payment_method'],
          'sub_total': subTotal,
          'discount_amount': discountAmount,
          'tax_percent': taxPercent,
          'tax_amount': taxAmount,
          'total_amount': totalAmount,
          'paid_amount': paidAmount,
          'remaining_amount': remainingAmount,
          'status': invoice['status'] ?? 'approved',
          'notes': invoice['notes'],
          'invoice_date': invoice['invoice_date'] ?? DateTime.now().toIso8601String(),
          'created_by': invoice['created_by'] ?? 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 5. إدخال البنود
        for (final item in items) {
          final quantity = item['quantity'] as int;
          final unitPrice = item['unit_price'] as double;
          final costPrice = item['cost_price'] as double? ?? 0.0;
          final productId = item['product_id'] as int;

          final totalPrice = quantity * unitPrice;
          final totalItemCost = quantity * costPrice;
          final profit = totalPrice - totalItemCost;

          await txn.insert('sale_items', {
            'sale_invoice_id': invoiceId,
            'product_id': productId,
            'quantity': quantity,
            'unit_price': unitPrice,
            'cost_price': costPrice,
            'total_price': totalPrice,
            'total_cost': totalItemCost,
            'profit': profit,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 6. تحديث مخزون المنتج (إذا الفاتورة معتمدة)
          if ((invoice['status'] as String? ?? 'approved') == 'approved') {
            await _updateProductStock(
                txn,
                productId,
                invoice['warehouse_id'] as int,
                quantity,
                false
            );
          }
        }

        // 7. تحديث رصيد العميل إذا كان البيع آجل
        if (invoice['customer_id'] != null &&
            (invoice['payment_method'] as String? ?? 'cash') == 'credit') {
          await _updateCustomerBalance(
              txn,
              invoice['customer_id'] as int,
              totalAmount,
              true
          );
        }

        // 8. تسجيل في سجل التدقيق
        await txn.insert('audit_log', {
          'user_id': invoice['created_by'] ?? 1,
          'action': 'CREATE_SALE_INVOICE',
          'table_name': 'sale_invoices',
          'record_id': invoiceId,
          'description': 'تم إنشاء فاتورة بيع رقم $invoiceNumber',
          'created_at': DateTime.now().toIso8601String(),
        });

        return {
          'success': true,
          'invoice_id': invoiceId,
          'invoice_number': invoiceNumber,
          'total_amount': totalAmount,
          'message': 'تم إنشاء الفاتورة بنجاح'
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء الفاتورة: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> approveSaleInvoice(int invoiceId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // جلب الفاتورة
        final invoice = await txn.query(
          'sale_invoices',
          where: 'id = ? AND status = ?',
          whereArgs: [invoiceId, 'draft'],
        );

        if (invoice.isEmpty) {
          throw Exception('الفاتورة غير موجودة أو غير قابلة للاعتماد');
        }

        // جلب بنود الفاتورة
        final items = await txn.query(
          'sale_items',
          where: 'sale_invoice_id = ?',
          whereArgs: [invoiceId],
        );

        final warehouseId = invoice.first['warehouse_id'];

        // التحقق من توفر الكميات في المخزون
        for (final item in items) {
          final stock = await txn.query(
            'warehouse_stock',
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [item['product_id'], warehouseId],
          );

          if (stock.isEmpty) {
            throw Exception('لا يوجد مخزون للمنتج: ${item['product_id']} في هذا المخزن');
          }

          final availableQty = stock.first['quantity'] as int;
          final requiredQty = item['quantity'] as int;

          if (availableQty < requiredQty) {
            throw Exception(
              'الكمية غير متوفرة للمنتج: ${item['product_id']} — المتاح: $availableQty — المطلوب: $requiredQty',
            );
          }
        }

        // خصم الكميات من المخزون
        for (final item in items) {
          await _updateProductStock(
              txn,
              item['product_id'] as int,
              warehouseId as int,
              item['quantity'] as int,
              false
          );
        }

        // تحديث حالة الفاتورة
        await txn.update(
          'sale_invoices',
          {
            'status': 'approved',
            'approved_by': 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // تسجيل العملية في سجل التدقيق
        await txn.insert(
          'audit_log',
          {
            'user_id': 1,
            'action': 'APPROVE_SALE_INVOICE',
            'table_name': 'sale_invoices',
            'record_id': invoiceId,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      });

      return {
        'success': true,
        'message': 'تم اعتماد الفاتورة بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد الفاتورة: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> deleteSaleInvoice(int invoiceId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'sale_invoices',
        where: 'id = ? AND status = ?',
        whereArgs: [invoiceId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف الفاتورة بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف فاتورة معتمدة'};
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف الفاتورة: ${e.toString()}'};
    }
  }

  // ========== دوال مرتجعات البيع ==========
  Future<List<Map<String, dynamic>>> getSalesReturns({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
      SELECT sr.*, 
             si.invoice_number as sale_invoice_number,
             c.name as customer_name,
             w.name as warehouse_name,
             u.name as created_by_name
      FROM sale_returns sr
      LEFT JOIN sale_invoices si ON sr.sale_invoice_id = si.id
      LEFT JOIN customers c ON sr.customer_id = c.id
      LEFT JOIN warehouses w ON sr.warehouse_id = w.id
      LEFT JOIN users u ON sr.created_by = u.id
      WHERE $whereClause
      ORDER BY sr.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>> createSalesReturnWithItems(
      Map<String, dynamic> salesReturn,
      List<Map<String, dynamic>> items
      ) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم المرتجع
        final returnNumber = 'SR${DateTime.now().millisecondsSinceEpoch}';

        // 2. إدخال المرتجع
        final returnId = await txn.insert('sale_returns', {
          ...salesReturn,
          'return_number': returnNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود
        double totalAmount = 0;
        for (final item in items) {
          final totalPrice = (item['quantity'] as int) * (item['unit_price'] as double);
          totalAmount += totalPrice;

          await txn.insert('sale_return_items', {
            ...item,
            'sale_return_id': returnId,
            'total_price': totalPrice,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث مخزون المنتج (زيادة لأنه مرتجع)
          await _updateProductStock(
              txn,
              item['product_id'] as int,
              salesReturn['warehouse_id'] as int,
              item['quantity'] as int,
              true
          );
        }

        // 5. تحديث المبلغ الإجمالي
        await txn.update(
          'sale_returns',
          {'total_amount': totalAmount},
          where: 'id = ?',
          whereArgs: [returnId],
        );

        return {
          'success': true,
          'return_id': returnId,
          'return_number': returnNumber,
          'total_amount': totalAmount,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء مرتجع البيع: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> deleteSalesReturn(int returnId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'sale_returns',
        where: 'id = ? AND status = ?',
        whereArgs: [returnId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف المرتجع بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف مرتجع معتمد'};
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف المرتجع: ${e.toString()}'};
    }
  }

  // ========== دوال مرتجعات الشراء ==========
  Future<List<Map<String, dynamic>>> getPurchaseReturns({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
      SELECT pr.*, 
             pi.invoice_number as purchase_invoice_number,
             s.name as supplier_name,
             w.name as warehouse_name,
             u.name as created_by_name
      FROM purchase_returns pr
      LEFT JOIN purchase_invoices pi ON pr.purchase_invoice_id = pi.id
      LEFT JOIN suppliers s ON pr.supplier_id = s.id
      LEFT JOIN warehouses w ON pr.warehouse_id = w.id
      LEFT JOIN users u ON pr.created_by = u.id
      WHERE $whereClause
      ORDER BY pr.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>> createPurchaseReturnWithItems(
      Map<String, dynamic> purchaseReturn,
      List<Map<String, dynamic>> items
      ) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم المرتجع
        final returnNumber = 'PR${DateTime.now().millisecondsSinceEpoch}';

        // 2. إدخال المرتجع
        final returnId = await txn.insert('purchase_returns', {
          ...purchaseReturn,
          'return_number': returnNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود
        double totalAmount = 0;
        for (final item in items) {
          final totalPrice = (item['quantity'] as int) * (item['unit_price'] as double);
          totalAmount += totalPrice;

          await txn.insert('purchase_return_items', {
            ...item,
            'purchase_return_id': returnId,
            'total_price': totalPrice,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث مخزون المنتج (نقصان لأنه مرتجع شراء)
          await _updateProductStock(
              txn,
              item['product_id'] as int,
              purchaseReturn['warehouse_id'] as int,
              item['quantity'] as int,
              false
          );
        }

        // 5. تحديث المبلغ الإجمالي
        await txn.update(
          'purchase_returns',
          {'total_amount': totalAmount},
          where: 'id = ?',
          whereArgs: [returnId],
        );

        return {
          'success': true,
          'return_id': returnId,
          'return_number': returnNumber,
          'total_amount': totalAmount,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء مرتجع الشراء: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> deletePurchaseReturn(int returnId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'purchase_returns',
        where: 'id = ? AND status = ?',
        whereArgs: [returnId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف المرتجع بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف مرتجع معتمد'};
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف المرتجع: ${e.toString()}'};
    }
  }

  // ========== دوال تحويلات المخزون ==========
  Future<List<Map<String, dynamic>>> getStockTransfers({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
      SELECT st.*, 
             w1.name as from_warehouse_name,
             w2.name as to_warehouse_name,
             u.name as created_by_name,
             COUNT(sti.id) as items_count
      FROM stock_transfers st
      LEFT JOIN warehouses w1 ON st.from_warehouse_id = w1.id
      LEFT JOIN warehouses w2 ON st.to_warehouse_id = w2.id
      LEFT JOIN users u ON st.created_by = u.id
      LEFT JOIN stock_transfer_items sti ON st.id = sti.stock_transfer_id
      WHERE $whereClause
      GROUP BY st.id
      ORDER BY st.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>> createStockTransferWithItems(
      Map<String, dynamic> transfer,
      List<Map<String, dynamic>> items
      ) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم التحويل
        final transferNumber = 'TR${DateTime.now().millisecondsSinceEpoch}';

        // 2. إدخال التحويل
        final transferId = await txn.insert('stock_transfers', {
          ...transfer,
          'transfer_number': transferNumber,
          'total_items': items.length,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود وتحديث المخزون
        for (final item in items) {
          await txn.insert('stock_transfer_items', {
            ...item,
            'stock_transfer_id': transferId,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث مخزون المنتج في المخزن المصدر (نقصان)
          await _updateProductStock(
              txn,
              item['product_id'] as int,
              transfer['from_warehouse_id'] as int,
              item['quantity'] as int,
              false
          );

          // 5. تحديث مخزون المنتج في المخزن الهدف (زيادة)
          await _updateProductStock(
              txn,
              item['product_id'] as int,
              transfer['to_warehouse_id'] as int,
              item['quantity'] as int,
              true
          );
        }

        return {
          'success': true,
          'transfer_id': transferId,
          'transfer_number': transferNumber,
          'total_items': items.length,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء تحويل المخزون: ${e.toString()}'
      };
    }
  }

  // ========== دوال تعديلات الجرد ==========
  Future<List<Map<String, dynamic>>> getInventoryAdjustments({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
      SELECT ia.*, 
             w.name as warehouse_name,
             u.name as created_by_name,
             COUNT(ai.id) as items_count
      FROM inventory_adjustments ia
      LEFT JOIN warehouses w ON ia.warehouse_id = w.id
      LEFT JOIN users u ON ia.created_by = u.id
      LEFT JOIN adjustment_items ai ON ia.id = ai.adjustment_id
      WHERE $whereClause
      GROUP BY ia.id
      ORDER BY ia.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>> createInventoryAdjustmentWithItems(
      Map<String, dynamic> adjustment,
      List<Map<String, dynamic>> items,
      ) async {
    final Database db = await database;

    try {
      return await db.transaction((txn) async {
        // 1. إنشاء رقم التعديل
        final String adjustmentNumber = 'ADJ${DateTime.now().millisecondsSinceEpoch}';

        // 2. إدخال التعديل الرئيسي
        final int adjustmentId = await txn.insert(
          'inventory_adjustments',
          {
            ...adjustment,
            'adjustment_number': adjustmentNumber,
            'total_items': items.length,
            'created_at': DateTime.now().toIso8601String(),
          },
        );

        // 3. إدخال البنود + تحديث المخزون
        for (final Map<String, dynamic> item in items) {
          await txn.insert(
            'adjustment_items',
            {
              ...item,
              'adjustment_id': adjustmentId,
              'created_at': DateTime.now().toIso8601String(),
            },
          );

          // 4. تحديث مخزون المنتج
          await _updateProductStockForAdjustment(
            txn,
            item['product_id'] as int,
            adjustment['warehouse_id'] as int,
            item['new_quantity'] as int,
          );
        }

        return {
          'success': true,
          'adjustment_id': adjustmentId,
          'adjustment_number': adjustmentNumber,
          'total_items': items.length,
        };
      });
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء تعديل الجرد: $e',
      };
    }
  }

  // ========== دوال سندات القبض ==========
  Future<List<Map<String, dynamic>>> getReceiptVouchers({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date(payment_date) BETWEEN ? AND ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await db.rawQuery('''
      SELECT rv.*, 
             c.name as customer_name,
             u.name as created_by_name
      FROM receipt_vouchers rv
      LEFT JOIN customers c ON rv.customer_id = c.id
      LEFT JOIN users u ON rv.created_by = u.id
      WHERE $whereClause
      ORDER BY rv.payment_date DESC, rv.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>> createReceiptVoucher(Map<String, dynamic> voucher) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم السند
        final voucherNumber = 'RCV${DateTime.now().millisecondsSinceEpoch}';

        // 2. إدخال السند
        final voucherId = await txn.insert('receipt_vouchers', {
          ...voucher,
          'voucher_number': voucherNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. تحديث رصيد العميل (تخفيض المدين)
        if (voucher['customer_id'] != null) {
          await _updateCustomerBalance(
              txn,
              voucher['customer_id'] as int,
              voucher['amount'] as double,
              false
          );
        }

        // 4. تسجيل في سجل الصندوق
        await _addCashLedgerEntry(
          txn,
          'receipt',
          voucher['amount'] as double,
          'سند قبض - $voucherNumber',
          'receipt_voucher',
          voucherId,
        );

        return {
          'success': true,
          'voucher_id': voucherId,
          'voucher_number': voucherNumber,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء سند القبض: ${e.toString()}'
      };
    }
  }

  // ========== دوال سندات الصرف ==========
  Future<List<Map<String, dynamic>>> getPaymentVouchers({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date(payment_date) BETWEEN ? AND ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await db.rawQuery('''
      SELECT pv.*, 
             s.name as supplier_name,
             u.name as created_by_name
      FROM payment_vouchers pv
      LEFT JOIN suppliers s ON pv.supplier_id = s.id
      LEFT JOIN users u ON pv.created_by = u.id
      WHERE $whereClause
      ORDER BY pv.payment_date DESC, pv.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>> createPaymentVoucher(Map<String, dynamic> voucher) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم السند
        final voucherNumber = 'PAY${DateTime.now().millisecondsSinceEpoch}';

        // 2. إدخال السند
        final voucherId = await txn.insert('payment_vouchers', {
          ...voucher,
          'voucher_number': voucherNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. تحديث رصيد المورد (تخفيض الدائن)
        if (voucher['supplier_id'] != null) {
          await _updateSupplierBalance(
              txn,
              voucher['supplier_id'] as int,
              voucher['amount'] as double,
              false
          );
        }

        // 4. تسجيل في سجل الصندوق
        await _addCashLedgerEntry(
          txn,
          'payment',
          voucher['amount'] as double,
          'سند صرف - $voucherNumber',
          'payment_voucher',
          voucherId,
        );

        return {
          'success': true,
          'voucher_id': voucherId,
          'voucher_number': voucherNumber,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء سند الصرف: ${e.toString()}'
      };
    }
  }

  // ========== دوال سجل الصندوق ==========
  Future<List<Map<String, dynamic>>> getCashLedger({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date(transaction_date) BETWEEN ? AND ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await db.rawQuery('''
      SELECT cl.*, u.name as created_by_name
      FROM cash_ledger cl
      LEFT JOIN users u ON cl.created_by = u.id
      WHERE $whereClause
      ORDER BY cl.transaction_date DESC, cl.created_at DESC
    ''', whereArgs);
  }

  Future<double> getCurrentCashBalance() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT balance_after FROM cash_ledger 
      ORDER BY id DESC LIMIT 1
    ''');

    if (result.isNotEmpty) {
      return result.first['balance_after'] as double;
    }

    return 0;
  }

  // ========== دوال المعاملات ==========
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    return await db.insert('transactions', {
      ...transaction,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, 
             p.name as product_name,
             c.name as customer_name,
             s.name as supplier_name
      FROM transactions t
      LEFT JOIN products p ON t.product_id = p.id
      LEFT JOIN customers c ON t.customer_id = c.id
      LEFT JOIN suppliers s ON t.supplier_id = s.id
      ORDER BY t.date DESC
      LIMIT 100
    ''');
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== دوال حركات المنتجات ==========
  Future<List<Map<String, dynamic>>> getProductMovements(int productId) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        pm.*,
        s.name as supplier_name,
        DATE(pm.created_at) as date
      FROM product_movements pm
      LEFT JOIN suppliers s ON pm.supplier_id = s.id
      WHERE pm.product_id = ?
      ORDER BY pm.created_at DESC
    ''', [productId]);
  }

  // ========== دوال التنبيهات ==========
  Future<List<Map<String, dynamic>>> getAlerts({bool? unreadOnly}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (unreadOnly == true) {
      whereClause += ' AND is_read = 0';
    }

    return await db.rawQuery('''
      SELECT * FROM alerts
      WHERE $whereClause
      ORDER BY 
        CASE priority 
          WHEN 'critical' THEN 1
          WHEN 'high' THEN 2
          WHEN 'medium' THEN 3
          WHEN 'low' THEN 4
        END,
        created_at DESC
    ''', whereArgs);
  }

  Future<int> markAlertAsRead(int alertId) async {
    final db = await database;
    return await db.update(
      'alerts',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  // ========== دوال التقارير ==========
  Future<List<Map<String, dynamic>>> getMonthlySalesReport(int year) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        strftime('%m', invoice_date) as month,
        COUNT(*) as invoices_count,
        SUM(total_amount) as total_sales,
        SUM(paid_amount) as total_paid,
        AVG(total_amount) as avg_sale,
        MAX(total_amount) as max_sale,
        MIN(total_amount) as min_sale
      FROM sale_invoices 
      WHERE status = 'approved' 
        AND strftime('%Y', invoice_date) = ?
      GROUP BY strftime('%m', invoice_date)
      ORDER BY month ASC
    ''', [year.toString()]);
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10, String period = 'month'}) async {
    final db = await database;

    String dateFilter = '';
    switch (period) {
      case 'day':
        dateFilter = "AND date(si.invoice_date) = date('now')";
        break;
      case 'week':
        dateFilter = "AND date(si.invoice_date) >= date('now', '-7 days')";
        break;
      case 'month':
        dateFilter = "AND strftime('%Y-%m', si.invoice_date) = strftime('%Y-%m', 'now')";
        break;
      case 'year':
        dateFilter = "AND strftime('%Y', si.invoice_date) = strftime('%Y', 'now')";
        break;
    }

    return await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.barcode,
        c.name as category_name,
        SUM(si.quantity) as total_sold,
        SUM(si.total_price) as total_revenue,
        AVG(si.unit_price) as avg_price,
        COUNT(DISTINCT si.sale_invoice_id) as invoices_count
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      JOIN sale_invoices s ON si.sale_invoice_id = s.id
      WHERE s.status = 'approved'
        $dateFilter
      GROUP BY p.id
      ORDER BY total_sold DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getInventoryReport() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.barcode,
        c.name as category_name,
        p.purchase_price,
        p.sell_price,
        p.cost_price,
        SUM(ws.quantity) as total_stock,
        COUNT(DISTINCT ws.warehouse_id) as warehouses_count,
        (p.sell_price - p.cost_price) as profit_margin,
        (p.sell_price - p.cost_price) / p.cost_price * 100 as profit_percentage
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
      WHERE p.is_active = 1
      GROUP BY p.id
      ORDER BY total_stock DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold = 10}) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.barcode,
        c.name as category_name,
        p.min_stock_level,
        SUM(ws.quantity) as total_stock,
        GROUP_CONCAT(w.name) as warehouse_names
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
      LEFT JOIN warehouses w ON ws.warehouse_id = w.id
      WHERE p.is_active = 1 
        AND p.min_stock_level > 0
      GROUP BY p.id
      HAVING total_stock <= p.min_stock_level OR total_stock <= ?
      ORDER BY total_stock ASC
    ''', [threshold]);
  }

  Future<Map<String, dynamic>> getProfitReport(DateTime startDate, DateTime endDate) async {
    final db = await database;

    // إحصائيات المبيعات
    final salesStats = await db.rawQuery('''
      SELECT
        COUNT(*) as total_invoices,
        SUM(total_amount) as total_sales,
        SUM(paid_amount) as total_paid,
        SUM(discount_amount) as total_discount,
        AVG(total_amount) as avg_sale
      FROM sale_invoices
      WHERE status = 'approved'
        AND date(invoice_date) BETWEEN ? AND ?
    ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // إحصائيات المشتريات
    final purchaseStats = await db.rawQuery('''
      SELECT
        COUNT(*) as total_invoices,
        SUM(total_amount) as total_purchases,
        SUM(paid_amount) as total_paid
      FROM purchase_invoices
      WHERE status = 'approved'
        AND date(invoice_date) BETWEEN ? AND ?
    ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // حساب الأرباح من بنود المبيعات
    final profitStats = await db.rawQuery('''
      SELECT
        SUM(si.quantity * (si.unit_price - si.cost_price)) as total_profit,
        SUM(si.quantity * si.unit_price) as total_revenue,
        SUM(si.quantity * si.cost_price) as total_cost,
        COUNT(DISTINCT si.sale_invoice_id) as invoices_count
      FROM sale_items si
      JOIN sale_invoices s ON si.sale_invoice_id = s.id
      WHERE s.status = 'approved'
        AND date(s.invoice_date) BETWEEN ? AND ?
    ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    return {
      'sales_stats': salesStats.isNotEmpty ? salesStats.first : {},
      'purchase_stats': purchaseStats.isNotEmpty ? purchaseStats.first : {},
      'profit_stats': profitStats.isNotEmpty ? profitStats.first : {},
    };
  }

  // ========== دوال مساعدة داخلية ==========
  Future<void> _updateProductStock(
      DatabaseExecutor txn,
      int productId,
      int warehouseId,
      int quantity,
      bool isIncrease
      ) async {
    final stock = await txn.query(
      'warehouse_stock',
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
    );

    if (stock.isNotEmpty) {
      final currentQty = stock.first['quantity'] as int;
      final newQty = isIncrease ? currentQty + quantity : currentQty - quantity;

      await txn.update(
        'warehouse_stock',
        {
          'quantity': newQty,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId],
      );
    }
  }

  Future<void> _updateProductStockForAdjustment(
      DatabaseExecutor txn,
      int productId,
      int warehouseId,
      int newQuantity
      ) async {
    final stock = await txn.query(
      'warehouse_stock',
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
    );

    if (stock.isNotEmpty) {
      await txn.update(
        'warehouse_stock',
        {
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId],
      );
    } else {
      await txn.insert('warehouse_stock', {
        'warehouse_id': warehouseId,
        'product_id': productId,
        'quantity': newQuantity,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _updateCustomerBalance(
      DatabaseExecutor txn,
      int customerId,
      double amount,
      bool isIncrease
      ) async {
    final customer = await txn.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
    );

    if (customer.isNotEmpty) {
      final currentBalance = customer.first['balance'] as double;
      final newBalance = isIncrease ? currentBalance + amount : currentBalance - amount;

      await txn.update(
        'customers',
        {
          'balance': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );
    }
  }

  Future<void> _updateSupplierBalance(
      DatabaseExecutor txn,
      int supplierId,
      double amount,
      bool isIncrease
      ) async {
    final supplier = await txn.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [supplierId],
    );

    if (supplier.isNotEmpty) {
      final currentBalance = supplier.first['balance'] as double;
      final newBalance = isIncrease ? currentBalance + amount : currentBalance - amount;

      await txn.update(
        'suppliers',
        {
          'balance': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [supplierId],
      );
    }
  }

  Future<void> _addCashLedgerEntry(
      DatabaseExecutor txn,
      String transactionType,
      double amount,
      String description,
      String referenceType,
      int referenceId,
      ) async {
    // الحصول على آخر رصيد
    final lastBalance = await txn.rawQuery('''
      SELECT balance_after FROM cash_ledger 
      ORDER BY id DESC LIMIT 1
    ''');

    double currentBalance = 0;
    if (lastBalance.isNotEmpty) {
      currentBalance = lastBalance.first['balance_after'] as double;
    }

    double newBalance = currentBalance;
    if (transactionType == 'receipt') {
      newBalance = currentBalance + amount;
    } else if (transactionType == 'payment') {
      newBalance = currentBalance - amount;
    }

    await txn.insert('cash_ledger', {
      'transaction_type': transactionType,
      'amount': amount,
      'balance_after': newBalance,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'transaction_date': DateTime.now().toIso8601String(),
      'created_by': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ========== دوال إضافية ==========
  Future<Map<String, dynamic>> getWarehouseStockSummary(int warehouseId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_products,
        SUM(ws.quantity) as total_quantity,
        SUM(ws.quantity * p.sell_price) as total_value,
        SUM(CASE WHEN ws.quantity <= p.min_stock_level AND ws.quantity > 0 THEN 1 ELSE 0 END) as low_stock_products,
        SUM(CASE WHEN ws.quantity = 0 THEN 1 ELSE 0 END) as out_of_stock_products
      FROM warehouse_stock ws
      JOIN products p ON ws.product_id = p.id
      WHERE ws.warehouse_id = ?
    ''', [warehouseId]);

    return result.isNotEmpty ? result.first : {};
  }

  Future<List<Map<String, dynamic>>> getWarehouseStock(int warehouseId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        ws.*,
        p.name as product_name,
        p.barcode,
        p.sell_price,
        p.min_stock_level
      FROM warehouse_stock ws
      JOIN products p ON ws.product_id = p.id
      WHERE ws.warehouse_id = ?
      ORDER BY p.name ASC
    ''', [warehouseId]);
  }

  Future<Map<String, dynamic>?> getCustomerDetails(int customerId) async {
    final db = await database;

    try {
      final result = await db.rawQuery('''
        SELECT 
          c.*,
          (SELECT COUNT(*) FROM sale_invoices 
           WHERE customer_id = ? AND status = 'approved') as total_invoices,
          (SELECT COALESCE(SUM(total_amount), 0) FROM sale_invoices 
           WHERE customer_id = ? AND status = 'approved') as total_purchases,
          (SELECT MAX(invoice_date) FROM sale_invoices 
           WHERE customer_id = ? AND status = 'approved') as last_purchase_date
        FROM customers c
        WHERE c.id = ? AND c.is_active = 1
      ''', [customerId, customerId, customerId, customerId]);

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSuppliersSummary() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        s.id,
        s.name,
        s.phone,
        s.balance,
        COUNT(pi.id) as total_invoices,
        COALESCE(SUM(pi.total_amount), 0) as total_purchases,
        COALESCE(SUM(pi.paid_amount), 0) as total_paid,
        MAX(pi.invoice_date) as last_purchase_date,
        (
          SELECT COUNT(DISTINCT product_id) 
          FROM purchase_items 
          WHERE purchase_invoice_id IN (
            SELECT id FROM purchase_invoices WHERE supplier_id = s.id
          )
        ) as unique_products,
        (
          SELECT COALESCE(SUM(si.quantity * (si.unit_price - si.cost_price)), 0)
          FROM sale_items si
          JOIN sale_invoices sinv ON si.sale_invoice_id = sinv.id
          JOIN products p ON si.product_id = p.id
          WHERE p.id IN (
            SELECT product_id FROM purchase_items WHERE purchase_invoice_id IN (
              SELECT id FROM purchase_invoices WHERE supplier_id = s.id
            )
          )
          AND sinv.status = 'approved'
        ) as generated_profit
      FROM suppliers s
      LEFT JOIN purchase_invoices pi ON s.id = pi.supplier_id AND pi.status = 'approved'
      WHERE s.is_active = 1
      GROUP BY s.id
      ORDER BY total_purchases DESC
    ''');
  }

  Future<void> updateProductQuantity(
      int productId,
      int quantity,
      String movementType, {
        int? warehouseId,
        String? notes,
      }) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. تحديث جدول المنتجات
      final product = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (product.isNotEmpty) {
        final currentQty = product.first['current_quantity'] as int;
        final newQty = movementType == 'return'
            ? currentQty + quantity  // زيادة للمرتجع
            : currentQty - quantity; // نقصان للبيع

        await txn.update(
          'products',
          {
            'current_quantity': newQty,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      // 2. تحديث مخزون المخزن (إذا تم تحديد مخزن)
      if (warehouseId != null) {
        final warehouseStock = await txn.query(
          'warehouse_stock',
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [productId, warehouseId],
        );

        if (warehouseStock.isNotEmpty) {
          final currentStock = warehouseStock.first['quantity'] as int;
          final newStock = movementType == 'return'
              ? currentStock + quantity  // زيادة للمرتجع
              : currentStock - quantity; // نقصان للبيع

          await txn.update(
            'warehouse_stock',
            {
              'quantity': newStock,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [productId, warehouseId],
          );
        }
      }

      // 3. تسجيل الحركة
      await txn.insert('product_movements', {
        'product_id': productId,
        'movement_type': movementType,
        'quantity': movementType == 'return' ? quantity : -quantity,
        'notes': notes ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> addSaleToCashLedger(
      double amount,
      String referenceNumber,
      int referenceId, {
        bool isReturn = false,
      }) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        final transactionType = isReturn ? 'payment' : 'receipt';
        final description = isReturn
            ? 'مرتجع بيع #$referenceNumber'
            : 'فاتورة بيع #$referenceNumber';

        await _addCashLedgerEntry(
          txn,
          transactionType,
          amount,
          description,
          isReturn ? 'sale_return' : 'sale_invoice',
          referenceId,
        );
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}