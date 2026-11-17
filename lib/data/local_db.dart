


import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/aes_helper.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static Database? _database;

  @visibleForTesting
  static bool forceWebStoreForTest = false;

  static final _WebMemoryStore _webStore = _WebMemoryStore();

  bool get _useWebStore => (kIsWeb || forceWebStoreForTest) && _database == null;

  @visibleForTesting
  static void setDatabaseForTest(Database? db) {
    _database = db;
  }

  @visibleForTesting
  static void resetWebStoreForTest() {
    _webStore.reset();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'asuhkita_offline.db');

    final db = await openDatabase(
      path,
      version: 9,
      onCreate: (db, version) async {
        await _createTables(db);
        await _runAlterMigrations(db);
        await _seedDefaultAuthUsers(db);
        await clearDummyChildren(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        await _runAlterMigrations(db);
        await _seedDefaultAuthUsers(db);
        await clearDummyChildren(db);
      },
      onOpen: (db) async {
        await _runAlterMigrations(db);
      },
    );
    await clearDummyChildren(db);
    return db;
  }

  Future<void> _runAlterMigrations(Database db) async {
    const migrations = [
      'ALTER TABLE cached_donations ADD COLUMN donor_name TEXT',
      'ALTER TABLE cached_donations ADD COLUMN need_category TEXT',
      'ALTER TABLE cached_donations ADD COLUMN donor_email TEXT',
      'ALTER TABLE cached_donations ADD COLUMN child_id TEXT',
      'ALTER TABLE cached_donations ADD COLUMN child_avatar TEXT',
      'ALTER TABLE cached_donations ADD COLUMN child_city TEXT',
      'ALTER TABLE cached_donations ADD COLUMN certificate_code TEXT',
      'ALTER TABLE cached_donations ADD COLUMN block_hash TEXT',
      'ALTER TABLE cached_children ADD COLUMN dream TEXT',
      'ALTER TABLE cached_children ADD COLUMN hobby TEXT',
      'ALTER TABLE cached_children ADD COLUMN target REAL',
      'ALTER TABLE cached_children ADD COLUMN category_budgets TEXT',
      'ALTER TABLE cached_children ADD COLUMN daily_status TEXT',
      'ALTER TABLE cached_children ADD COLUMN birth_date TEXT',
      'ALTER TABLE new_children ADD COLUMN category_budgets TEXT',
      'ALTER TABLE new_children ADD COLUMN daily_status TEXT',
      'ALTER TABLE new_children ADD COLUMN birth_date TEXT',
      'ALTER TABLE cached_progress_reports ADD COLUMN daily_status TEXT',
      'ALTER TABLE offline_donations_queue ADD COLUMN local_id TEXT',
      'ALTER TABLE offline_donations_queue ADD COLUMN package_name TEXT',
      'ALTER TABLE offline_donations_queue ADD COLUMN donor_name TEXT',
      'ALTER TABLE offline_donations_queue ADD COLUMN donor_email TEXT',
      'ALTER TABLE offline_donations_queue ADD COLUMN notes TEXT',
    ];
    for (final sql in migrations) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  }

  Future<void> _createTables(Database db) async {

    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_users (
        email TEXT PRIMARY KEY,
        password_hash TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        phone TEXT,
        created_at TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_children (
        id TEXT PRIMARY KEY,
        orphanage_id TEXT,
        alias TEXT,
        age INTEGER,
        need_category TEXT,
        story_summary TEXT,
        avatar TEXT,
        status TEXT,
        orphanage_name TEXT,
        orphanage_city TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_donations (
        id TEXT PRIMARY KEY,
        sponsorship_id TEXT,
        child_alias TEXT,
        amount_original REAL,
        currency TEXT,
        rate_used REAL,
        amount_idr REAL,
        created_at TEXT,
        status TEXT,
        donor_name TEXT,
        donor_email TEXT,
        need_category TEXT,
        certificate_code TEXT,
        block_hash TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_donations_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id TEXT,
        package_id TEXT,
        amount_original REAL,
        currency TEXT,
        rate_used REAL,
        amount_idr REAL,
        frequency TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0,
        local_id TEXT,
        package_name TEXT,
        donor_name TEXT,
        donor_email TEXT,
        notes TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone_encrypted TEXT,
        email TEXT,
        photo_url TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipts (
        id TEXT PRIMARY KEY,
        child_name TEXT,
        title TEXT,
        amount REAL,
        date TEXT,
        receipt_image TEXT,
        description TEXT,
        hash TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS feedback_entries (
        id TEXT PRIMARY KEY,
        user_email TEXT,
        user_name TEXT,
        rating INTEGER,
        category TEXT,
        message TEXT,
        created_at TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS new_children (
        id TEXT PRIMARY KEY,
        name TEXT,
        age INTEGER,
        gender TEXT,
        city TEXT,
        urgent_needs TEXT,
        story TEXT,
        photo TEXT,
        target REAL,
        dream TEXT,
        hobby TEXT,
        created_at TEXT,
        category_budgets TEXT
      )
    ''');


    try {
      await db.execute('ALTER TABLE new_children ADD COLUMN category_budgets TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE new_children ADD COLUMN daily_status TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE new_children ADD COLUMN birth_date TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_children ADD COLUMN daily_status TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_children ADD COLUMN birth_date TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_children ADD COLUMN dream TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_children ADD COLUMN hobby TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_children ADD COLUMN target REAL');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_children ADD COLUMN category_budgets TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN donor_name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN need_category TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN donor_email TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN child_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN child_avatar TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN child_city TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN certificate_code TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cached_donations ADD COLUMN block_hash TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE offline_donations_queue ADD COLUMN local_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE offline_donations_queue ADD COLUMN package_name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE offline_donations_queue ADD COLUMN donor_name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE offline_donations_queue ADD COLUMN donor_email TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE offline_donations_queue ADD COLUMN notes TEXT');
    } catch (_) {}


    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_alias TEXT NOT NULL,
        sender TEXT NOT NULL,
        text TEXT,
        type TEXT DEFAULT 'text',
        file_url TEXT,
        time TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_progress_reports (
        id TEXT PRIMARY KEY,
        child_id TEXT,
        child_alias TEXT,
        title TEXT,
        category TEXT,
        period TEXT,
        summary TEXT,
        evidence_url TEXT,
        author_name TEXT,
        daily_status TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_wishlists (
        id TEXT PRIMARY KEY,
        child_id TEXT,
        child_alias TEXT,
        item_name TEXT,
        estimated_idr REAL,
        status TEXT,
        funded_by_user_id TEXT,
        funded_by_name TEXT,
        receipt_url TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_schedules (
        id TEXT PRIMARY KEY,
        sponsorship_id TEXT,
        child_id TEXT,
        child_alias TEXT,
        donor_name TEXT,
        scheduled_at_utc TEXT,
        donor_timezone TEXT,
        status TEXT,
        notes TEXT,
        admin_notes TEXT,
        created_at TEXT
      )
    ''');
  }


  static String hashPassword(String password) {
    const salt = 'asuhkita_secure_salt_2026_xyz';
    final bytes = utf8.encode('$salt$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> _seedDefaultAuthUsers(Database db) async {

    await db.insert(
      'auth_users',
      {
        'email': 'donatur@asuhkita.id',
        'password_hash': hashPassword('donatur123'),
        'name': 'Donatur Asuh',
        'role': 'donatur',
        'phone': '081234567890',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );


    await db.insert(
      'auth_users',
      {
        'email': 'admin@asuhkita.id',
        'password_hash': hashPassword('admin123!'),
        'name': 'Admin Pengurus Panti',
        'role': 'admin_panti',
        'phone': '081987654321',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  static const List<String> _dummyChildNames = [
    'Arfa Pratama', 'Ayra Humaira', 'Bintang Ramadhan', 'Citra Kirana', 'Dimas Anggara',
    'Elsa Safitri', 'Fahri Ramdani', 'Gita Gutawa', 'Hafiz Al-Fatih', 'Intan Permata',
    'Joko Susilo', 'Khadijah Az-Zahra', 'Luki Hermawan', 'Manda Cantika', 'Noval Kurniawan',
    'Olivia Zahrani', 'Putra Perkasa', 'Qiana Azzahra', 'Rafi Ahmad Fauzi', 'Siti Nurhaliza'
  ];

  Map<String, dynamic> _normalizeAuthUserRow({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
  }) {
    return {
      'email': email.toLowerCase().trim(),
      'password_hash': hashPassword(password),
      'name': name.trim(),
      'role': role,
      'phone': phone.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic>? _matchAuthUserRow(
    Map<String, dynamic>? user,
    String cleanEmail,
    String password,
  ) {
    if (user == null) return null;
    final storedHash = user['password_hash']?.toString() ?? '';
    if (storedHash != hashPassword(password)) return null;
    return {
      'id': 'usr_${user['email'].hashCode.abs()}',
      'name': user['name']?.toString() ?? cleanEmail.split('@').first,
      'email': cleanEmail,
      'role': user['role']?.toString() ?? (cleanEmail.contains('admin') ? 'admin_panti' : 'donatur'),
      'phone': user['phone']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _normalizeCachedChild(Map<String, dynamic> child) {
    return {
      'id': child['id']?.toString() ?? '',
      'orphanage_id': child['orphanage_id']?.toString() ?? '',
      'alias': child['alias']?.toString() ?? child['name']?.toString() ?? '',
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'need_category': child['need_category']?.toString() ?? child['urgentNeeds']?.toString() ?? '',
      'story_summary': child['story_summary']?.toString() ?? child['story']?.toString() ?? '',
      'avatar': child['avatar']?.toString() ?? child['photo']?.toString() ?? '',
      'status': child['status']?.toString() ?? 'Tersedia',
      'orphanage_name': child['orphanage_name']?.toString() ?? '',
      'orphanage_city': child['orphanage_city']?.toString() ?? child['city']?.toString() ?? '',
      'daily_status': child['daily_status']?.toString() ?? '',
      'birth_date': child['birth_date']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _normalizeNewChild(Map<String, dynamic> child, String childId) {
    return {
      'id': childId,
      'name': child['name']?.toString() ?? child['alias']?.toString() ?? '',
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'gender': child['gender']?.toString() ?? 'Laki-laki',
      'city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
      'urgent_needs': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
      'story': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
      'photo': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
      'target': child['target'] is num ? (child['target'] as num).toDouble() : 500000.0,
      'dream': child['dream']?.toString() ?? '',
      'hobby': child['hobby']?.toString() ?? '',
      'created_at': child['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      'category_budgets': child['category_budgets']?.toString() ?? child['categoryBudgets']?.toString() ?? '',
      'daily_status': child['daily_status']?.toString() ?? '',
      'birth_date': child['birth_date']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _normalizeNewChildAsCached(Map<String, dynamic> child, String childId) {
    return {
      'id': childId,
      'orphanage_id': 'panti_peduli_anak',
      'alias': child['name']?.toString() ?? child['alias']?.toString() ?? '',
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'need_category': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
      'story_summary': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
      'avatar': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
      'status': 'Tersedia',
      'orphanage_name': 'Peduli Anak Foundation',
      'orphanage_city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
      'dream': child['dream']?.toString() ?? '',
      'hobby': child['hobby']?.toString() ?? '',
      'target': child['target'] is num ? (child['target'] as num).toDouble() : 500000.0,
      'category_budgets': child['category_budgets']?.toString() ?? child['categoryBudgets']?.toString() ?? '',
      'daily_status': child['daily_status']?.toString() ?? '',
      'birth_date': child['birth_date']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _mapNewChildRow(Map<String, dynamic> r) {
    return {
      'id': r['id'],
      'name': r['name'],
      'alias': r['name'],
      'age': r['age'],
      'gender': r['gender'],
      'city': r['city'],
      'orphanage_city': r['city'],
      'orphanage_name': 'Peduli Anak Foundation',
      'urgentNeeds': r['urgent_needs'],
      'need_category': r['urgent_needs'],
      'story': r['story'],
      'story_summary': r['story'],
      'photo': r['photo'],
      'avatar': r['photo'],
      'target': r['target'],
      'dream': r['dream'],
      'hobby': r['hobby'],
      'category_budgets': r['category_budgets'],
      'categoryBudgets': r['category_budgets'],
      'daily_status': r['daily_status'] ?? '',
      'birth_date': r['birth_date'] ?? '',
    };
  }

  Map<String, dynamic> _normalizeDonation(Map<String, dynamic> donation) {
    return {
      'id': donation['id']?.toString() ?? 'don_${DateTime.now().millisecondsSinceEpoch}',
      'sponsorship_id': donation['sponsorship_id']?.toString() ?? '',
      'child_alias': donation['child_alias']?.toString() ?? '',
      'amount_original': donation['amount_original'] is num ? (donation['amount_original'] as num).toDouble() : 0.0,
      'currency': donation['currency']?.toString() ?? 'IDR',
      'rate_used': donation['rate_used'] is num ? (donation['rate_used'] as num).toDouble() : 1.0,
      'amount_idr': donation['amount_idr'] is num ? (donation['amount_idr'] as num).toDouble() : 0.0,
      'created_at': donation['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'status': donation['status']?.toString() ?? 'Terverifikasi di Ledger',
      'donor_name': donation['donor_name']?.toString() ?? '',
      'donor_email': donation['donor_email']?.toString() ?? '',
      'need_category': donation['need_category']?.toString() ?? '',
      'child_id': donation['child_id']?.toString() ?? '',
      'child_avatar': donation['child_avatar']?.toString() ?? '',
      'child_city': donation['child_city']?.toString() ?? '',
      'certificate_code': donation['certificate_code']?.toString() ?? '',
      'block_hash': donation['block_hash']?.toString() ?? '',
    };
  }

  Map<String, String> _mapUserProfileRow(Map<String, dynamic> row) {
    final decryptedPhone = AesHelper.decrypt(row['phone_encrypted']?.toString() ?? '');
    return {
      'id': row['id']?.toString() ?? '',
      'name': row['name']?.toString() ?? '',
      'phone': decryptedPhone,
      'email': row['email']?.toString() ?? '',
      'photo_url': row['photo_url']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _normalizeReceipt(Map<String, dynamic> receipt) {
    return {
      'id': receipt['id']?.toString() ?? 'rec_${DateTime.now().millisecondsSinceEpoch}',
      'child_name': receipt['childName']?.toString() ?? receipt['child_name']?.toString() ?? '',
      'title': receipt['title']?.toString() ?? '',
      'amount': receipt['amount'] is num ? (receipt['amount'] as num).toDouble() : 0.0,
      'date': receipt['date']?.toString() ?? DateTime.now().toString().split(' ')[0],
      'receipt_image': receipt['receiptImage']?.toString() ?? receipt['receipt_image']?.toString() ?? '',
      'description': receipt['description']?.toString() ?? '',
      'hash': receipt['hash']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _mapReceiptRow(Map<String, dynamic> r) {
    return {
      'id': r['id'],
      'childName': r['child_name'],
      'title': r['title'],
      'amount': r['amount'],
      'date': r['date'],
      'receiptImage': r['receipt_image'],
      'description': r['description'],
      'hash': r['hash'],
    };
  }

  Map<String, dynamic> _normalizeFeedback(Map<String, dynamic> fb) {
    return {
      'id': fb['id']?.toString() ?? 'fb_${DateTime.now().millisecondsSinceEpoch}',
      'user_email': fb['user_email']?.toString() ?? '',
      'user_name': fb['user_name']?.toString() ?? '',
      'rating': fb['rating'] is int ? fb['rating'] : int.tryParse(fb['rating']?.toString() ?? '5') ?? 5,
      'category': fb['category']?.toString() ?? 'Umum',
      'message': fb['message']?.toString() ?? '',
      'created_at': fb['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _normalizeProgressReport(Map<String, dynamic> r) {
    return {
      'id': r['id']?.toString() ?? 'rep_${DateTime.now().microsecondsSinceEpoch}',
      'child_id': r['child_id']?.toString() ?? '',
      'child_alias': r['child_alias']?.toString() ?? r['alias']?.toString() ?? '',
      'title': r['title']?.toString() ?? '',
      'category': r['category']?.toString() ?? 'Kegiatan',
      'period': r['period']?.toString() ?? '',
      'summary': r['summary']?.toString() ?? '',
      'evidence_url': r['evidence_url']?.toString() ?? '',
      'author_name': r['author_name']?.toString() ?? 'Pengurus Panti',
      'created_at': r['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      // PBI 1: status harian 1 baris
      'daily_status': r['daily_status']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _normalizeWishlist(Map<String, dynamic> item) {
    return {
      'id': item['id']?.toString() ?? 'wl_${DateTime.now().microsecondsSinceEpoch}',
      'child_id': item['child_id']?.toString() ?? '',
      'child_alias': item['child_alias']?.toString() ?? item['alias']?.toString() ?? '',
      'item_name': item['item_name']?.toString() ?? '',
      'estimated_idr': item['estimated_idr'] is num
          ? (item['estimated_idr'] as num).toDouble()
          : double.tryParse(item['estimated_idr']?.toString() ?? '0') ?? 0.0,
      'status': item['status']?.toString() ?? 'open',
      'funded_by_user_id': item['funded_by_user_id']?.toString() ?? '',
      'funded_by_name': item['funded_by_name']?.toString() ?? '',
      'receipt_url': item['receipt_url']?.toString() ?? '',
      'created_at': item['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _normalizeSchedule(Map<String, dynamic> schedule) {
    return {
      'id': schedule['id']?.toString() ?? 'sch_${DateTime.now().microsecondsSinceEpoch}',
      'sponsorship_id': schedule['sponsorship_id']?.toString() ?? '',
      'child_id': schedule['child_id']?.toString() ?? '',
      'child_alias': schedule['child_alias']?.toString() ?? '',
      'donor_name': schedule['donor_name']?.toString() ?? '',
      'scheduled_at_utc': schedule['scheduled_at_utc']?.toString() ?? '',
      'donor_timezone': schedule['donor_timezone']?.toString() ?? 'WIB',
      'status': schedule['status']?.toString() ?? 'scheduled',
      'notes': schedule['notes']?.toString() ?? '',
      'admin_notes': schedule['admin_notes']?.toString() ?? '',
      'created_at': schedule['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }

  List<Map<String, dynamic>> _filterByChildKey(
    List<Map<String, dynamic>> rows, {
    String? childId,
    String? childAlias,
  }) {
    if ((childId == null || childId.isEmpty) && (childAlias == null || childAlias.isEmpty)) {
      return rows;
    }
    final cleanId = (childId ?? '').trim();
    final cleanAlias = (childAlias ?? '').trim().toLowerCase();
    return rows.where((r) {
      final rId = (r['child_id'] ?? '').toString().trim();
      final rAlias = (r['child_alias'] ?? '').toString().trim().toLowerCase();
      return (cleanId.isNotEmpty && rId == cleanId) ||
          (cleanAlias.isNotEmpty && rAlias == cleanAlias);
    }).toList();
  }

  Future<void> clearDummyChildren([Database? targetDb]) async {
    if (targetDb == null && _useWebStore) {
      _webStore.clearDummyChildren(_dummyChildNames);
      return;
    }
    final db = targetDb ?? await database;
    await db.delete('cached_children', where: "id LIKE 'child_dummy_%'");
    await db.delete('new_children', where: "id LIKE 'child_dummy_%'");
    for (var name in _dummyChildNames) {
      await db.delete('cached_children', where: 'alias = ?', whereArgs: [name]);
      await db.delete('new_children', where: 'name = ?', whereArgs: [name]);
    }
  }

  Future<void> seed20DummyChildren([Database? targetDb]) async {
    await clearDummyChildren(targetDb);
  }

  Future<void> saveAuthUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
  }) async {
    final row = _normalizeAuthUserRow(
      email: email,
      password: password,
      name: name,
      role: role,
      phone: phone,
    );
    if (_useWebStore) {
      _webStore.authUsers[row['email'] as String] = row;
      return;
    }
    final db = await database;
    await db.insert('auth_users', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> verifyAuthUser({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    if (_useWebStore) {
      return _matchAuthUserRow(_webStore.authUsers[cleanEmail], cleanEmail, password);
    }
    final db = await database;
    final rows = await db.query(
      'auth_users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _matchAuthUserRow(rows.first, cleanEmail, password);
  }

  Future<bool> isEmailRegistered(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    if (_useWebStore) {
      return _webStore.authUsers.containsKey(cleanEmail);
    }
    final db = await database;
    final rows = await db.query(
      'auth_users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> cacheChildren(List<Map<String, dynamic>> childrenList) async {
    if (childrenList.isEmpty) return;
    final normalized = childrenList.map(_normalizeCachedChild).toList();
    if (_useWebStore) {
      _webStore.replaceCachedChildren(normalized);
      return;
    }
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_children');
    batch.delete('new_children');
    for (final row in normalized) {
      batch.insert('cached_children', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAllChildrenCache() async {
    if (_useWebStore) {
      _webStore.cachedChildren.clear();
      _webStore.newChildren.clear();
      return;
    }
    final db = await database;
    await db.delete('cached_children');
    await db.delete('new_children');
  }

  Future<List<Map<String, dynamic>>> getCachedChildren({String query = '', String category = ''}) async {
    if (_useWebStore) {
      return _webStore.queryCachedChildren(query: query, category: category);
    }
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty) {
      whereClause += 'alias LIKE ?';
      whereArgs.add('%$query%');
    }

    if (category.isNotEmpty && category != 'Semua') {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'need_category LIKE ?';
      whereArgs.add('%$category%');
    }

    return await db.query(
      'cached_children',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'alias ASC',
    );
  }

  Future<void> insertChild(Map<String, dynamic> child) async {
    final childId = child['id']?.toString() ?? 'child_${DateTime.now().millisecondsSinceEpoch}';
    final newRow = _normalizeNewChild(child, childId);
    final cachedRow = _normalizeNewChildAsCached(child, childId);
    if (_useWebStore) {
      _webStore.upsert(_webStore.newChildren, newRow);
      _webStore.upsert(_webStore.cachedChildren, cachedRow);
      return;
    }
    final db = await database;
    await db.insert('new_children', newRow, conflictAlgorithm: ConflictAlgorithm.replace);
    try {
      await db.insert('cached_children', cachedRow, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> updateChild(Map<String, dynamic> child) async {
    final childId = child['id']?.toString() ?? '';
    final name = child['name']?.toString() ?? child['alias']?.toString() ?? '';
    final newUpdates = {
      'name': name,
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'gender': child['gender']?.toString() ?? 'Laki-laki',
      'city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
      'urgent_needs': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
      'story': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
      'photo': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
      'target': child['target'] is num ? (child['target'] as num).toDouble() : 500000.0,
      'dream': child['dream']?.toString() ?? '',
      'hobby': child['hobby']?.toString() ?? '',
      'category_budgets': child['category_budgets']?.toString() ?? child['categoryBudgets']?.toString() ?? '',
    };
    final cachedUpdates = {
      'alias': name,
      'age': child['age'] is int ? child['age'] : int.tryParse(child['age']?.toString() ?? '0') ?? 0,
      'need_category': child['urgentNeeds']?.toString() ?? child['urgent_needs']?.toString() ?? child['need_category']?.toString() ?? 'Pendidikan',
      'story_summary': child['story']?.toString() ?? child['story_summary']?.toString() ?? '',
      'avatar': child['photo']?.toString() ?? child['avatar']?.toString() ?? '',
      'orphanage_city': child['city']?.toString() ?? child['orphanage_city']?.toString() ?? 'PeduliAnak Lombok',
      'dream': child['dream']?.toString() ?? '',
      'hobby': child['hobby']?.toString() ?? '',
      'target': child['target'] is num ? (child['target'] as num).toDouble() : 500000.0,
      'category_budgets': child['category_budgets']?.toString() ?? child['categoryBudgets']?.toString() ?? '',
    };

    if (_useWebStore) {
      _webStore.updateMatching(
        _webStore.newChildren,
        (r) => r['id']?.toString() == childId || r['name']?.toString() == name,
        newUpdates,
      );
      _webStore.updateMatching(
        _webStore.cachedChildren,
        (r) => r['id']?.toString() == childId || r['alias']?.toString() == name,
        cachedUpdates,
      );
      return;
    }

    final db = await database;
    await db.update('new_children', newUpdates, where: 'id = ? OR name = ?', whereArgs: [childId, name]);
    try {
      await db.update('cached_children', cachedUpdates, where: 'id = ? OR alias = ?', whereArgs: [childId, name]);
    } catch (_) {}
  }

  Future<void> deleteChild(String childId, [String? childName]) async {
    final name = childName ?? childId;
    if (_useWebStore) {
      _webStore.newChildren.removeWhere((r) => r['id']?.toString() == childId || r['name']?.toString() == name);
      _webStore.cachedChildren.removeWhere((r) => r['id']?.toString() == childId || r['alias']?.toString() == name);
      return;
    }
    final db = await database;
    await db.delete('new_children', where: 'id = ? OR name = ?', whereArgs: [childId, name]);
    await db.delete('cached_children', where: 'id = ? OR alias = ?', whereArgs: [childId, name]);
  }

  Future<List<Map<String, dynamic>>> getNewChildren() async {
    final rows = _useWebStore
        ? _webStore.sortedDesc(_webStore.newChildren, 'created_at')
        : await (await database).query('new_children', orderBy: 'created_at DESC');
    return rows.map(_mapNewChildRow).toList();
  }

  Future<void> insertDonation(Map<String, dynamic> donation) async {
    final row = _normalizeDonation(donation);
    if (_useWebStore) {
      _webStore.upsert(_webStore.cachedDonations, row);
      return;
    }
    final db = await database;
    await db.insert('cached_donations', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCachedDonations() async {
    if (_useWebStore) {
      return _webStore.sortedDesc(_webStore.cachedDonations, 'created_at');
    }
    final db = await database;
    return await db.query('cached_donations', orderBy: 'created_at DESC');
  }

  Future<int> queueOfflineDonation({
    required String childId,
    required String packageId,
    required double amountOriginal,
    required String currency,
    required double rateUsed,
    required double amountIdr,
    required String frequency,
    String? packageName,
    String? donorName,
    String? donorEmail,
    String? notes,
  }) async {
    final row = {
      'child_id': childId,
      'package_id': packageId,
      'amount_original': amountOriginal,
      'currency': currency,
      'rate_used': rateUsed,
      'amount_idr': amountIdr,
      'frequency': frequency,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
      'local_id': 'offline_${DateTime.now().microsecondsSinceEpoch}',
      'package_name': packageName,
      'donor_name': donorName,
      'donor_email': donorEmail,
      'notes': notes,
    };
    if (_useWebStore) {
      return _webStore.insertOfflineDonation(row);
    }
    final db = await database;
    return await db.insert('offline_donations_queue', row);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedDonations() async {
    if (_useWebStore) {
      return _webStore.offlineDonations
          .where((r) => (r['is_synced'] ?? 0) == 0)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    final db = await database;
    return await db.query('offline_donations_queue', where: 'is_synced = 0');
  }

  Future<void> markDonationSynced(int queueId) async {
    if (_useWebStore) {
      _webStore.updateMatching(
        _webStore.offlineDonations,
        (r) => r['id'] == queueId,
        {'is_synced': 1},
      );
      return;
    }
    final db = await database;
    await db.update(
      'offline_donations_queue',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<void> saveUserProfile({
    required String id,
    required String name,
    required String plainPhone,
    required String email,
    String? photoUrl,
  }) async {
    final encryptedPhone = AesHelper.encrypt(plainPhone);
    final row = {
      'id': id,
      'name': name,
      'phone_encrypted': encryptedPhone,
      'email': email,
      'photo_url': photoUrl ?? '',
    };
    if (_useWebStore) {
      _webStore.userProfiles[id] = row;
      return;
    }
    final db = await database;
    await db.insert('user_profile', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>?> getUserProfile(String id) async {
    if (_useWebStore) {
      final row = _webStore.userProfiles[id];
      return row == null ? null : _mapUserProfileRow(row);
    }
    final db = await database;
    final results = await db.query('user_profile', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return _mapUserProfileRow(results.first);
  }

  Future<void> insertReceipt(Map<String, dynamic> receipt) async {
    final row = _normalizeReceipt(receipt);
    if (_useWebStore) {
      _webStore.upsert(_webStore.receipts, row);
      return;
    }
    final db = await database;
    await db.insert('receipts', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getReceipts() async {
    final rows = _useWebStore
        ? _webStore.sortedDesc(_webStore.receipts, 'date')
        : await (await database).query('receipts', orderBy: 'date DESC');
    return rows.map(_mapReceiptRow).toList();
  }

  Future<void> insertFeedback(Map<String, dynamic> fb) async {
    final row = _normalizeFeedback(fb);
    if (_useWebStore) {
      _webStore.upsert(_webStore.feedbackEntries, row);
      return;
    }
    final db = await database;
    await db.insert('feedback_entries', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllFeedbacks() async {
    if (_useWebStore) {
      return _webStore.sortedDesc(_webStore.feedbackEntries, 'created_at');
    }
    final db = await database;
    return await db.query('feedback_entries', orderBy: 'created_at DESC');
  }

  Future<void> insertChatMessage({
    required String childAlias,
    required String sender,
    required String text,
    String type = 'text',
    String fileUrl = '',
    String? time,
  }) async {
    final now = DateTime.now();
    final row = {
      'child_alias': childAlias.trim(),
      'sender': sender,
      'text': text,
      'type': type,
      'file_url': fileUrl,
      'time': time ?? '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      'created_at': now.toIso8601String(),
    };
    if (_useWebStore) {
      _webStore.insertChatMessage(row);
      return;
    }
    final db = await database;
    await db.insert('chat_messages', row);
  }

  Future<List<Map<String, dynamic>>> getChatMessages(String childAlias) async {
    final clean = childAlias.trim().toLowerCase();
    if (_useWebStore) {
      return _webStore.getChatMessages(clean);
    }
    final db = await database;
    return await db.query(
      'chat_messages',
      where: 'LOWER(TRIM(child_alias)) = ?',
      whereArgs: [clean],
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, dynamic>?> getLastChatMessage(String childAlias) async {
    final clean = childAlias.trim().toLowerCase();
    if (_useWebStore) {
      final matches = _webStore.getChatMessages(clean);
      return matches.isNotEmpty ? matches.last : null;
    }
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'LOWER(TRIM(child_alias)) = ?',
      whereArgs: [clean],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<bool> hasAnyChatMessages() async {
    if (_useWebStore) {
      return _webStore.chatMessages.isNotEmpty;
    }
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM chat_messages');
    final count = Sqflite.firstIntValue(res) ?? 0;
    return count > 0;
  }

  Future<void> cacheProgressReports(List<Map<String, dynamic>> reports) async {
    if (reports.isEmpty) return;
    final normalized = reports.map(_normalizeProgressReport).toList();
    if (_useWebStore) {
      for (final row in normalized) {
        _webStore.upsert(_webStore.cachedProgressReports, row);
      }
      return;
    }
    final db = await database;
    final batch = db.batch();
    for (final row in normalized) {
      batch.insert('cached_progress_reports', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedProgressReports({
    String? childId,
    String? childAlias,
  }) async {
    final rows = _useWebStore
        ? _webStore.sortedDesc(_webStore.cachedProgressReports, 'created_at')
        : await (await database).query('cached_progress_reports', orderBy: 'created_at DESC');
    return _filterByChildKey(rows, childId: childId, childAlias: childAlias);
  }

  Future<void> deleteCachedProgressReport(String id) async {
    if (_useWebStore) {
      _webStore.cachedProgressReports.removeWhere((r) => r['id']?.toString() == id);
      return;
    }
    final db = await database;
    await db.delete('cached_progress_reports', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateChildDailyStatusLocal(String childKey, String dailyStatus) async {
    final clean = childKey.trim().toLowerCase();
    if (_useWebStore) {
      _webStore.updateMatching(
        _webStore.cachedChildren,
        (r) => r['id']?.toString() == childKey || (r['alias'] ?? '').toString().trim().toLowerCase() == clean,
        {'daily_status': dailyStatus},
      );
      _webStore.updateMatching(
        _webStore.newChildren,
        (r) => r['id']?.toString() == childKey || (r['name'] ?? '').toString().trim().toLowerCase() == clean,
        {'daily_status': dailyStatus},
      );
      return;
    }
    final db = await database;
    await db.update(
      'cached_children',
      {'daily_status': dailyStatus},
      where: 'id = ? OR LOWER(TRIM(alias)) = ?',
      whereArgs: [childKey, clean],
    );
    try {
      await db.update(
        'new_children',
        {'daily_status': dailyStatus},
        where: 'id = ? OR LOWER(TRIM(name)) = ?',
        whereArgs: [childKey, clean],
      );
    } catch (_) {}
  }

  Future<void> cacheWishlists(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final normalized = items.map(_normalizeWishlist).toList();
    if (_useWebStore) {
      for (final row in normalized) {
        _webStore.upsert(_webStore.cachedWishlists, row);
      }
      return;
    }
    final db = await database;
    final batch = db.batch();
    for (final row in normalized) {
      batch.insert('cached_wishlists', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedWishlists({
    String? childId,
    String? childAlias,
  }) async {
    final rows = _useWebStore
        ? _webStore.sortedDesc(_webStore.cachedWishlists, 'created_at')
        : await (await database).query('cached_wishlists', orderBy: 'created_at DESC');
    return _filterByChildKey(rows, childId: childId, childAlias: childAlias);
  }

  Future<void> upsertScheduleLocal(Map<String, dynamic> schedule) async {
    final row = _normalizeSchedule(schedule);
    if (_useWebStore) {
      _webStore.upsert(_webStore.cachedSchedules, row);
      return;
    }
    final db = await database;
    await db.insert('cached_schedules', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCachedSchedules() async {
    if (_useWebStore) {
      return _webStore.sortedDesc(_webStore.cachedSchedules, 'created_at');
    }
    final db = await database;
    return await db.query('cached_schedules', orderBy: 'created_at DESC');
  }
}

/// In-memory session store used on Flutter Web where sqflite is unavailable.
class _WebMemoryStore {
  final Map<String, Map<String, dynamic>> authUsers = {};
  final List<Map<String, dynamic>> cachedChildren = [];
  final List<Map<String, dynamic>> newChildren = [];
  final List<Map<String, dynamic>> cachedDonations = [];
  final List<Map<String, dynamic>> offlineDonations = [];
  final Map<String, Map<String, dynamic>> userProfiles = {};
  final List<Map<String, dynamic>> receipts = [];
  final List<Map<String, dynamic>> feedbackEntries = [];
  final List<Map<String, dynamic>> chatMessages = [];
  final List<Map<String, dynamic>> cachedProgressReports = [];
  final List<Map<String, dynamic>> cachedWishlists = [];
  final List<Map<String, dynamic>> cachedSchedules = [];
  int _nextOfflineId = 1;
  int _nextChatId = 1;

  _WebMemoryStore() {
    _seedDefaultUsers();
  }

  void _seedDefaultUsers() {
    final now = DateTime.now().toIso8601String();
    authUsers['donatur@asuhkita.id'] = {
      'email': 'donatur@asuhkita.id',
      'password_hash': LocalDatabase.hashPassword('donatur123'),
      'name': 'Donatur Asuh',
      'role': 'donatur',
      'phone': '081234567890',
      'created_at': now,
    };
    authUsers['admin@asuhkita.id'] = {
      'email': 'admin@asuhkita.id',
      'password_hash': LocalDatabase.hashPassword('admin123!'),
      'name': 'Admin Pengurus Panti',
      'role': 'admin_panti',
      'phone': '081987654321',
      'created_at': now,
    };
  }

  void reset() {
    authUsers.clear();
    cachedChildren.clear();
    newChildren.clear();
    cachedDonations.clear();
    offlineDonations.clear();
    userProfiles.clear();
    receipts.clear();
    feedbackEntries.clear();
    chatMessages.clear();
    cachedProgressReports.clear();
    cachedWishlists.clear();
    cachedSchedules.clear();
    _nextOfflineId = 1;
    _nextChatId = 1;
    _seedDefaultUsers();
  }

  void clearDummyChildren(List<String> dummyNames) {
    final dummySet = dummyNames.toSet();
    cachedChildren.removeWhere((r) {
      final id = (r['id'] ?? '').toString();
      final alias = (r['alias'] ?? '').toString();
      return id.startsWith('child_dummy_') || dummySet.contains(alias);
    });
    newChildren.removeWhere((r) {
      final id = (r['id'] ?? '').toString();
      final name = (r['name'] ?? '').toString();
      return id.startsWith('child_dummy_') || dummySet.contains(name);
    });
  }

  void replaceCachedChildren(List<Map<String, dynamic>> normalized) {
    cachedChildren.clear();
    newChildren.clear();
    for (final row in normalized) {
      upsert(cachedChildren, row);
    }
  }

  List<Map<String, dynamic>> queryCachedChildren({String query = '', String category = ''}) {
    final cleanQuery = query.toLowerCase();
    final cleanCategory = category.toLowerCase();
    final filtered = cachedChildren.where((r) {
      final alias = (r['alias'] ?? '').toString().toLowerCase();
      final needCat = (r['need_category'] ?? '').toString().toLowerCase();
      final matchQuery = cleanQuery.isEmpty || alias.contains(cleanQuery);
      final matchCat = category.isEmpty || category == 'Semua' || needCat.contains(cleanCategory);
      return matchQuery && matchCat;
    }).map((r) => Map<String, dynamic>.from(r)).toList();

    filtered.sort((a, b) => (a['alias'] ?? '').toString().toLowerCase().compareTo(
          (b['alias'] ?? '').toString().toLowerCase(),
        ));
    return filtered;
  }

  void upsert(List<Map<String, dynamic>> list, Map<String, dynamic> row, {String key = 'id'}) {
    final rowKey = row[key]?.toString() ?? '';
    list.removeWhere((e) => (e[key]?.toString() ?? '') == rowKey);
    list.add(Map<String, dynamic>.from(row));
  }

  void updateMatching(
    List<Map<String, dynamic>> list,
    bool Function(Map<String, dynamic>) matcher,
    Map<String, dynamic> updates,
  ) {
    for (final row in list) {
      if (matcher(row)) {
        row.addAll(updates);
      }
    }
  }

  List<Map<String, dynamic>> sortedDesc(List<Map<String, dynamic>> list, String field) {
    final copy = list.map((r) => Map<String, dynamic>.from(r)).toList();
    copy.sort((a, b) => (b[field] ?? '').toString().compareTo((a[field] ?? '').toString()));
    return copy;
  }

  int insertOfflineDonation(Map<String, dynamic> row) {
    final id = _nextOfflineId++;
    final entry = Map<String, dynamic>.from(row)..['id'] = id;
    offlineDonations.add(entry);
    return id;
  }

  void insertChatMessage(Map<String, dynamic> row) {
    final id = _nextChatId++;
    final entry = Map<String, dynamic>.from(row)..['id'] = id;
    chatMessages.add(entry);
  }

  List<Map<String, dynamic>> getChatMessages(String cleanAlias) {
    final matches = chatMessages
        .where((r) => (r['child_alias'] ?? '').toString().trim().toLowerCase() == cleanAlias)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    matches.sort((a, b) => ((a['id'] as int?) ?? 0).compareTo((b['id'] as int?) ?? 0));
    return matches;
  }
}
