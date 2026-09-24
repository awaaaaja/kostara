import 'package:flutter_test/flutter_test.dart';

import 'package:kostara/main.dart';

void main() {
  testWidgets('app boots without Supabase configuration', (tester) async {
    await tester.pumpWidget(const KostaraApp());

    expect(find.text('KOSTARA'), findsWidgets);
    expect(find.textContaining('Foundation ready'), findsOneWidget);
  });
}
