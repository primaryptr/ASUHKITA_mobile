import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mobile/core/dio_client.dart';
import 'package:mobile/data/local_db.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/reports/progress_feed_screen.dart';
import 'package:mobile/widgets/main_navigation.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  _FakeAuthProvider({this.role = 'donatur'});
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
  String get userName => 'Donatur Uji';

  @override
  String get userEmail => 'donatur@asuhkita.app';

  @override
  String get userId => 'usr-demo-001';

  @override
  bool get isBiometricAvailable => false;

  @override
  bool get isBiometricEnabled => false;

  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReportDb implements Database {
  _FakeReportDb(this.reports);
  final List<Map<String, Object?>> reports;

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
    if (table == 'cached_progress_reports') return reports;
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    LocalDatabase.setDatabaseForTest(null);
  });

  testWidgets('ProgressFeedScreen renders reports, filter chips, and empty state', (tester) async {
    LocalDatabase.setDatabaseForTest(_FakeReportDb([
      {
        'id': 'rep-1',
        'child_id': 'ch-001',
        'child_alias': 'Bintang',
        'title': 'Juara Lomba Sains',
        'category': 'Prestasi',
        'period': '2026-11',
        'summary': 'Bintang memenangkan lomba IPA kecamatan.',
        'evidence_url': '',
        'author_name': 'Ibu Sari',
        'created_at': '2026-11-13T08:00:00Z',
      }
    ]));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuthProvider(),
        child: MaterialApp(
          home: ProgressFeedScreen(
            initialReports: const [
              {
                'id': 'rep-1',
                'child_id': 'ch-001',
                'child_alias': 'Bintang',
                'title': 'Juara Lomba Sains',
                'category': 'Prestasi',
                'period': '2026-11',
                'summary': 'Bintang memenangkan lomba IPA kecamatan.',
                'evidence_url': '',
                'author_name': 'Ibu Sari',
                'created_at': '2026-11-13T08:00:00Z',
              }
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Semua Anak'), findsOneWidget);
    expect(find.text('Anak Asuh Saya'), findsOneWidget);
    expect(find.text('Juara Lomba Sains'), findsOneWidget);
    expect(find.text('Prestasi'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Bintang'), findsAtLeastNWidgets(1));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuthProvider(),
        child: const MaterialApp(
          home: ProgressFeedScreen(initialReports: []),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Belum ada kabar perkembangan'), findsOneWidget);
  });

  testWidgets('MainNavigation for donatur shows exact 5 Opsi-1 tabs', (tester) async {
    DioClient().dio.options.connectTimeout = const Duration(milliseconds: 50);
    DioClient().dio.options.receiveTimeout = const Duration(milliseconds: 50);
    LocalDatabase.setDatabaseForTest(_FakeReportDb(const []));
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuthProvider(role: 'donatur'),
        child: const MaterialApp(home: MainNavigation()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final navFinder = find.byType(BottomNavigationBar);
    expect(navFinder, findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Beranda')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Sponsor')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Kabar Anak')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Ruang Kasih')), findsOneWidget);
    expect(find.descendant(of: navFinder, matching: find.text('Profil')), findsOneWidget);

    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  });
}
