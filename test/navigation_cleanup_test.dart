import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/profile/profile_screen.dart';
import 'package:mobile/widgets/main_navigation.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  FakeAuthProvider({this.role = 'donatur'});

  final String role;
  bool logoutCalled = false;

  @override
  String get userRole => role;

  @override
  bool get isAdmin => role == 'admin_panti';

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  String get userName => isAdmin ? 'Admin Panti' : 'Donatur Test';

  @override
  String get userEmail => 'test@asuhkita.app';

  @override
  String get userId => 'usr_test_1';

  @override
  bool get isBiometricAvailable => false;

  @override
  bool get isBiometricEnabled => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> logout({bool notifyServer = true}) async {
    logoutCalled = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Removed features are absent and Logout is moved to ProfileScreen',
    (tester) async {
      final auth = FakeAuthProvider(role: 'donatur');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: MainNavigation()),
        ),
      );
      await tester.pump();

      expect(find.text('Berita Panti'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Sponsori Anak'), findsNothing);
      expect(find.text('Berita Perkembangan Anak'), findsNothing);
      expect(find.text('Sensor & Game'), findsNothing);
      expect(find.text('Peta Panti LBS'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.text('Ruang Kasih'),
        ),
        findsNothing,
      );

      expect(find.text('Saran & Kesan'), findsNothing);
      expect(find.text('Keluar'), findsNothing);
      expect(find.text('Verifikasi Sertifikat'), findsNothing);
      expect(find.text('100% SHA-256'), findsNothing);
      expect(find.text('Data Offline & Online'), findsNothing);
      expect(find.text('Kotak Amal IoT'), findsNothing);
      expect(find.text('IoT Panti'), findsNothing);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();

      final logoutFinder = find.text('Keluar dari Akun');
      await tester.scrollUntilVisible(
        logoutFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(logoutFinder, findsOneWidget);

      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Keluar'), findsOneWidget);
    },
  );
}
