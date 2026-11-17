import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mobile/core/dio_client.dart';
import 'package:mobile/data/local_db.dart';
import 'package:mobile/features/admin/admin_panel_screen.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/sponsor/child_detail_screen.dart';

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

class _ChildrenApiAdapter implements HttpClientAdapter {
  static final List<Map<String, dynamic>> _sampleChildren = List.generate(
    8,
    (i) => {
      'id': 'ch-00${i + 1}',
      'alias': 'Anak ${i + 1}',
      'age': 8 + (i % 5),
      'need_category': 'Pendidikan',
      'story_summary': 'Cerita anak ${i + 1}',
      'avatar': 'assets/children/1.webp',
      'status': 'Tersedia',
      'orphanage_name': 'Panti Asuhan Peduli Anak',
      'orphanage_city': 'Lombok Barat',
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/children' || options.path.endsWith('/children')) {
      return ResponseBody.fromString(
        jsonEncode({'success': true, 'data': _sampleChildren}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"success":false}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  _FakeAuth({this.role = 'donatur'});
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
  String get userEmail => isAdmin ? 'admin@asuhkita.app' : 'donor@asuhkita.app';

  @override
  String get userId => isAdmin ? 'usr-admin-001' : 'usr-demo-001';

  @override
  bool get isBiometricAvailable => false;

  @override
  bool get isBiometricEnabled => false;

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDb implements Database {
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
    return const [];
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
    LocalDatabase.setDatabaseForTest(_FakeDb());
  });

  tearDown(() {
    DioClient().dio.httpClientAdapter = origAdapter;
    LocalDatabase.setDatabaseForTest(null);
    LocalDatabase.resetWebStoreForTest();
    LocalDatabase.forceWebStoreForTest = false;
  });

  testWidgets('ChildDetailScreen shows Kirim Doa / Semangat button and birthday reminder trigger', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'donatur'),
        child: const MaterialApp(
          home: ChildDetailScreen(
            childData: {
              'id': 'ch-001',
              'alias': 'Bintang',
              'age': 10,
              'birth_date': '2016-11-20',
              'need_category': 'Pendidikan',
              'target': 500000,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kirim Doa / Semangat'), findsOneWidget);
    expect(find.textContaining('Pengingat Ulang Tahun'), findsOneWidget);
  });

  testWidgets('Admin HomeScreen and AdminPanelScreen expose Broadcast Kabar ke Donatur', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Broadcast Kabar ke Donatur'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: AdminPanelScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Broadcast Kabar ke Donatur'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.volunteer_activism),
      ),
      findsNothing,
    );
  });

  testWidgets('Pushed AdminPanelScreen shows BackButton and pops back cleanly', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                ),
                child: const Text('Buka Panel'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Panel'));
    await tester.pumpAndSettle();

    expect(find.text('Panel Kelola Panti'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Buka Panel'), findsOneWidget);
  });

  testWidgets('HomeScreen and AdminPanelScreen render 8 Anak with Web store when /children succeeds', (tester) async {
    DioClient().dio.httpClientAdapter = _ChildrenApiAdapter();
    LocalDatabase.setDatabaseForTest(null);
    LocalDatabase.forceWebStoreForTest = true;
    LocalDatabase.resetWebStoreForTest();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8 Anak'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: AdminPanelScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total Terdaftar: 8 Anak'), findsOneWidget);
  });

  testWidgets('Bagikan Kabar Anak preserves 4 fields after AI polish and publishes cleanly without crash', (tester) async {
    DioClient().dio.httpClientAdapter = _ChildrenApiAdapter();
    LocalDatabase.setDatabaseForTest(null);
    LocalDatabase.forceWebStoreForTest = true;
    LocalDatabase.resetWebStoreForTest();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: AdminPanelScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anak 1').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'No overflow opening child detail bottom sheet');

    final shareBtn = find.text('Bagikan Kabar Anak');
    await tester.scrollUntilVisible(shareBtn, 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(shareBtn);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'No overflow opening Bagikan Kabar dialog');

    expect(find.text('Bagikan Kabar Anak 1'), findsOneWidget);
    expect(find.text('Kategori Kabar'), findsOneWidget);
    expect(find.text('📢 Status Harian (1 baris singkat)'), findsOneWidget);
    expect(find.text('Judul Kabar'), findsOneWidget);
    expect(find.text('Cerita Perkembangan'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '📢 Status Harian (1 baris singkat)'),
      'Hari ini menang lomba mewarnai!',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Judul Kabar'),
      'Juara 1 Mewarnai',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Cerita Perkembangan'),
      'anak sangat antusias mengikuti lomba tingkat kabupaten hari ini',
    );
    await tester.pump();

    await tester.tap(find.text('Rapikan Kalimat dengan AI'));
    await tester.pumpAndSettle();

    // All 4 fields remain intact; only Cerita Perkembangan is polished cleanly.
    expect(find.text('Kategori Kabar'), findsOneWidget);
    expect(find.text('Prestasi'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, '📢 Status Harian (1 baris singkat)')).controller?.text,
      equals('Hari ini menang lomba mewarnai!'),
    );
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Judul Kabar')).controller?.text,
      equals('Juara 1 Mewarnai'),
    );
    final polishedStory = tester
        .widget<TextField>(find.widgetWithText(TextField, 'Cerita Perkembangan'))
        .controller
        ?.text ?? '';
    expect(polishedStory.contains('Ringkasan Perkembangan Anak'), isFalse);
    expect(polishedStory.contains('•'), isFalse);
    expect(polishedStory.startsWith('Anak sangat antusias'), isTrue);

    await tester.tap(find.text('Publikasikan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bagikan Kabar Anak 1'), findsNothing);
    expect(find.text('✅ Kabar Anak 1 berhasil dipublikasikan!'), findsOneWidget);

    final reports = await LocalDatabase().getCachedProgressReports(childAlias: 'Anak 1');
    expect(reports.length, 1);
    expect(reports.first['title'], 'Juara 1 Mewarnai');
    expect(reports.first['daily_status'], 'Hari ini menang lomba mewarnai!');
  });

  testWidgets('Broadcast Kabar ke Donatur opens, cancels, and sends cleanly from HomeScreen and AdminPanelScreen', (tester) async {
    DioClient().dio.httpClientAdapter = _ChildrenApiAdapter();
    LocalDatabase.setDatabaseForTest(null);
    LocalDatabase.forceWebStoreForTest = true;
    LocalDatabase.resetWebStoreForTest();

    // 1. From HomeScreen Admin
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final homeCard = find.text('Broadcast Kabar ke Donatur');
    await tester.scrollUntilVisible(homeCard, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(homeCard);
    await tester.pumpAndSettle();

    expect(find.text('Judul Notifikasi'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Judul Notifikasi'), findsNothing);

    // 2. From AdminPanelScreen AppBar icon
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: AdminPanelScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Broadcast Kabar ke Donatur'));
    await tester.pumpAndSettle();

    // Empty submit validates inline without crashing
    await tester.tap(find.text('Kirim Broadcast'));
    await tester.pump();
    expect(find.textContaining('wajib diisi'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Judul Notifikasi'), 'Info Panti Terbaru');
    await tester.enterText(find.widgetWithText(TextField, 'Isi Pesan Broadcast'), 'Terima kasih donatur.');
    await tester.pump();

    await tester.tap(find.text('Kirim Broadcast'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Judul Notifikasi'), findsNothing);
    expect(find.text('📡 Broadcast tercatat, akan dikirim saat terhubung.'), findsOneWidget);
  });
}
