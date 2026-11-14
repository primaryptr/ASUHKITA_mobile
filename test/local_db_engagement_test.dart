import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/local_db.dart';
import 'package:sqflite/sqflite.dart';

class _InMemoryBatch implements Batch {
  _InMemoryBatch(this.db);
  final _InMemoryDatabase db;
  final List<Future<void> Function()> _ops = [];

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _ops.add(() => db.insert(table, values, conflictAlgorithm: conflictAlgorithm));
  }

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _ops.add(() => db.delete(table, where: where, whereArgs: whereArgs));
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    for (final op in _ops) {
      await op();
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryDatabase implements Database {
  final Map<String, List<Map<String, Object?>>> tables = {
    'cached_progress_reports': [],
    'cached_wishlists': [],
    'cached_schedules': [],
    'cached_children': [
      {'id': 'ch-001', 'alias': 'Bintang', 'daily_status': ''}
    ],
    'new_children': [],
  };

  @override
  Batch batch() => _InMemoryBatch(this);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables.putIfAbsent(table, () => []);
    final idx = list.indexWhere((e) => e['id'] == values['id']);
    if (idx >= 0) {
      list[idx] = Map<String, Object?>.from(values);
    } else {
      list.add(Map<String, Object?>.from(values));
    }
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables.putIfAbsent(table, () => []);
    int count = 0;
    for (final row in list) {
      if (where == null ||
          (whereArgs != null &&
              whereArgs.any((arg) =>
                  row['id']?.toString().toLowerCase() == arg.toString().toLowerCase() ||
                  row['alias']?.toString().toLowerCase() == arg.toString().toLowerCase() ||
                  row['name']?.toString().toLowerCase() == arg.toString().toLowerCase()))) {
        row.addAll(values);
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final list = tables.putIfAbsent(table, () => []);
    if (where == null) {
      final len = list.length;
      list.clear();
      return len;
    }
    final before = list.length;
    if (whereArgs != null && whereArgs.isNotEmpty) {
      list.removeWhere((row) => row['id'] == whereArgs.first);
    }
    return before - list.length;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return List<Map<String, Object?>>.from(tables[table] ?? []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _InMemoryDatabase fakeDb;

  setUp(() {
    fakeDb = _InMemoryDatabase();
    LocalDatabase.setDatabaseForTest(fakeDb);
  });

  tearDown(() {
    LocalDatabase.setDatabaseForTest(null);
  });

  test('LocalDatabase supports engagement tables, daily status, wishlists, and schedules', () async {
    final db = LocalDatabase();

    await db.cacheProgressReports([
      {
        'id': 'rep-1',
        'child_id': 'ch-001',
        'child_alias': 'Bintang',
        'title': 'Juara Lomba Mewarnai',
        'category': 'Prestasi',
        'period': '2026-11',
        'summary': 'Bintang meraih juara 1 mewarnai.',
        'evidence_url': '',
        'author_name': 'Ibu Sari',
        'created_at': '2026-11-13T08:00:00Z',
      },
      {
        'id': 'rep-2',
        'child_id': 'ch-002',
        'child_alias': 'Bulan',
        'title': 'Lukisan Pemandangan',
        'category': 'Karya Anak',
        'period': '2026-11',
        'summary': 'Bulan melukis gunung.',
        'evidence_url': 'data:image/png;base64,AAA',
        'author_name': 'Ibu Sari',
        'created_at': '2026-11-13T09:00:00Z',
      },
    ]);

    final bintangByAlias = await db.getCachedProgressReports(childAlias: 'bintang');
    expect(bintangByAlias.length, 1);
    expect(bintangByAlias.first['title'], 'Juara Lomba Mewarnai');

    final bintangById = await db.getCachedProgressReports(childId: 'ch-001');
    expect(bintangById.length, 1);

    await db.updateChildDailyStatusLocal('Bintang', 'Senang belajar matematika');
    expect(fakeDb.tables['cached_children']!.first['daily_status'], 'Senang belajar matematika');

    await db.cacheWishlists([
      {
        'id': 'wl-1',
        'child_id': 'ch-001',
        'child_alias': 'Bintang',
        'item_name': 'Sepatu Sekolah',
        'estimated_idr': 180000,
        'status': 'open',
      }
    ]);
    final wishlists = await db.getCachedWishlists(childAlias: 'bintang');
    expect(wishlists.length, 1);
    expect(wishlists.first['item_name'], 'Sepatu Sekolah');

    await db.upsertScheduleLocal({
      'id': 'sch-1',
      'sponsorship_id': 'sp-1',
      'child_id': 'ch-001',
      'child_alias': 'Bintang',
      'donor_name': 'Donatur Test',
      'scheduled_at_utc': '2026-11-20T10:00:00Z',
      'donor_timezone': 'WIB',
      'status': 'approved',
      'notes': 'Sapa sore',
      'admin_notes': 'Oke siap',
    });
    final schedules = await db.getCachedSchedules();
    expect(schedules.length, 1);
    expect(schedules.first['status'], 'approved');
  });

  group('LocalDatabase Web in-memory fallback store', () {
    setUp(() {
      LocalDatabase.setDatabaseForTest(null);
      LocalDatabase.forceWebStoreForTest = true;
      LocalDatabase.resetWebStoreForTest();
    });

    tearDown(() {
      LocalDatabase.resetWebStoreForTest();
      LocalDatabase.forceWebStoreForTest = false;
    });

    test('operates auth, children, donations, chat, and engagement without sqflite', () async {
      final db = LocalDatabase();

      final admin = await db.verifyAuthUser(email: 'admin@asuhkita.id', password: 'admin123!');
      expect(admin?['role'], 'admin_panti');

      await db.cacheChildren([
        {
          'id': 'ch-1',
          'alias': 'Bintang',
          'age': 10,
          'need_category': 'Pendidikan',
          'status': 'Tersedia',
          'orphanage_name': 'Panti Peduli Anak',
          'orphanage_city': 'Lombok',
        },
        {
          'id': 'ch-2',
          'alias': 'Awan',
          'age': 12,
          'need_category': 'Kesehatan',
          'status': 'Tersedia',
          'orphanage_name': 'Panti Peduli Anak',
          'orphanage_city': 'Lombok',
        },
      ]);

      final allCached = await db.getCachedChildren();
      expect(allCached.map((e) => e['alias']).toList(), ['Awan', 'Bintang']);

      final filtered = await db.getCachedChildren(query: 'bin', category: 'Pendidikan');
      expect(filtered.length, 1);
      expect(filtered.first['id'], 'ch-1');

      await db.insertChild({'id': 'ch-3', 'name': 'Mentari', 'age': 9, 'urgentNeeds': 'Pendidikan'});
      expect((await db.getNewChildren()).length, 1);
      await db.updateChild({'id': 'ch-3', 'name': 'Mentari', 'age': 10, 'urgentNeeds': 'Gizi'});
      expect((await db.getCachedChildren(query: 'Mentari')).first['need_category'], 'Gizi');
      await db.updateChildDailyStatusLocal('ch-3', 'Aktif belajar');
      expect((await db.getNewChildren()).first['daily_status'], 'Aktif belajar');
      await db.deleteChild('ch-3', 'Mentari');
      expect(await db.getNewChildren(), isEmpty);

      await db.insertDonation({
        'id': 'don-1',
        'child_id': 'ch-1',
        'child_alias': 'Bintang',
        'amount_idr': 150000,
        'donor_name': 'Donatur Web',
      });
      final donations = await db.getCachedDonations();
      expect(donations.length, 1);
      expect(donations.first['amount_idr'], 150000.0);

      final qId = await db.queueOfflineDonation(
        childId: 'ch-1',
        packageId: 'pkg-1',
        amountOriginal: 100000,
        currency: 'IDR',
        rateUsed: 1,
        amountIdr: 100000,
        frequency: 'sekali',
      );
      expect((await db.getUnsyncedDonations()).length, 1);
      await db.markDonationSynced(qId);
      expect(await db.getUnsyncedDonations(), isEmpty);

      await db.insertChatMessage(childAlias: 'Bintang', sender: 'donatur', text: 'Semangat!');
      expect(await db.hasAnyChatMessages(), isTrue);
      expect((await db.getChatMessages(' bintang ')).length, 1);
      expect((await db.getLastChatMessage('BINTANG'))?['text'], 'Semangat!');

      await db.cacheProgressReports([
        {'id': 'rep-w1', 'child_id': 'ch-1', 'child_alias': 'Bintang', 'title': 'Rapot Bagus'},
      ]);
      expect((await db.getCachedProgressReports(childAlias: 'Bintang')).length, 1);
      await db.deleteCachedProgressReport('rep-w1');
      expect(await db.getCachedProgressReports(), isEmpty);

      await db.cacheWishlists([
        {'id': 'wl-w1', 'child_id': 'ch-1', 'child_alias': 'Bintang', 'item_name': 'Tas', 'estimated_idr': 120000},
      ]);
      expect((await db.getCachedWishlists(childId: 'ch-1')).length, 1);

      await db.upsertScheduleLocal({'id': 'sch-w1', 'child_id': 'ch-1', 'child_alias': 'Bintang', 'status': 'approved'});
      expect((await db.getCachedSchedules()).length, 1);
    });
  });
}
