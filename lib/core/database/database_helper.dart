import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'uohs_student.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. جدول الإشعارات المحلية
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        is_received INTEGER DEFAULT 0,
        type TEXT DEFAULT 'general'
      )
    ''');

    // 2. جدول الفواتير المحلية (نسخة من بيانات السيرفر)
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT,
        title TEXT,
        total_amount REAL,
        status TEXT,
        rejection_note TEXT,
        created_at TEXT
      )
    ''');

    // 3. جدول البيانات العامة كـ Key-Value (الملخص المالي والملف الشخصي)
    await db.execute('''
      CREATE TABLE cached_data (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ─── دوال جدول الإشعارات (Notifications) ──────────────────────────────────

  Future<int> insertNotification(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'notifications',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final db = await database;
    return await db.query('notifications', orderBy: 'created_at DESC');
  }

  Future<int> markNotificationAsRead(String id) async {
    final db = await database;
    return await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllNotificationsAsRead() async {
    final db = await database;
    return await db.update(
      'notifications',
      {'is_read': 1},
    );
  }

  Future<int> clearNotifications() async {
    final db = await database;
    return await db.delete('notifications');
  }

  // ─── دوال جدول الفواتير (Invoices Cache) ──────────────────────────────────

  Future<void> saveInvoices(List<dynamic> fetchedInvoices) async {
    final db = await database;
    final batch = db.batch();
    
    // مسح الفواتير القديمة قبل الحفظ الجديد لضمان التطابق
    batch.delete('invoices');
    
    for (var inv in fetchedInvoices) {
      batch.insert('invoices', {
        'id': inv['id'].toString(),
        'invoice_number': inv['invoice_number'] ?? '',
        'title': inv['title'] ?? '',
        'total_amount': double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0.0,
        'status': inv['status'] ?? '',
        'rejection_note': inv['rejection_note'] ?? '',
        'created_at': inv['created_at'] ?? '',
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final db = await database;
    return await db.query('invoices');
  }

  // ─── دوال جدول البيانات العامة (Cached Data Store) ─────────────────────────

  Future<int> saveCache(String key, String value) async {
    final db = await database;
    return await db.insert(
      'cached_data',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCache(String key) async {
    final db = await database;
    final maps = await db.query(
      'cached_data',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future<int> removeCache(String key) async {
    final db = await database;
    return await db.delete(
      'cached_data',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<void> clearAllCache() async {
    final db = await database;
    final batch = db.batch();
    batch.delete('notifications');
    batch.delete('invoices');
    batch.delete('cached_data');
    await batch.commit(noResult: true);
  }
}
