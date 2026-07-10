import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';

/// 02 — EmailVerifiedPage. UI-parity rebuild matching the old app's real
/// 6-digit OTP code entry screen (`old app ss/onboring_screens/WhatsApp
/// Image … 11.04.02/03 PM.jpeg`) instead of our old static "Email
/// verified!" landing screen.
///
/// ⚠️ **UI ONLY — not wired to a real verification backend.** Supabase
/// "Confirm email" is currently disabled server-side (see CLAUDE.md), and
/// there is no OTP-verification RPC/edge function to call. Per explicit
/// instruction: the Continue step must NOT let the user through just
/// because *a* widget exists — it stays disabled until 6 digits are
/// entered, and submitting shows an honest "not available yet" message
/// rather than pretending to verify anything. Wire this up once the real
/// OTP flow is enabled server-side and its contract is known.
class EmailVerifiedScreen extends StatefulWidget {
  const EmailVerifiedScreen({super.key, this.email});

  final String? email;

  @override
  State<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen> {
  static const _codeLength = 6;
  static const _initialSeconds = 9 * 60 + 53; // matches the old app's 9:53

  final List<TextEditingController> _digits =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  int _secondsLeft = _initialSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _digits.map((c) => c.text).join();
  bool get _codeComplete => _code.length == _codeLength;

  String get _countdownLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (text.isEmpty) return;
    for (var i = 0; i < _codeLength; i++) {
      _digits[i].text = i < text.length ? text[i] : '';
    }
    setState(() {});
  }

  void _resend() {
    setState(() => _secondsLeft = _initialSeconds);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Resending isn\'t available yet — backend not built.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _submit() {
    if (!_codeComplete) return;
    // Deliberately does NOT navigate anywhere — no real verification exists
    // to check the code against. Per instruction: entering digits alone
    // must not be enough to move forward.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Email verification isn\'t available yet — backend not built.'),
        behavior: SnackBarBehavior.floating,
      ));
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
                      child: const Icon(LucideIcons.mail,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 18),
                    const Text('Verify Your Email',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            color: AppColors.mutedFg, height: 1.4),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to\n'),
                          TextSpan(
                              text: widget.email ?? 'your email',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.fgLight)),
                          const TextSpan(
                              text: '. Enter it below to verify your account.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _codeLength; i++) _digitBox(i),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⏱️', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text('Code expires in $_countdownLabel',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
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
                          style: TextStyle(color: AppColors.mutedFg, fontSize: 13),
                          children: [
                            TextSpan(text: '📌 Don\'t see it? Check your '),
                            TextSpan(
                                text: 'Spam',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: ' or '),
                            TextSpan(
                                text: 'Promotions',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(
                                text:
                                    ' folder for an email from noreply@loveme-app.com'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GradientButton(
                            label: 'Paste Code',
                            icon: LucideIcons.clipboard,
                            height: 48,
                            onPressed: _pasteCode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _secondsLeft == 0 ? _resend : null,
                            icon: const Icon(LucideIcons.refreshCw, size: 16),
                            label: const Text('Resend'),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: const StadiumBorder(),
                                side: const BorderSide(color: AppColors.borderLight)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Verify',
                      // Disabled until all 6 digits are entered — a filled
                      // field is not the same as a verified code, and there
                      // is no backend to check it against yet regardless.
                      onPressed: _codeComplete ? _submit : null,
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

  Widget _digitBox(int i) => SizedBox(
        width: 44,
        height: 54,
        child: TextField(
          controller: _digits[i],
          focusNode: _focusNodes[i],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.pink, width: 2),
            ),
          ),
          onChanged: (v) => _onDigitChanged(i, v),
        ),
      );
}
