import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Logging event interaksi (taxonomy cp02; AC-PRIV-03: consent gate di server —
/// insert tanpa consent ditolak RLS dan error ditelan, logging tidak boleh
/// menggagalkan UX).
///
/// `event_weight` memakai design parameter cp02 §ML — bukan probabilitas.
final eventLoggerProvider = Provider<EventLogger>((ref) => EventLogger());

class EventLogger {
  static const weights = <String, double>{
    'recommendation_impression': 0,
    'property_view': 1,
    'property_save': 3,
    'property_unsave': 0,
    'compare_add': 2,
    'filter_apply': 1,
    'map_search_area': 1,
    'near_me_search': 1,
    'tenancy_request': 5,
    'tenancy_accepted': 8,
  };

  void log(
    String eventType, {
    String? propertyId,
    String source = 'app',
    Map<String, dynamic>? metadata,
  }) {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    final weight = weights[eventType];
    unawaited(
      client
          .from('interactions')
          .insert({
            'event_type': eventType,
            'source': source,
            'property_id': ?propertyId,
            'event_weight': ?weight,
            'metadata': ?metadata,
          })
          .then<void>((_) {}, onError: (_) {}),
    );
  }
}
