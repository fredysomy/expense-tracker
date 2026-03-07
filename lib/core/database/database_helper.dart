import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const _uuid = Uuid();

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'money_manager.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE categories ADD COLUMN parent_id TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'INR',
        balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        parent_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        account_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        tags TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        limit_amount REAL NOT NULL,
        period TEXT NOT NULL,
        start_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_categories (
        budget_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        PRIMARY KEY (budget_id, category_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_accounts (
        budget_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        PRIMARY KEY (budget_id, account_id)
      )
    ''');

    await _seedDefaultCategories(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    // Helper to insert parent + children
    Future<String> addParent(String name, String type, String icon) async {
      final id = _uuid.v4();
      await db.insert('categories',
          {'id': id, 'name': name, 'type': type, 'icon': icon, 'parent_id': null});
      return id;
    }

    Future<void> addChild(
        String parentId, String name, String type, String icon) async {
      await db.insert('categories', {
        'id': _uuid.v4(),
        'name': name,
        'type': type,
        'icon': icon,
        'parent_id': parentId,
      });
    }

    // --- EXPENSE ---
    final foodId = await addParent('Food & Drinks', 'expense', 'restaurant');
    await addChild(foodId, 'Restaurant', 'expense', 'restaurant');
    await addChild(foodId, 'Food Delivery', 'expense', 'delivery_dining');
    await addChild(foodId, 'Groceries', 'expense', 'shopping_cart');
    await addChild(foodId, 'Coffee & Tea', 'expense', 'coffee');

    final transportId = await addParent('Transport', 'expense', 'directions_car');
    await addChild(transportId, 'Fuel', 'expense', 'local_gas_station');
    await addChild(transportId, 'Auto / Rickshaw', 'expense', 'two_wheeler');
    await addChild(transportId, 'Taxi / Cab', 'expense', 'local_taxi');
    await addChild(transportId, 'Public Transport', 'expense', 'directions_bus');

    final shoppingId = await addParent('Shopping', 'expense', 'shopping_bag');
    await addChild(shoppingId, 'Clothing', 'expense', 'checkroom');
    await addChild(shoppingId, 'Electronics', 'expense', 'phone_android');
    await addChild(shoppingId, 'Online Shopping', 'expense', 'shopping_bag');

    final billsId = await addParent('Bills', 'expense', 'receipt_long');
    await addChild(billsId, 'Electricity', 'expense', 'bolt');
    await addChild(billsId, 'Internet', 'expense', 'wifi');
    await addChild(billsId, 'Mobile Recharge', 'expense', 'phone');
    await addChild(billsId, 'Rent', 'expense', 'home');

    final entId = await addParent('Entertainment', 'expense', 'movie');
    await addChild(entId, 'Movies', 'expense', 'movie');
    await addChild(entId, 'Subscriptions', 'expense', 'subscriptions');
    await addChild(entId, 'Gaming', 'expense', 'sports_esports');

    final healthId = await addParent('Health', 'expense', 'local_hospital');
    await addChild(healthId, 'Medicine', 'expense', 'medication');
    await addChild(healthId, 'Doctor', 'expense', 'medical_services');
    await addChild(healthId, 'Gym', 'expense', 'fitness_center');

    final travelId = await addParent('Travel', 'expense', 'flight');
    await addChild(travelId, 'Flights', 'expense', 'flight');
    await addChild(travelId, 'Hotels', 'expense', 'hotel');
    await addChild(travelId, 'Luggage / Misc', 'expense', 'luggage');

    await addParent('EMI', 'expense', 'credit_card');
    await addParent('Education', 'expense', 'school');
    await addParent('Other', 'expense', 'more_horiz');

    // --- INCOME ---
    final salaryId = await addParent('Salary', 'income', 'account_balance_wallet');
    await addChild(salaryId, 'Monthly Salary', 'income', 'account_balance_wallet');
    await addChild(salaryId, 'Bonus', 'income', 'stars');

    final freelanceId = await addParent('Freelance', 'income', 'work');
    await addChild(freelanceId, 'Project Payment', 'income', 'work');
    await addChild(freelanceId, 'Consulting', 'income', 'business_center');

    final investId = await addParent('Investment', 'income', 'savings');
    await addChild(investId, 'Dividends', 'income', 'trending_up');
    await addChild(investId, 'Returns', 'income', 'trending_up');

    await addParent('Refund', 'income', 'replay');
    await addParent('Other Income', 'income', 'attach_money');
  }
}
