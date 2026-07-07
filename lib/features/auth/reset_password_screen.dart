import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';

/// 03 — ResetPasswordPage. Set a new password from the recovery deep link.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _pwd.text));
      if (mounted) setState(() => _done = true);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.destructive));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: _done
                  ? _success(theme)
                  : Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Choose a new password',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _pwd,
                            obscureText: _obscure,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: Validators.password,
                            decoration: InputDecoration(
                              labelText: 'New password',
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
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscure,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (v) =>
                                Validators.confirmPassword(v, _pwd.text),
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: Icon(LucideIcons.lock),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Update password'),
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

  Widget _success(ThemeData theme) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.circleCheck,
              color: AppColors.success, size: 56),
          const SizedBox(height: 16),
          Text('Password updated', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go(RoutePaths.auth),
              child: const Text('Go to sign in'),
            ),
          ),
        ],
      );
}
