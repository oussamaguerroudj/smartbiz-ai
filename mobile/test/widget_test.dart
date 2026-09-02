import 'package:flutter_test/flutter_test.dart';

import 'package:smartbiz_ai/main.dart';

void main() {
  testWidgets('SmartBiz AI app builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartBizApp());

    expect(find.byType(SmartBizApp), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
  });
}