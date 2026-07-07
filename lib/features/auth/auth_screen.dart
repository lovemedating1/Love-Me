import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/validators.dart';
import 'auth_controller.dart';
import 'reset_password_dialog.dart';

/// 01 — AuthPage. Sign In / Sign Up tabs + Google OAuth + reset flow + 18+ gate.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _isSignUp = false;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _acceptTerms = false;
  String? _gender; // 'male' | 'female'
  String? _country;
  DateTime? _dob;

  static const _countries = [
    'Kenya', 'Nigeria', 'Ghana', 'South Africa', 'Egypt', 'Uganda',
    'Tanzania', 'India', 'United States', 'United Kingdom',
  ];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.destructive : AppColors.pink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSignUp) {
      final dobError = Validators.dob(_dob);
      if (dobError != null) { _toast(dobError, error: true); return; }
      if (_gender == null) { _toast('Select your gender', error: true); return; }
      if (_country == null) { _toast('Select your country', error: true); return; }
      if (!_acceptTerms) {
        _toast('You must accept the terms and confirm you are 18+', error: true);
        return;
      }
    }

    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_isSignUp) {
        await auth.signUp(_email.text.trim(), _password.text);
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
      if (mounted) _toast(_isSignUp ? 'Account created!' : 'Welcome back!');
      // Router redirect (guard) takes the user onward automatically.
    } on AuthException catch (e) {
      if (mounted) _toast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = ref.watch(authControllerProvider).loading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.header),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _logo(theme),
                          const SizedBox(height: 20),
                          _tabs(theme),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: Validators.email,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(LucideIcons.mail),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: Validators.password,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(LucideIcons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? LucideIcons.eye
                                    : LucideIcons.eyeOff),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_isSignUp) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirm,
                              obscureText: _obscure,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (v) => Validators.confirmPassword(
                                  v, _password.text),
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: Icon(LucideIcons.lock),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _dobField(theme),
                            const SizedBox(height: 12),
                            _genderField(),
                            const SizedBox(height: 12),
                            _countryField(),
                            const SizedBox(height: 8),
                            _termsCheckbox(theme),
                          ],
                          if (!_isSignUp) _signInRow(theme),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _isSignUp ? 'Create Account' : 'Sign In'),
                          ),
                          const SizedBox(height: 12),
                          _divider(theme),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: loading
                                ? null
                                : () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogle(),
                            icon: const Icon(LucideIcons.logIn),
                            label: const Text('Continue with Google'),
                          ),
                          const SizedBox(height: 16),
                          _legalFooter(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(ThemeData theme) => Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                gradient: AppGradients.premium, shape: BoxShape.circle),
            child: const Icon(LucideIcons.heart, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text('Love Me', style: theme.textTheme.headlineMedium),
          Text('Find your someone',
              style: theme.textTheme.bodySmall),
        ],
      );

  Widget _tabs(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tab('Sign In', !_isSignUp, () => setState(() => _isSignUp = false)),
          _tab('Sign Up', _isSignUp, () => setState(() => _isSignUp = true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.pink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );

  Widget _dobField(ThemeData theme) => InkWell(
        onTap: _pickDob,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Date of birth (18+)',
            prefixIcon: Icon(LucideIcons.calendar),
          ),
          child: Text(
            _dob == null
                ? 'Select date'
                : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
          ),
        ),
      );

  Widget _genderField() => DropdownButtonFormField<String>(
        initialValue: _gender,
        decoration: const InputDecoration(
            labelText: 'Gender', prefixIcon: Icon(LucideIcons.users)),
        items: const [
          DropdownMenuItem(value: 'male', child: Text('Male')),
          DropdownMenuItem(value: 'female', child: Text('Female')),
        ],
        onChanged: (v) => setState(() => _gender = v),
      );

  Widget _countryField() => DropdownButtonFormField<String>(
        initialValue: _country,
        isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Country', prefixIcon: Icon(LucideIcons.mapPin)),
        items: [
          for (final c in _countries)
            DropdownMenuItem(value: c, child: Text(c)),
        ],
        onChanged: (v) => setState(() => _country = v),
      );

  Widget _termsCheckbox(ThemeData theme) => Row(
        children: [
          Checkbox(
            value: _acceptTerms,
            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
          ),
          Expanded(
            child: Text(
              'I am 18+ and accept the Terms & Privacy Policy',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );

  Widget _signInRow(ThemeData theme) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _rememberMe,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
                const Flexible(
                    child: Text('Remember me', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ResetPasswordDialog(initialEmail: _email.text),
            ),
            child: const Text('Forgot password?'),
          ),
        ],
      );

  Widget _divider(ThemeData theme) => Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('or', style: theme.textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      );

  Widget _legalFooter(ThemeData theme) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          _legalLink('Terms', RoutePaths.terms),
          _legalLink('Privacy', RoutePaths.privacy),
          _legalLink('Refund', RoutePaths.refund),
          _legalLink('Child Safety', RoutePaths.childSafety),
        ],
      );

  Widget _legalLink(String label, String route) => GestureDetector(
        onTap: () => context.push(route),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(decoration: TextDecoration.underline),
        ),
      );
}
