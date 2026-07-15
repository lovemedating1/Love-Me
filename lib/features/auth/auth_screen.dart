import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_paths.dart';
import '../../core/settings/local_settings_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/info_modals.dart';
import 'auth_controller.dart';
import 'reset_password_dialog.dart';

/// 01 — AuthPage. Rebuilt for UI parity with the old app
/// (`old app ss/IMG-…-WA0042.jpg` Login, `…WA0047.jpg` Sign Up).
///
/// Deliberate differences from our old build, per UI_REBUILD_PLAN.md §0.4:
/// no surrounding Card, no confirm-password, no DOB/gender/country at sign-up
/// (they move to onboarding), no Google button, no legal footer. Password
/// minimum is **6** characters.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isSignUp = false;
  bool _obscure = true;
  bool _acceptTerms = false;
  bool _prefilledEmail = false;

  // Held as fields (not created in build) so they can be disposed.
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.privacy);

  @override
  void initState() {
    super.initState();
    // Old app pops the "90-Day Data Policy" modal once over the first view
    // of Login. Session-only (not persisted) — shown again on a fresh app
    // launch, matching the screenshot behavior rather than a one-time-ever
    // dismiss that would need its own SharedPreferences flag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) InfoModals.dataPolicy(context);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// "Remember me" is backed by [LocalSettings] (Settings screen's
  /// "Remember email after inactivity logout" toggle) rather than a
  /// separate local field — one real preference, not a decorative
  /// checkbox plus an unrelated setting.
  void _prefillRememberedEmail(LocalSettings settings) {
    if (_prefilledEmail) return;
    _prefilledEmail = true;
    if (settings.rememberEmail && settings.rememberedEmail != null) {
      _email.text = settings.rememberedEmail!;
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? AppColors.destructive : AppColors.pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSignUp && !_acceptTerms) {
      _toast('You must confirm you are 18+ and accept the terms', error: true);
      return;
    }

    final auth = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();
    try {
      if (_isSignUp) {
        final res = await auth.signUp(email, _password.text);
        if (res.session == null) {
          // Confirm-email is on server-side: no session yet — the user must
          // tap the emailed link first. Route to the "check your email"
          // screen instead of relying on the guard (there's no session to
          // trigger it, and we're staying on a public route either way).
          if (mounted) {
            context.push(
              '${RoutePaths.emailVerified}?email=${Uri.encodeComponent(email)}',
            );
          }
          return;
        }
      } else {
        await auth.signIn(email, _password.text);
        await ref
            .read(localSettingsProvider.notifier)
            .rememberEmailIfEnabled(email);
      }
      if (mounted) _toast(_isSignUp ? 'Account created!' : 'Welcome back!');
      // Router redirect (guard) takes the user onward automatically.
    } on AuthException catch (e) {
      if (mounted) _toast(e.message, error: true);
    }
  }

  /// Old app has a "↻ Refresh" action under the CTA — it re-runs the session
  /// check (useful after confirming an email in another app).
  void _refresh() {
    ref.invalidate(authControllerProvider);
    _toast('Refreshed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = ref.watch(authControllerProvider).loading;
    final localSettings = ref.watch(localSettingsProvider);
    _prefillRememberedEmail(localSettings);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppConstants.maxContainerWidth,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _logo(theme),
                    const SizedBox(height: 28),
                    _tabs(theme),
                    const SizedBox(height: 28),
                    _label(theme, 'Email'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: Validators.email,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LucideIcons.mail),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _label(theme, 'Password'),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: Validators.password,
                      decoration: InputDecoration(
                        hintText:
                            'Min ${AppConstants.minPasswordChars} characters',
                        prefixIcon: const Icon(LucideIcons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isSignUp)
                      _termsCheckbox(theme)
                    else
                      _rememberMeRow(localSettings.rememberEmail),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: _isSignUp ? 'Sign Up' : 'Login',
                      loading: loading,
                      onPressed: loading ? null : _submit,
                    ),
                    if (!_isSignUp)
                      TextButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) =>
                              ResetPasswordDialog(initialEmail: _email.text),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: AppColors.pink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(
                        LucideIcons.refreshCw,
                        size: 16,
                        color: AppColors.mutedFg,
                      ),
                      label: const Text(
                        'Refresh',
                        style: TextStyle(color: AppColors.mutedFg),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _legalFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Always-visible legal links footer — shown on both Login and Sign Up
  /// (not just buried in the Sign Up terms checkbox), per explicit request
  /// that Privacy/Terms/Refund/Child Safety be reachable by everyone,
  /// signed-up or not.
  Widget _legalFooter() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        _footerLink('Privacy & Terms', RoutePaths.privacy),
        _footerDot(),
        _footerLink('Refund Policy', RoutePaths.refund),
        _footerDot(),
        _footerLink('Child Safety', RoutePaths.childSafety),
      ],
    ),
  );

  Widget _footerDot() =>
      const Text('·', style: TextStyle(color: AppColors.mutedFg, fontSize: 12));

  Widget _footerLink(String label, String route) => GestureDetector(
    onTap: () => context.push(route),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.mutedFg,
        fontSize: 12,
        decoration: TextDecoration.underline,
      ),
    ),
  );

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    ),
  );

  Widget _logo(ThemeData theme) => Column(
    children: [
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          gradient: AppGradients.cta,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(LucideIcons.heart, color: Colors.white, size: 40),
      ),
      const SizedBox(height: 14),
      Text(
        'LoveMe',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        'Find your perfect match',
        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedFg),
      ),
    ],
  );

  /// Full-bleed segmented control — squarer than our old rounded pills.
  Widget _tabs(ThemeData theme) => Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.colorScheme.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      children: [
        _tab('Login', !_isSignUp, () => setState(() => _isSignUp = false)),
        _tab('Sign Up', _isSignUp, () => setState(() => _isSignUp = true)),
      ],
    ),
  );

  Widget _tab(String label, bool selected, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: selected ? AppColors.pink : Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.mutedFg,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    ),
  );

  Widget _rememberMeRow(bool rememberMe) => Row(
    children: [
      Checkbox(
        value: rememberMe,
        shape: const CircleBorder(),
        activeColor: AppColors.pink,
        onChanged: (v) => ref
            .read(localSettingsProvider.notifier)
            .setRememberEmail(v ?? false),
      ),
      const Text('Remember me'),
    ],
  );

  Widget _termsCheckbox(ThemeData theme) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(
        value: _acceptTerms,
        shape: const CircleBorder(),
        activeColor: AppColors.pink,
        onChanged: (v) => setState(() => _acceptTerms = v ?? false),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                const TextSpan(text: 'I confirm I am at least '),
                const TextSpan(
                  text: '18 years old',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text:
                      ', I am using this app voluntarily, and I agree '
                      'to the ',
                ),
                _linkSpan('Terms & Conditions', _termsTap),
                const TextSpan(text: ' and '),
                _linkSpan('Privacy Policy', _privacyTap),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  TextSpan _linkSpan(String text, TapGestureRecognizer recognizer) => TextSpan(
    text: text,
    style: const TextStyle(
      color: AppColors.pink,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    ),
    recognizer: recognizer,
  );
}
