import 'package:flutter_test/flutter_test.dart';

import 'package:kostara/features/compare/compare_state.dart';

void main() {
  group('CompareIds (AC-CMP-01: maksimal 3)', () {
    test('add sampai 3 lalu tolak dengan pesan', () {
      final c = CompareIds();
      expect(c.add('a'), isNull);
      expect(c.add('b'), isNull);
      expect(c.add('c'), isNull);
      expect(c.state, ['a', 'b', 'c']);
      expect(c.add('d'), 'maksimal 3');
      expect(c.state, ['a', 'b', 'c']);
    });

    test('duplikat tidak menambah, tidak error', () {
      final c = CompareIds();
      expect(c.add('a'), isNull);
      expect(c.add('a'), isNull);
      expect(c.state, ['a']);
    });

    test('remove membuka slot lagi', () {
      final c = CompareIds();
      for (final id in ['a', 'b', 'c']) {
        c.add(id);
      }
      c.remove('b');
      expect(c.contains('b'), isFalse);
      expect(c.add('d'), isNull);
      expect(c.state, ['a', 'c', 'd']);
    });
  });
}
