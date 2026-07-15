import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/supabase_config.dart';
import '../../core/devices/device_session_registrar.dart';
import '../../core/notifications/fcm_service.dart';
import '../../core/presence/presence_service.dart';
import '../../shared/data/repositories.dart';
import '../discover/discover_providers.dart';

/// Wraps the live Supabase auth session + the user's `profiles` row
/// completeness, since routing decisions need both.
class AuthState {
  const AuthState({
    this.session,
    this.profileComplete = false,
    this.loading = false,
    this.error,
    this.bootstrapped = false,
  });

  final sb.Session? session;
  final bool profileComplete;
  final bool loading;
  final String? error;

  /// `false` until the initial session-restore + `profile_complete` fetch has
  /// resolved. The router must not make redirect decisions before this flips
  /// to `true`, otherwise a restored-but-not-yet-checked session gets routed
  /// to the onboarding wizard by mistake.
  final bool bootstrapped;

  bool get signedIn => session != null;

  AuthState copyWith({
    sb.Session? session,
    bool clearSession = false,
    bool? profileComplete,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? bootstrapped,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      profileComplete: profileComplete ?? this.profileComplete,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      bootstrapped: bootstrapped ?? this.bootstrapped,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  AuthState build() {
    final current = _client.auth.currentSession;
    ref.listen(_authStateChangesProvider, (previous, next) {
      next.whenData(_onAuthEvent);
    });

    // Restore the persisted session synchronously, then load its
    // `profile_complete` flag asynchronously before marking bootstrap done.
    if (current != null) {
      _bootstrapSession(current.user.id);
      return AuthState(session: current);
    }
    return const AuthState(bootstrapped: true);
  }

  /// Reacts to Supabase auth-state changes (token refresh, OAuth sign-in,
  /// sign-out, **and a deferred sign-up confirmation** — see
  /// `BACKEND_CONFIRM_EMAIL_HANDOFF.md`: once "Confirm email" is on,
  /// `signUp()` returns no session, and the real session only arrives here,
  /// asynchronously, after the user taps the emailed link). When a session
  /// appears we (re)load `profile_complete`, creating the `profiles` row
  /// first if this is that user's first-ever session (nothing to load yet).
  Future<void> _onAuthEvent(sb.AuthState event) async {
    final session = event.session;
    if (session == null) {
      state = state.copyWith(
        clearSession: true,
        profileComplete: false,
        bootstrapped: true,
      );
      return;
    }
    // Only refetch on a genuinely new user id to avoid clobbering an
    // already-known `profileComplete` on routine token refreshes.
    final isNewUser = state.session?.user.id != session.user.id;
    if (isNewUser) {
      await _ensureProfileRowExists(session.user);
      _onSignedIn();
    }
    final complete = isNewUser
        ? await _fetchProfileComplete(session.user.id)
        : state.profileComplete;
    state = state.copyWith(
      session: session,
      profileComplete: complete,
      bootstrapped: true,
    );
  }

  /// Starts presence tracking + registers this device's `active_sessions`
  /// row. Called from every path that lands on a real session: a restored
  /// cold-start session, `signIn`/`signUp` returning a session immediately,
  /// and the deferred-confirmation path in [_onAuthEvent].
  void _onSignedIn() {
    ref.read(presenceServiceProvider).start();
    unawaited(
      ref.read(deviceSessionRegistrarProvider).registerForCurrentUser(),
    );
  }

  /// Creates the minimal `profiles` (+ `notification_preferences`) row the
  /// first time a session appears for [user] — a no-op if it already
  /// exists. Covers both timings: `signUp()` returning a session immediately
  /// (confirm-email off, current default) and a session only arriving later
  /// via [_onAuthEvent] once the user confirms via the emailed link
  /// (confirm-email on, once backend flips it).
  Future<void> _ensureProfileRowExists(sb.User user) async {
    final existing = await _client
        .from('profiles')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (existing != null) return;
    await _client.from('profiles').insert({
      'user_id': user.id,
      'name': '',
      'city': '',
      'country': '',
      'ringtone': '',
    });
    await _client.from('notification_preferences').insert({'user_id': user.id});
  }

  /// One-shot load of `profile_complete` for a restored session on cold start.
  Future<void> _bootstrapSession(String userId) async {
    _onSignedIn();
    final complete = await _fetchProfileComplete(userId);
    // Guard against the notifier being disposed / re-signed mid-fetch.
    if (state.session?.user.id != userId) return;
    state = state.copyWith(profileComplete: complete, bootstrapped: true);
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final complete = await _fetchProfileComplete(res.user!.id);
      state = state.copyWith(
        session: res.session,
        profileComplete: complete,
        loading: false,
        bootstrapped: true,
      );
      _invalidateUserScopedProviders();
      _onSignedIn();
      unawaited(FcmService.instance.registerTokenForCurrentUser());
    } on sb.AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      rethrow;
    }
  }

