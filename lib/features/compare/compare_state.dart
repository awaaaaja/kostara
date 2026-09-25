import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pilihan compare, state lokal sesuai cp03a §6 (maks 3 — AC-CMP-01).
class CompareIds extends StateNotifier<List<String>> {
  CompareIds() : super(const []);

  /// null = bertambah; String = pesan tolak (mis. 'maksimal 3').
  String? add(String id) {
    if (state.contains(id)) return null;
    if (state.length >= 3) return 'maksimal 3';
    state = [...state, id];
    return null;
  }

  void remove(String id) {
    state = state.where((e) => e != id).toList();
  }

  bool contains(String id) => state.contains(id);
}

final compareIdsProvider = StateNotifierProvider<CompareIds, List<String>>(
  (ref) => CompareIds(),
);
