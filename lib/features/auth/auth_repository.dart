import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthResult {
  const AuthResult({this.needsEmailConfirmation = false});

  final bool needsEmailConfirmation;
}

class AuthRepository {
  AuthRepository(this._db);

  final SupabaseClient _db;

  Stream<AuthState> get authStates => _db.auth.onAuthStateChange;
  User? get currentUser => _db.auth.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      _db.auth.signInWithPassword(email: email, password: password);

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role, // seeker | owner (super_admin tidak dari client)
    required bool acceptTos,
    required bool dataConsent,
  }) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
        'tos_version': 'v1.0',
        'tos_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'data_consent': dataConsent ? 'true' : 'false',
      },
    );
    return AuthResult(needsEmailConfirmation: res.session == null);
  }

  Future<void> signOut() => _db.auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(Supabase.instance.client),
);

/// Perubahan sesi → reaktivitas router & gate.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStates,
);

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authRepositoryProvider).currentUser,
);

class AppProfile {
  const AppProfile({
    required this.id,
    required this.role,
    required this.fullName,
    this.tosVersion = '',
    this.hasDataConsent = false,
  });

  final String id;
  final String role;
  final String fullName;
  final String tosVersion;
  final bool hasDataConsent;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'super_admin';

  factory AppProfile.fromJson(Map<String, dynamic> json) => AppProfile(
    id: json['id'] as String,
    role: json['role'] as String,
    fullName: json['full_name'] as String? ?? '',
    tosVersion: json['tos_version'] as String? ?? '',
    hasDataConsent: json['data_consent_at'] != null,
  );
}

/// Role/identitas dari DB (source of truth), bukan user_metadata.
final currentProfileProvider = FutureProvider<AppProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final data = await Supabase.instance.client
      .from('profiles')
      .select('id, role, full_name, tos_version, data_consent_at')
      .eq('id', user.id)
      .maybeSingle();
  return data == null ? null : AppProfile.fromJson(data);
});
