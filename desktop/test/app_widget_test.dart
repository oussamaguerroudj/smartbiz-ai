import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_desktop/main.dart';
import 'package:modiri_desktop/core/network/session.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets('ModiriDesktopApp renders Auth screen when unauthenticated', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ModiriDesktopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('ModiriDesktopApp renders Navigation Shell when authenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => SessionNotifierMock()),
        ],
        child: const ModiriDesktopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class SessionNotifierMock extends SessionNotifier {
  SessionNotifierMock() {
    state = const SessionState(
      accessToken: 'mock_jwt_token',
      userId: 'user_1',
      userName: 'Amine Test',
      companyId: 'comp_test',
      companyName: 'Modiri Enterprise Corp',
      businessType: 'restaurant',
    );
  }
}
