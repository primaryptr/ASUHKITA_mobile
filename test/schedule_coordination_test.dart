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
import 'package:mobile/features/schedule/schedule_screen.dart';
import 'package:mobile/widgets/main_navigation.dart';

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

class _FakeScheduleDb implements Database {
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
    if (table == 'cached_donations') {
      return [
        {
          'id': 'don-1',
          'child_id': 'ch-001',
          'child_alias': 'Bintang',
          'donor_email': 'donor@asuhkita.app',
          'donor_name': 'Donatur Uji',
          'amount_idr': 250000,
        },
      ];
    }
    if (table == 'cached_schedules') {
      return [
        {
          'id': 'sch-1',
          'sponsorship_id': 'sp-1',
          'child_id': 'ch-001',
          'child_alias': 'Bintang',
          'donor_name': 'Donatur Uji',
          'scheduled_at_utc': '2026-11-20T10:00:00Z',
          'donor_timezone': 'WIB',
          'status': 'approved',
          'notes': 'Bincang belajar',
          'admin_notes': 'Siap jam 17:00 WIB',
          'created_at': '2026-11-13T08:00:00Z',
        },
      ];
    }
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
    LocalDatabase.setDatabaseForTest(_FakeScheduleDb());
  });

  tearDown(() {
    DioClient().dio.httpClientAdapter = origAdapter;
    LocalDatabase.setDatabaseForTest(null);
  });

  testWidgets('Admin ScheduleScreen shows 2 tabs and queue coordination items', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Antrean Jadwal Donatur'), findsOneWidget);
    expect(find.text('Pengingat Audit Kas'), findsOneWidget);
    expect(find.text('Bintang'), findsOneWidget);
    expect(find.text('Disetujui'), findsOneWidget);
  });

  testWidgets('Donor ScheduleScreen displays coordinated schedules with status badge', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'donatur'),
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Status Pengajuan Video Call'), findsOneWidget);
    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.textContaining('Siap jam 17:00 WIB'), findsOneWidget);
  });

  testWidgets('MainNavigation for admin_panti shows exact 5 Opsi-1 tabs with Jadwal', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(role: 'admin_panti'),
        child: const MaterialApp(home: MainNavigation()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final navFinder = find.byType(BottomNavigationBar);
    expect(navFinder, findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Beranda')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Kelola Panti')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Jadwal')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Ruang Kasih')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Profil')), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
