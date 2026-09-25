import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kontrak API nyata (anon key dari Aman.md — git-ignored).
/// Lompati otomatis bila Aman.md tidak ada (mis. CI tanpa kredensial).
(String?, String?) _config() {
  final file = File('Aman.md');
  if (!file.existsSync()) return (null, null);
  final text = file.readAsStringSync();
  final anon = RegExp(r'ANON_PUBLIC:\s*(\S+)').firstMatch(text)?.group(1);
  final ref = RegExp(r'PROJECT_REF:\s*(\S+)').firstMatch(text)?.group(1);
  if (anon == null || ref == null) return (null, null);
  return (anon, 'https://$ref.supabase.co');
}

void main() {
  final (anon, url) = _config();
  final hasCreds = anon != null && url != null;
  final skip = hasCreds ? false : 'Aman.md tidak tersedia di environment ini';

  setUpAll(() async {
    if (!hasCreds) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test memasang HttpClient mock yang memblokir jaringan nyata;
    // kontrak API butuh request asli (anon, read-only).
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: url, publishableKey: anon);
  });

  group('CP-03B contract (anon, RLS invoker)', () {
    test(
      'search_properties: bentuk paged + item non-kosong',
      skip: skip,
      () async {
        final data =
            await Supabase.instance.client.rpc(
                  'search_properties',
                  params: {'p_page_size': 5},
                )
                as Map<String, dynamic>;
        expect(data['page'], 1);
        expect(data['page_size'], 5);
        expect(data['items'], isA<List>());
        final items = data['items'] as List;
        expect(items, isNotEmpty);
        expect(items.length, lessThanOrEqualTo(5));
        final first = items.first as Map<String, dynamic>;
        expect(first['id'], isA<String>());
        expect(first['name'], isA<String>());
        expect(data['has_more'], isA<bool>());
      },
    );

    test(
      'search_properties: sort tidak valid ditolak 22023',
      skip: skip,
      () async {
        await expectLater(
          Supabase.instance.client.rpc(
            'search_properties',
            params: {'p_sort': 'acak'},
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('campus_suggestions: ilike kampus', skip: skip, () async {
      final data =
          await Supabase.instance.client.rpc(
                'campus_suggestions',
                params: {'p_q': 'unand'},
              )
              as Map<String, dynamic>;
      final items = data['items'] as List;
      expect(items, isNotEmpty);
      expect('${items.first['name']}'.toLowerCase(), contains('unand'));
    });

    test(
      'feed_recommendations anon: model_name valid + p_limit dihormati',
      skip: skip,
      () async {
        final data =
            await Supabase.instance.client.rpc(
                  'feed_recommendations',
                  params: {'p_limit': 3},
                )
                as Map<String, dynamic>;
        final items = data['items'] as List;
        expect(items.length, lessThanOrEqualTo(3));
        // Model aktif bila ada ('hybrid'/dst) atau fallback kontrak
        // 'baseline-fallback' (AC-REC-03) — keduanya non-kosong.
        expect(
          '${data['model_name']}',
          anyOf(equals('baseline-fallback'), isNotEmpty),
        );
        for (final it in items) {
          final score = (it as Map<String, dynamic>)['score'];
          expect(score, inInclusiveRange(0, 100));
        }
      },
    );
  });
}
