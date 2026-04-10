import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unisharesync_mobile_app/core/config/app_secrets.dart';
import 'package:unisharesync_mobile_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: AppSecrets.supabaseUrl,
      anonKey: AppSecrets.supabaseAnonKey,
    );
  });

  testWidgets('Splash screen renders app name', (WidgetTester tester) async {
    await tester.pumpWidget(const UniShareSyncApp());
    await tester.pump();

    expect(find.text('UniShareSync'), findsOneWidget);

    // Let splash delayed navigation finish to avoid pending timer at test teardown.
    await tester.pump(const Duration(seconds: 4));
  });
}
