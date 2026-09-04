import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartbiz_ai/main.dart';

void main() {
  testWidgets('SmartBiz AI app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartBizApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(SmartBizApp), findsOneWidget);
  });
}
