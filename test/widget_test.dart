import 'package:flutter_test/flutter_test.dart';

import 'package:unisharesync_mobile_app/main.dart';

void main() {
  testWidgets('Splash screen renders app name', (WidgetTester tester) async {
    await tester.pumpWidget(const UniShareSyncApp());

    expect(find.text('UniShareSync'), findsOneWidget);
  });
}
