import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import 'discovery_repository.dart';
import 'models.dart';

/// State pencarian bersama list & map (satu sumber hasil, AC-MAP-01);
/// state kamera peta terpisah di [mapViewportProvider].
final searchFiltersProvider = StateProvider<Map<String, dynamic>>(
  (ref) => const {'available_only': true},
);

final searchSortProvider = StateProvider<String>((ref) => 'relevansi');

const _searchCacheKey = 'search_cache_v1';

String _cacheToken(Map<String, dynamic> filters, String sort) =>
    jsonEncode({'f': filters, 's': sort});

class SearchNotifier extends AsyncNotifier<SearchResult> {
  @override
  Future<SearchResult> build() async {
    final filters = ref.watch(searchFiltersProvider);
    final sort = ref.watch(searchSortProvider);
    try {
      final res = await ref
          .read(discoveryProvider)
          .search(filters: filters, sort: sort, page: 1);
      unawaited(_saveCache(filters, sort, res));
      return res;
    } catch (_) {
      // Gagal RPC/offline → cache terakhir bila filter masih sama
      // (AC-OFF-01); kalau tidak ada, lempar error normal (state error).
      final cached = await _loadCache(filters, sort);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.fromCache || state.isLoading) {
      return;
    }
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

  Future<void> _saveCache(
    Map<String, dynamic> filters,
    String sort,
    SearchResult res,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _searchCacheKey,
        jsonEncode({
          'token': _cacheToken(filters, sort),
          'items': [for (final i in res.items) i.toJson()],
        }),
      );
    } catch (_) {
      // Cache adalah optimasi; gagal menulis tidak mengganggu UI.
    }
  }

  Future<SearchResult?> _loadCache(
    Map<String, dynamic> filters,
    String sort,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_searchCacheKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['token'] != _cacheToken(filters, sort)) return null;
      final items = ((map['items'] as List?) ?? const [])
          .map((e) => PropertySummary.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isEmpty) return null;
      return SearchResult(
        items: items,
        page: 1,
        pageSize: 20,
        hasMore: false,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }
}

final searchResultProvider =
    AsyncNotifierProvider<SearchNotifier, SearchResult>(SearchNotifier.new);

/// Hasil query viewport peta (bbox terakhir) — terpisah dari filter state
/// namun sinkron (AGENTS §9.6). [items] null = pakai hasil list bersama
/// (jumlah marker == jumlah list, AC-MAP-01).
class MapViewportState {
  const MapViewportState({
    this.items,
    this.loading = false,
    this.dirty = false,
    this.error,
  });

  final List<PropertySummary>? items;
  final bool loading;
  final bool dirty;
  final String? error;

  MapViewportState copyWith({
    List<PropertySummary>? items,
    bool? loading,
    bool? dirty,
    String? error,
    bool clearItems = false,
    bool clearError = false,
  }) => MapViewportState(
    items: clearItems ? null : (items ?? this.items),
    loading: loading ?? this.loading,
    dirty: dirty ?? this.dirty,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Debounce 300 ms per jeda gesture (FR-MAP-02 / AC-MAP-02): tepat 1 query
/// per berhenti. Query memakai bbox = viewport saat ini (FR-MAP-01).
class MapViewportController extends Notifier<MapViewportState> {
  Timer? _debounce;
  List<double>? _pendingBounds;
  List<double>? _queriedBounds;
  var _seq = 0;

  /// Flag per-build: false saat provider rebuild/final dispose — query telat
  /// tidak boleh menyentuh state setelah itu.
  var _alive = [true];

  @override
  MapViewportState build() {
    // Filter/sort berubah → kembali ke hasil list bersama (sinkron).
    ref.watch(searchFiltersProvider);
    ref.watch(searchSortProvider);
    _debounce?.cancel();
    _seq++;
    _pendingBounds = null;
    _queriedBounds = null;
    _alive = [true];
    final flag = _alive;
    ref.onDispose(() {
      flag[0] = false;
      _debounce?.cancel();
    });
    return const MapViewportState();
  }

  bool _sameBounds(List<double>? a, List<double>? b) {
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  /// Gesture peta berhenti → debounce 300 ms lalu query.
  void cameraStopped(List<double> bounds) {
    if (_sameBounds(bounds, _queriedBounds) ||
        _sameBounds(bounds, _pendingBounds)) {
      return;
    }
    _pendingBounds = bounds;
    if (!state.dirty) state = state.copyWith(dirty: true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _searchNow);
  }

  /// Query segera (tombol "Cari di area ini", pemilihan kampus, near me).
  void searchBounds(List<double> bounds) {
    _debounce?.cancel();
    if (_sameBounds(bounds, _queriedBounds)) return;
    _pendingBounds = bounds;
    _searchNow();
  }

  void _searchNow() {
    _debounce?.cancel();
    final b = _pendingBounds;
    if (b == null || _sameBounds(b, _queriedBounds)) return;
    unawaited(_run(b));
  }

  Future<void> _run(List<double> bounds) async {
    final seq = ++_seq;
    final alive = _alive;
    state = state.copyWith(loading: true, dirty: false, clearError: true);
    try {
      final res = await ref
          .read(discoveryProvider)
          .search(
            filters: ref.read(searchFiltersProvider),
            sort: ref.read(searchSortProvider),
            bbox: bounds,
          );
      if (!alive[0] || seq != _seq) return;
      _queriedBounds = bounds;
      _pendingBounds = null;
      state = MapViewportState(items: res.items);
    } catch (_) {
      if (!alive[0] || seq != _seq) return;
      // Tidak ada cache viewport (layar peta bukan layar utama) → tampilkan
      // hasil list sementara + tombol coba lagi (dirty).
      state = MapViewportState(dirty: true, error: 'gagal');
    }
  }
}

final mapViewportProvider =
    NotifierProvider<MapViewportController, MapViewportState>(
      MapViewportController.new,
    );

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
