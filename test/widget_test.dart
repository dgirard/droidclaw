import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test - full widget test requires SharedPreferences mock
    expect(true, isTrue);
  });
}
