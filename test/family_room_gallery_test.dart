import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mobile/core/dio_client.dart';
import 'package:mobile/data/local_db.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/communication/child_gallery_screen.dart';
import 'package:mobile/features/communication/family_room_screen.dart';

class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"success":false}', 503);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  _FakeAuth({this.role = 'admin_panti'});
  final String role;

  @override
  String get userRole => role;

  @override
  bool get isAdmin => role == 'admin_panti';

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  String get userName => isAdmin ? 'Admin Panti' : 'Donatur Uji';

  @override
  String get userEmail => 'admin@asuhkita.app';

  @override
  String get userId => 'usr-admin-001';

  @override
  bool get isBiometricAvailable => false;

  @override
  bool get isBiometricEnabled => false;

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGalleryDb implements Database {
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
    if (table == 'cached_children') {
      return [
        {
          'id': 'ch-001',
          'alias': 'Bintang',
          'need_category': 'Pendidikan',
          'avatar': '',
          'orphanage_city': 'Jakarta',
          'daily_status': 'Senang ikut kelas robotik 🤖',
        },
        {
          'id': 'ch-002',
          'alias': 'Bulan',
          'need_category': 'Gizi',
          'avatar': '',
          'orphanage_city': 'Jakarta',
          'daily_status': '',
        },
      ];
    }
    if (table == 'cached_progress_reports') {
      return [
        {
          'id': 'rep-1',
          'child_id': 'ch-001',
          'child_alias': 'Bintang',
          'title': 'Karya Origami',
          'category': 'Karya Anak',
          'summary': 'Origami burung bangau buatan Bintang',
          'evidence_url': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          'created_at': '2026-11-13T08:00:00Z',
        },
      ];
    }
    if (table == 'chat_messages') {
      return [
        {
          'id': 1,
          'child_alias': 'Bintang',
          'sender': 'admin',
          'text': 'Foto melukis',
          'type': 'file',
          'file_url': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          'created_at': '2026-11-13T09:00:00Z',
        },
        {
          'id': 2,
          'child_alias': 'Bintang',
          'sender': 'admin',
          'text': 'Duplikat origami',
          'type': 'file',
          'file_url': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          'created_at': '2026-11-13T09:05:00Z',
        },
      ];
    }
    return const [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    return [
      {'cnt': 1}
    ];
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async => 1;

  @override
  Batch batch() => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late HttpClientAdapter origAdapter;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    SharedPreferences.setMockInitialValues({});
    origAdapter = DioClient().dio.httpClientAdapter;
    DioClient().dio.httpClientAdapter = _OfflineAdapter();
    DioClient().dio.options.connectTimeout = const Duration(milliseconds: 50);
    DioClient().dio.options.receiveTimeout = const Duration(milliseconds: 50);
    LocalDatabase.setDatabaseForTest(_FakeGalleryDb());
  });

  tearDown(() {
    DioClient().dio.httpClientAdapter = origAdapter;
    LocalDatabase.setDatabaseForTest(null);
  });

  testWidgets('ChildGalleryScreen merges report & chat images without duplicates and handles empty state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(),
        child: const MaterialApp(
          home: ChildGalleryScreen(
            childId: 'ch-001',
            childAlias: 'Bintang',
            isAdmin: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Karya Origami'), findsOneWidget);
    expect(find.text('Foto melukis'), findsOneWidget);
    expect(find.text('Duplikat origami'), findsNothing);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(),
        child: const MaterialApp(
          key: ValueKey('empty_gallery'),
          home: ChildGalleryScreen(
            childId: 'ch-empty',
            childAlias: 'AnakKosong',
            isAdmin: false,
            initialItems: [],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Belum ada karya atau foto anak'), findsOneWidget);
  });

  testWidgets('FamilyRoomScreen displays dynamic daily_status instead of hardcoded _childNotes', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: FamilyRoomScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Senang ikut kelas robotik 🤖'), findsOneWidget);
    expect(find.text('Semangat belajar 🎒'), findsOneWidget);
    expect(find.text('Lagi les matematika 📚'), findsNothing);
  });
}
