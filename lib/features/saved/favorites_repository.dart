import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/events/event_logger.dart';
import '../discovery/discovery_repository.dart';
import '../discovery/models.dart';

/// Favorite: PK (user_id, property_id) menjamin 1 baris meski dobel tap
/// <500 ms (AC-SAVED-02) — duplikat ditangkap dan dianggap sukses.
class FavoritesRepository {
  FavoritesRepository(this._db);

  final SupabaseClient _db;

  Future<List<String>> ids() async {
    final rows = await _db
        .from('favorites')
        .select('property_id')
        .order('created_at', ascending: false);
    return rows.map((r) => r['property_id'] as String).toList();
  }

  /// true bila berakhir tersimpan (save), false bila dihapus.
  Future<bool> toggle(String propertyId) async {
    final uid = _db.auth.currentUser!.id;
    final existing = await _db
        .from('favorites')
        .select('property_id')
        .eq('user_id', uid)
        .eq('property_id', propertyId)
        .maybeSingle();
    if (existing != null) {
      await _db
          .from('favorites')
          .delete()
          .eq('user_id', uid)
          .eq('property_id', propertyId);
      return false;
    }
    try {
      await _db.from('favorites').insert({
        'user_id': uid,
        'property_id': propertyId,
      });
    } on PostgrestException catch (e) {
      // duplikat (race dua tap) = sudah tersimpan
      if (e.code != '23505') rethrow;
    }
    return true;
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(Supabase.instance.client),
);

/// Daftar id favorit (urut terbaru). Invalidate setelah toggle.
final favoriteIdsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(favoritesRepositoryProvider).ids(),
);

/// Ringkasan properti favorit; availability di-refresh dari server saat
/// layar/simpan ulang dibuka (FR-SAVED-01).
final favoriteSummariesProvider = FutureProvider<List<PropertySummary>>((
  ref,
) async {
  final ids = await ref.watch(favoriteIdsProvider.future);
  if (ids.isEmpty) return const [];
  final all = await ref.watch(discoveryProvider).propertiesByIds(ids);
  final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  final sorted = [...all]
    ..sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
  return sorted;
});

/// Toggle + log event; dipakai tombol hati di detail/saved.
Future<bool> toggleFavorite(WidgetRef ref, String propertyId) async {
  final saved = await ref.read(favoritesRepositoryProvider).toggle(propertyId);
  ref
      .read(eventLoggerProvider)
      .log(saved ? 'property_save' : 'property_unsave', propertyId: propertyId);
  ref.invalidate(favoriteIdsProvider);
  ref.invalidate(favoriteSummariesProvider);
  return saved;
}
