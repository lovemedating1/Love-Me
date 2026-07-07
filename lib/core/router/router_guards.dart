import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../constants/route_paths.dart';

/// Redirect logic for go_router, driven by [authControllerProvider] (a real
/// Supabase session + the user's `profiles.profile_complete` flag).
class RouterGuards {
  const RouterGuards(this._ref);

  final Ref _ref;

  static const _publicRoutes = {
    RoutePaths.auth,
    RoutePaths.emailVerified,
    RoutePaths.resetPassword,
    RoutePaths.terms,
    RoutePaths.privacy,
    RoutePaths.refund,
    RoutePaths.childSafety,
  };

  String? redirect(Object context, GoRouterState state) {
    final auth = _ref.read(authControllerProvider);
    final loc = state.matchedLocation;
    final isPublic = _publicRoutes.contains(loc);

    // Session restore + profile_complete fetch hasn't resolved yet on cold
    // start — don't redirect (especially not into onboarding) until we know
    // the real profile-complete state. The router re-runs this when the auth
    // controller flips `bootstrapped`.
    if (!auth.bootstrapped) {
      return null;
    }

    // Not signed in → allow public routes, otherwise go to /auth.
    if (!auth.signedIn) {
      return isPublic ? null : RoutePaths.auth;
    }

    // Signed in but profile incomplete → force the onboarding wizard.
    if (!auth.profileComplete && loc != RoutePaths.profileSetup) {
      return RoutePaths.profileSetup;
    }

    // Signed in + complete but sitting on an auth screen → send to Discover.
    if (auth.profileComplete &&
        (loc == RoutePaths.auth || loc == RoutePaths.profileSetup)) {
      return RoutePaths.discover;
    }
    return null;
  }
}

final routerGuardsProvider = Provider<RouterGuards>((ref) => RouterGuards(ref));