  /// New user sign-up. If Supabase returns a session immediately
  /// (confirm-email off — current default), creates the `profiles` row
  /// right here and lands on onboarding. If Supabase returns no session
  /// (confirm-email on), there is nothing to create yet — the real session,
  /// and the profile-row creation that depends on it, arrives later via
  /// [_onAuthEvent] once the user taps the emailed confirmation link. Either
  /// way the caller should route to [RoutePaths.emailVerified] whenever
  /// `res.session` comes back null.
  Future<sb.AuthResponse> signUp(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: SupabaseConfig.emailRedirectUrl,
      );
      if (res.session != null) {
        await _ensureProfileRowExists(res.user!);
        _invalidateUserScopedProviders();
        _onSignedIn();
        unawaited(FcmService.instance.registerTokenForCurrentUser());
      }
      state = state.copyWith(
        session: res.session,
        profileComplete: false,
        loading: false,
        bootstrapped: true,
      );
      return res;
    } on sb.AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      rethrow;
    }
  }

  /// Resends the confirmation email for a pending sign-up.
  Future<void> resendConfirmationEmail(String email) => _client.auth.resend(
    type: sb.OtpType.signup,
    email: email,
    emailRedirectTo: SupabaseConfig.emailRedirectUrl,
  );

  Future<void> signInWithGoogle() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _client.auth.signInWithOAuth(sb.OAuthProvider.google);
      // Session arrives asynchronously via the auth-state-change stream.
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> requestPasswordReset(String email) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      state = state.copyWith(error: e.message);
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// Called at the end of the onboarding wizard (after the profile PATCH
  /// that sets `profile_complete: true` server-side has succeeded).
  void markProfileComplete() => state = state.copyWith(profileComplete: true);

  Future<void> signOut() async {
    // Must run before signOut() clears the session — setOnline(false) needs
    // auth.uid() to still resolve for the RLS-scoped upsert.
    ref.read(presenceServiceProvider).stop();
    ref.read(deviceSessionRegistrarProvider).clearOnSignOut();
    await _client.auth.signOut();
    state = const AuthState(bootstrapped: true);
    _invalidateUserScopedProviders();
  }

  /// Permanently deletes the current user's account by invoking the proposed
  /// `delete-account` Edge Function (see `BACKEND_ATIER_HANDOFF.md` §3) —
  /// that function is responsible for removing/anonymizing every row owned
  /// by this user (profile, photos, matches, messages, etc.) with the
  /// service-role key, then deleting the `auth.users` row itself (which the
  /// client can never do — it only holds the anon key).
  ///
  /// On success, tears down local state via the same path as [signOut] so
  /// there is exactly one sign-out/session-teardown implementation.
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    await signOut();
  }

  Future<bool> _fetchProfileComplete(String userId) async {
    final row = await _client
        .from('profiles')
        .select('profile_complete')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['profile_complete'] as bool? ?? false;
  }

  /// Every cached provider that reads Supabase directly (not derived from
  /// [authControllerProvider]'s own state) must be invalidated on sign-out
  /// AND sign-in. Otherwise switching accounts leaves the UI showing the
  /// previous user's profile/feed/matches/etc. until something else happens
  /// to invalidate them — Riverpod has no reason to recompute a `FutureProvider`
  /// just because the underlying Supabase session changed underneath it.
  void _invalidateUserScopedProviders() {
    ref.invalidate(currentUserProvider);
    ref.invalidate(discoverFeedProvider);
    ref.invalidate(cardPhotosProvider);
    ref.invalidate(likedYouProvider);
    ref.invalidate(matchesProvider);
    ref.invalidate(myMatchRowsProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(conversationForPartnerProvider);
    ref.invalidate(messagesProvider);
    ref.invalidate(profileByIdProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationPreferencesProvider);
    ref.invalidate(safetyReportsProvider);
    ref.invalidate(devicesProvider);
    ref.invalidate(profilesByCountryProvider);
    ref.invalidate(myPhotosProvider);
    ref.invalidate(myStatsProvider);
    ref.invalidate(reactionsProvider);
    ref.invalidate(callHistoryProvider);
    ref.invalidate(isPremiumProvider);
    ref.invalidate(presenceForProvider);
  }
}

final _authStateChangesProvider = StreamProvider<sb.AuthState>(
  (ref) => sb.Supabase.instance.client.auth.onAuthStateChange,
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
