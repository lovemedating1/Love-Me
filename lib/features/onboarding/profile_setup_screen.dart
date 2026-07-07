import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../auth/auth_controller.dart';

/// 04 — ProfileSetupPage. 4-step onboarding wizard (mock; no real upload).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static const _steps = 4;
  int _step = 0;

  // Step 1
  final _name = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String _seeking = 'both';
  // Step 2 (mock photo slots)
  bool _avatarAdded = false;
  final List<bool> _gallery = List.filled(AppConstants.maxGalleryPhotos - 1, false);
  // Step 3
  final _bio = TextEditingController();
  final Set<String> _interests = {};
  String _goal = 'Long-term';
  // Step 4
  String? _country;
  final _city = TextEditingController();
  bool _locating = false;
  bool _located = false;

  bool _submitting = false;

  static const _allInterests = [
    'Travel', 'Music', 'Coffee', 'Hiking', 'Movies', 'Food', 'Art', 'Sports',
    'Reading', 'Gaming', 'Yoga', 'Photography', 'Dancing', 'Cooking',
  ];
  static const _goals = ['Long-term', 'Dating', 'Friendship', 'Casual'];
  static const _countries = [
    'Kenya', 'Nigeria', 'Ghana', 'South Africa', 'Egypt', 'India',
    'United States', 'United Kingdom',
  ];

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _city.dispose();
    super.dispose();
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

  String? _validateStep() {
    switch (_step) {
      case 0:
        return Validators.displayName(_name.text) ??
            Validators.dob(_dob) ??
            (_gender == null ? 'Select your gender' : null);
      case 1:
        return _avatarAdded ? null : 'Add a profile photo';
      case 2:
        if (Validators.bio(_bio.text) != null) return 'Bio too long';
        return Validators.interests(_interests.toList())
            ? null
            : 'Select 1-8 interests';
      case 3:
        return _country == null ? 'Select your country' : null;
    }
    return null;
  }

  Future<void> _next() async {
    final err = _validateStep();
    if (err != null) { _toast(err, error: true); return; }

    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    // Finish
    setState(() => _submitting = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      await Supabase.instance.client.from('profiles').update({
        'name': _name.text.trim(),
        'birthday':
            '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        'gender': _gender,
        'interested_in': _seeking,
        'relationship_goal': _goal,
        'hobbies': _interests.toList(),
        'country': _country,
        'city': _city.text.trim(),
        'profile_complete': true,
      }).eq('user_id', userId);
      ref.read(authControllerProvider.notifier).markProfileComplete();
      if (mounted) {
        _toast('Profile complete! Welcome to Love Me.');
        context.go(RoutePaths.discover);
      }
    } catch (_) {
      if (mounted) _toast('Could not save your profile — try again.', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _locating = false;
        _located = true;
        _country ??= 'Kenya';
        if (_city.text.isEmpty) _city.text = 'Nairobi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Column(
              children: [
                _progressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _stepContent(),
                  ),
                ),
                _navButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            for (var i = 0; i < _steps; i++) ...[
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? AppColors.pink
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < _steps - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      );

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _step1();
      case 1:
        return _step2();
      case 2:
        return _step3();
      default:
        return _step4();
    }
  }

  Widget _stepTitle(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodySmall),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _step1() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle('About you', 'The basics to get started'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'First name',
                prefixIcon: Icon(LucideIcons.user)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 20),
                firstDate: DateTime(now.year - 100),
                lastDate: now,
              );
              if (picked != null) setState(() => _dob = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Date of birth (18+)',
                  prefixIcon: Icon(LucideIcons.calendar)),
              child: Text(_dob == null
                  ? 'Select date'
                  : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
                      '  ·  age ${Validators.ageFrom(_dob!)}'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Gender', style: Theme.of(context).textTheme.titleMedium),
          _radioRow(['male', 'female'], _gender, (v) => setState(() => _gender = v)),
          const SizedBox(height: 8),
          Text('Show me', style: Theme.of(context).textTheme.titleMedium),
          _radioRow(['male', 'female', 'both'], _seeking,
              (v) => setState(() => _seeking = v!)),
        ],
      );

  Widget _radioRow(List<String> options, String? group, ValueChanged<String?> onChanged) => Wrap(
        spacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text(o[0].toUpperCase() + o.substring(1)),
              selected: group == o,
              onSelected: (_) => onChanged(o),
            ),
        ],
      );

  Widget _step2() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle('Your photos', 'Add a profile photo (and up to 5 more)'),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _avatarAdded = !_avatarAdded),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.pink, width: 2),
                ),
                child: Icon(
                  _avatarAdded ? LucideIcons.check : LucideIcons.camera,
                  size: 40,
                  color: _avatarAdded ? AppColors.success : AppColors.pink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
              child: Text(_avatarAdded ? 'Photo added (mock)' : 'Tap to add avatar',
                  style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 20),
          Text('Gallery', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _gallery.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _gallery[i] = !_gallery[i]),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _gallery[i] ? LucideIcons.image : LucideIcons.plus,
                      color: _gallery[i] ? AppColors.pink : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _step3() {
    final count = _bio.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle('About me', 'Tell others a little about yourself'),
        TextField(
          controller: _bio,
          maxLines: 4,
          maxLength: AppConstants.maxBioChars,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Bio',
            alignLabelWithHint: true,
            counterText: '$count/${AppConstants.maxBioChars}',
          ),
        ),
        const SizedBox(height: 12),
        Text('Interests (max ${AppConstants.maxInterests})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final it in _allInterests)
              FilterChip(
                label: Text(it),
                selected: _interests.contains(it),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    if (_interests.length < AppConstants.maxInterests) {
                      _interests.add(it);
                    } else {
                      _toast('Up to ${AppConstants.maxInterests} interests',
                          error: true);
                    }
                  } else {
                    _interests.remove(it);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Relationship goal',
            style: Theme.of(context).textTheme.titleMedium),
        _radioRow(_goals, _goal, (v) => setState(() => _goal = v!)),
      ],
    );
  }

  Widget _step4() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle('Where are you?', 'Helps us show people nearby'),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_located ? LucideIcons.check : LucideIcons.mapPin),
            label: Text(_located ? 'Location captured' : 'Use current location'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _country,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Country'),
            items: [
              for (final c in _countries)
                DropdownMenuItem(value: c, child: Text(c))
            ],
            onChanged: (v) => setState(() => _country = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
        ],
      );

  Widget _navButtons() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _back,
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _next,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_step == _steps - 1 ? 'Finish' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      );
}
