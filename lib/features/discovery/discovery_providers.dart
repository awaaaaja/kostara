import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import 'discovery_repository.dart';
import 'models.dart';

/// State pencarian bersama list & map (satu sumber hasil, AC-MAP-01);
/// state kamera peta terpisah di ExploreMapScreen.
final searchFiltersProvider = StateProvider<Map<String, dynamic>>(
  (ref) => const {'available_only': true},
);

final searchSortProvider = StateProvider<String>((ref) => 'relevansi');

class SearchNotifier extends AsyncNotifier<SearchResult> {
  @override
  Future<SearchResult> build() {
    final filters = ref.watch(searchFiltersProvider);
    final sort = ref.watch(searchSortProvider);
    return ref
        .read(discoveryProvider)
        .search(filters: filters, sort: sort, page: 1);
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || state.isLoading) return;
    final res = await ref
        .read(discoveryProvider)
        .search(
          filters: ref.read(searchFiltersProvider),
          sort: ref.read(searchSortProvider),
          page: cur.page + 1,
        );
    state = AsyncData(
      SearchResult(
        items: [...cur.items, ...res.items],
        page: res.page,
        pageSize: res.pageSize,
        hasMore: res.hasMore,
      ),
    );
  }
}

final searchResultProvider =
    AsyncNotifierProvider<SearchNotifier, SearchResult>(SearchNotifier.new);

final campusesProvider = FutureProvider<List<Campus>>(
  (ref) => ref.watch(discoveryProvider).allCampuses(),
);

/// Onboarding gate: baris user_preferences = onboarding selesai.
final hasPrefsProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final row = await Supabase.instance.client
      .from('user_preferences')
      .select('user_id')
      .eq('user_id', user.id)
      .maybeSingle();
  return row != null;
});
