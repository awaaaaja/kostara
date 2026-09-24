import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kostara/main.dart';

void main() {
  testWidgets('app boots without Supabase configuration', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KostaraApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Foundation ready'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
