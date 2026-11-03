import 'package:flutter_test/flutter_test.dart';
import 'package:gojek_polinela/main.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GojekPolinelaApp());
    expect(find.byType(GojekPolinelaApp), findsOneWidget);
  });
}
