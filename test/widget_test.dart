// Backend-integration (Auth & Profile layer) smoke test.
//
// AuthController now talks to a live Supabase project (network I/O,
// SharedPreferences-backed session storage), so it can no longer be driven
// headlessly the way the Phase-2 mock controller was. This test only checks
// what's true without a backend connection: the initial (signed-out) state
// shape. Full sign-in/sign-up/onboarding flows are verified by a `flutter
// run` walkthrough against the live project (see developer.log).

import 'package:flutter_test/flutter_test.dart';

import 'package:love_me/features/auth/auth_controller.dart';

void main() {
  test('AuthState defaults to signed out with profile incomplete', () {
    const state = AuthState();
    expect(state.signedIn, isFalse);
    expect(state.profileComplete, isFalse);
    expect(state.loading, isFalse);
  });

  test('AuthState.copyWith clearSession drops the session', () {
    const state = AuthState(profileComplete: true);
    final cleared = state.copyWith(clearSession: true);
    expect(cleared.session, isNull);
    expect(cleared.signedIn, isFalse);
  });
}
