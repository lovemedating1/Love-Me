import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../auth/auth_controller.dart';

/// 13 — SettingsPage. Sectioned preferences: discovery, notifications, privacy,
/// ringtone, account, legal. Mock local state (no persistence yet).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  RangeValues _age = const RangeValues(18, 45);
  double _distance = 50;
  String _showMe = 'everyone';
  bool _push = true;
  bool _email = false;
  bool _sound = true;
  bool _vibrate = true;
  bool _hideDistance = false;
  bool _onlineStatus = true;
  bool _screenshotGuard = true;
  String _ringtone = 'Classic';

  static const _ringtones = ['Classic', 'Soft', 'Love'];

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    // While unset, ThemeMode.system is in effect — reflect the platform's
    // current brightness so the switch never looks wrong on first load.
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _section('Appearance'),
          SwitchListTile(
            secondary: Icon(isDark ? LucideIcons.moon : LucideIcons.sun),
            title: const Text('Dark Mode'),
            value: isDark,
            onChanged: (v) =>
                ref.read(themeModeProvider.notifier).setDarkMode(v),
          ),

          _section('Discovery'),
          ListTile(
            title: const Text('Age range'),
            subtitle: Text('${_age.start.round()} – ${_age.end.round()}'),
          ),
          RangeSlider(
            min: 18,
            max: 80,
            divisions: 62,
            values: _age,
            labels: RangeLabels('${_age.start.round()}', '${_age.end.round()}'),
            onChanged: (v) => setState(() => _age = v),
          ),
          ListTile(
            title: const Text('Maximum distance'),
            subtitle: Text('${_distance.round()} km'),
          ),
          Slider(
            min: 1,
            max: 500,
            value: _distance,
            label: '${_distance.round()} km',
            onChanged: (v) => setState(() => _distance = v),
          ),
          ListTile(
            title: const Text('Show me'),
            trailing: DropdownButton<String>(
              value: _showMe,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                DropdownMenuItem(value: 'male', child: Text('Men')),
                DropdownMenuItem(value: 'female', child: Text('Women')),
              ],
              onChanged: (v) => setState(() => _showMe = v!),
            ),
          ),

          _section('Notifications'),
          _switch('Push notifications', _push, (v) => setState(() => _push = v)),
          _switch('Email notifications', _email, (v) => setState(() => _email = v)),
          _switch('Sound', _sound, (v) => setState(() => _sound = v)),
          _switch('Vibration', _vibrate, (v) => setState(() => _vibrate = v)),

          _section('Privacy'),
          _switch('Hide my distance', _hideDistance,
              (v) => setState(() => _hideDistance = v)),
          _switch('Show online status', _onlineStatus,
              (v) => setState(() => _onlineStatus = v)),
          _switch('Screenshot guard', _screenshotGuard,
              (v) => setState(() => _screenshotGuard = v)),

          _section('Ringtone'),
          ListTile(
            leading: const Icon(LucideIcons.music),
            title: const Text('Call ringtone'),
            trailing: DropdownButton<String>(
              value: _ringtone,
              underline: const SizedBox.shrink(),
              items: [
                for (final r in _ringtones)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _ringtone = v!),
            ),
          ),

          _section('Account'),
          _nav(LucideIcons.monitor, 'Signed-in devices', RoutePaths.devices),
          _nav(LucideIcons.shield, 'Safety reports', RoutePaths.safetyReports),
          ListTile(
            leading: const Icon(LucideIcons.trash2, color: AppColors.destructive),
            title: const Text('Delete account',
                style: TextStyle(color: AppColors.destructive)),
            onTap: () => context.push(RoutePaths.deleteAccount),
          ),
          ListTile(
            leading: const Icon(LucideIcons.logOut),
            title: const Text('Sign out'),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),

          _section('Legal'),
          _nav(LucideIcons.fileText, 'Privacy Policy', RoutePaths.privacy),
          _nav(LucideIcons.fileText, 'Terms of Service', RoutePaths.terms),
          _nav(LucideIcons.fileText, 'Refund Policy', RoutePaths.refund),
          _nav(LucideIcons.shield, 'Child Safety', RoutePaths.childSafety),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.pink, fontWeight: FontWeight.w700)),
      );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );

  Widget _nav(IconData icon, String label, String route) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: () => context.push(route),
      );
}
