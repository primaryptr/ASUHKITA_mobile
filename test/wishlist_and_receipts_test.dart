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
import 'package:mobile/features/donation/donation_form_screen.dart';
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

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  @override
  String get userRole => 'donatur';

  @override
  bool get isAdmin => false;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  String get userName => 'Donatur Uji';

  @override
  String get userEmail => 'donor@asuhkita.app';

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

class _FakeWishlistDb implements Database {
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
    if (table == 'cached_wishlists') {
      return [
        {
          'id': 'wl-1',
          'child_id': 'ch-001',
          'child_alias': 'Bintang',
          'item_name': 'Sepatu Sekolah',
          'estimated_idr': 150000.0,
          'status': 'open',
          'funded_by_user_id': '',
          'funded_by_name': '',
          'receipt_url': '',
          'created_at': '2026-11-13T08:00:00Z',
        },
      ];
    }
    if (table == 'receipts') {
      return [
        {
          'id': 'rec-1',
          'child_name': 'Bintang',
          'title': 'Pembelian Paket Buku',
          'amount': 125000.0,
          'date': '2026-11-12',
          'receipt_image': '',
          'description': 'Toko Buku Gramedia Mataram',
          'hash': '0xabc',
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
    SharedPreferences.setMockInitialValues({
      'asuhkita_exchange_rates': '{"IDR":1.0,"USD":15850.0,"SGD":11800.0,"EUR":17200.0,"SAR":4220.0}',
      'asuhkita_exchange_rates_ts': DateTime.now().millisecondsSinceEpoch,
    });
    origAdapter = DioClient().dio.httpClientAdapter;
    DioClient().dio.httpClientAdapter = _OfflineAdapter();
    LocalDatabase.setDatabaseForTest(_FakeWishlistDb());
  });

  tearDown(() {
    DioClient().dio.httpClientAdapter = origAdapter;
    LocalDatabase.setDatabaseForTest(null);
  });

  testWidgets('ChildDetailScreen displays wishlist section and disbursement receipts', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(),
        child: const MaterialApp(
          home: ChildDetailScreen(
            childData: {
              'id': 'ch-001',
              'alias': 'Bintang',
              'age': 10,
              'need_category': 'Pendidikan',
              'target': 500000,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Kebutuhan Spesifik Mendesak'), findsOneWidget);
    expect(find.text('Sepatu Sekolah'), findsOneWidget);
    expect(find.text('Penuhi Kebutuhan Ini'), findsOneWidget);
    expect(find.textContaining('Jejak Penyaluran Dana'), findsOneWidget);
    expect(find.text('Pembelian Paket Buku'), findsOneWidget);
  });

  testWidgets('DonationFormScreen prefills estimated_idr from wishlistItem', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(),
        child: const MaterialApp(
          home: DonationFormScreen(
            childData: {'id': 'ch-001', 'alias': 'Bintang'},
            packageData: {'id': 'pkg_wishlist', 'name': 'Wishlist: Sepatu Sekolah', 'monthly_idr': 150000},
            wishlistItem: {
              'id': 'wl-1',
              'item_name': 'Sepatu Sekolah',
              'estimated_idr': 150000,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('150000'), findsOneWidget);
  });

  testWidgets('DonationFormScreen prefills nominal otomatis sesuai pilihan paket sponsor', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuth(),
        child: const MaterialApp(
          home: ChildDetailScreen(
            childData: {
              'id': 'ch-001',
              'alias': 'Bintang',
              'age': 10,
              'need_category': 'Pendidikan',
              'target': 500000,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final komprehensifCard = find.text('Paket Asuh Komprehensif');
    await tester.scrollUntilVisible(komprehensifCard, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(komprehensifCard);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lanjut ke Form Donasi & Sertifikat'));
    await tester.pumpAndSettle();

    expect(find.text('Form Donasi & Kurs'), findsOneWidget);
    final amountField = find.widgetWithText(TextField, 'Nominal (IDR) *');
    final tf = tester.widget<TextField>(amountField);
    expect(tf.controller?.text, equals('400000'));
    expect(find.text('Rp 400.000'), findsOneWidget);
  });
}
