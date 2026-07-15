import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';
import 'auth_controller.dart';

/// 02 — EmailVerifiedPage.
///
/// Link-based confirmation (2026-07-13): Supabase's own confirmation email
/// contains a link the user taps — there is no code to enter. This screen
/// just tells the user to check their inbox and offers a resend, then waits
/// (the router redirects away automatically once `auth.onAuthStateChange`
/// reports the session is confirmed — see `router_guards.dart`).
///
/// Supersedes the old 6-digit OTP mock UI, which never had a real backend to
/// verify against (there is no separate OTP flow — Supabase's link IS the
/// verification). See `BACKEND_CONFIRM_EMAIL_HANDOFF.md`.
class EmailVerifiedScreen extends ConsumerStatefulWidget {
  const EmailVerifiedScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<EmailVerifiedScreen> createState() =>
      _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends ConsumerState<EmailVerifiedScreen> {
  static const _resendCooldownSeconds = 60;

  int _resendCooldown = 0;
  Timer? _timer;
  bool _resending = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
        return;
      }
      setState(() => _resendCooldown--);
    });
  }

  Future<void> _resend() async {
    final email = widget.email;
    if (email == null || _resending) return;
    setState(() => _resending = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendConfirmationEmail(email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Confirmation email resent.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not resend — please try again shortly.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: BoxDecoration(
                  color: AppColors.cardLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.pink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.mailCheck,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Check Your Email',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: AppColors.mutedFg,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text: 'We sent a confirmation link to\n',
                          ),
                          TextSpan(
                            text: widget.email ?? 'your email',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.fgLight,
                            ),
                          ),
                          const TextSpan(
                            text:
                                '. Tap the link in that email to finish setting up your account — this screen will move on automatically.',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: AppColors.mutedFg,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(text: '📌 Don\'t see it? Check your '),
                            TextSpan(
                              text: 'Spam',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: ' or '),
                            TextSpan(
                              text: 'Promotions',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: ' folder.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : 'Resend Email',
                      icon: LucideIcons.refreshCw,
                      onPressed: _resendCooldown == 0 && !_resending
                          ? _resend
                          : null,
                    ),
                    TextButton(
                      onPressed: () => context.go(RoutePaths.auth),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
