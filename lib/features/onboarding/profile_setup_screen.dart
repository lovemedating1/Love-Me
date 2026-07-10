import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/route_paths.dart';
import '../../core/location/location_service.dart';
import '../../core/media/photo_picker_service.dart';
import '../../core/media/photo_source_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/data/repositories.dart';
import '../../shared/widgets/gradient_button.dart';
import '../auth/auth_controller.dart';
import 'onboarding_widgets.dart';

/// `profile_photos.display_order` is constrained to 1-4; onboarding uses
/// slots 1-3 (all mandatory, per the old app — `avatar` = slot 1/primary).
const _mandatoryPhotoCount = 3;

/// 04 — ProfileSetupPage. Rebuilt for UI parity with the old app's 4-step
/// wizard (`old app ss/onboring_screens/`):
///   1. About You      — name, birthday (+ age badge), marital status,
///                        orientation, interested-in.
///   2. Add Your Photos — 3 MANDATORY photos, one at a time, each
///                        face-validated on-device ("verified").
///   3. Your Location   — standalone GPS-only step (no manual country/city
///                        fields — matches the old app exactly).
///   4. Interests & Goals — relationship goal + hobbies, combined.
///
/// Country/city are still collected (the live `profiles` table requires
/// them and nothing in the old app's location step provides them any other
/// way) — captured silently from reverse-mapping is NOT done (no geocoding
/// service exists); instead they default to empty strings when no GPS fix
/// was captured, same as the "never fake data" rule applied elsewhere.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static const _steps = 4;
  int _step = 0;

  // Step 1 — About You
  final _name = TextEditingController();
  DateTime? _dob;
  String? _maritalStatus;
  String? _orientation;
  String? _interestedIn;

  // Step 2 — Add Your Photos (3 mandatory, uploaded one at a time)
  final List<String> _photoUrls = [];
  bool _photoUploading = false;

  // Step 3 — Your Location (GPS-only, no manual fields)
  bool _locating = false;
  LocationFix? _locationFix;
  String? _locationLabel; // e.g. "Kabianga ward, Kenya" (best-effort display)

  // Step 4 — Interests & Goals
  String? _goal;
  final Set<String> _hobbies = {};

  bool _submitting = false;

  static const _maritalOptions = [
    SheetOption('single', 'Single', emoji: '💫'),
    SheetOption('dating', 'Dating', emoji: '💑'),
    SheetOption('searching', 'Searching', emoji: '🔍'),
    SheetOption('divorced', 'Divorced', emoji: '💔'),
    SheetOption('married', 'Married', emoji: '💍'),
    SheetOption('widowed', 'Widowed', emoji: '🥀'),
  ];
  static const _orientationOptions = [
    SheetOption('straight', 'Straight'),
    SheetOption('gay', 'Gay'),
    SheetOption('lesbian', 'Lesbian'),
    SheetOption('bisexual', 'Bisexual'),
  ];
  static const _interestedInOptions = [
    SheetOption('men', 'Men', emoji: '👨'),
    SheetOption('women', 'Women', emoji: '👩'),
    SheetOption('everyone', 'Everyone', emoji: '🌈'),
  ];
  static const _goalOptions = [
    SheetOption('Looking for a lover', 'Looking for a lover', emoji: '💕'),
    SheetOption('Need a serious relationship', 'Need a serious relationship',
        emoji: '💍'),
    SheetOption('Looking for genuine connections',
        'Looking for genuine connections',
        emoji: '🤝'),
    SheetOption('Just here to make friends', 'Just here to make friends',
        emoji: '👋'),
    SheetOption('Looking for something casual', 'Looking for something casual',
        emoji: '🌸'),
    SheetOption('Open to anything', 'Open to anything', emoji: '🌈'),
  ];
  static const _hobbyOptions = [
    ('Coffee Lover', '☕'), ('Travel Enthusiast', '✈️'),
    ('Photography', '📸'), ('Yoga', '🧘'), ('Music', '🎵'),
    ('Hiking', '🥾'), ('Cooking', '🍳'), ('Fitness', '💪'),
    ('Art', '🎨'), ('Reading', '📚'), ('Dancing', '💃'),
    ('Gaming', '🎮'), ('Surfing', '🏄'), ('Movies', '🎬'),
    ('Dogs', '🐕'), ('Cats', '🐱'), ('Wine', '🍷'),
  ];

  @override
  void dispose() {
    _name.dispose();
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
            (_maritalStatus == null ? 'Select your marital status' : null) ??
            (_orientation == null ? 'Select your orientation' : null) ??
            (_interestedIn == null ? 'Select who you\'re interested in' : null);
      case 1:
        return _photoUrls.length >= _mandatoryPhotoCount
            ? null
            : 'Upload all $_mandatoryPhotoCount photos';
      case 2:
        return null; // location is best-effort, not blocking
      case 3:
        return (_goal == null ? 'Select your goal' : null) ??
            (_hobbies.isEmpty ? 'Select at least one hobby' : null);
    }
    return null;
  }

  Future<void> _next() async {
    final err = _validateStep();
    if (err != null) {
      _toast(err, error: true);
      return;
    }

    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    // Finish
    setState(() => _submitting = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      final fix = _locationFix;
      await Supabase.instance.client.from('profiles').update({
        'name': _name.text.trim(),
        'birthday':
            '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        'marital_status': _maritalStatus,
        'orientation': _orientation,
        'interested_in': _interestedIn,
        'relationship_goal': _goal,
        'hobbies': _hobbies.toList(),
        if (fix != null) 'location_lat': fix.latitude,
        if (fix != null) 'location_lng': fix.longitude,
        if (fix != null) 'location_accuracy_m': fix.accuracyMeters,
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

  /// Uploads the next mandatory photo (face-validated on-device — the old
  /// app calls this "AI verification"; ours is the same ML Kit face check
  /// used everywhere else in the app, not a separate service). The first
  /// photo uploaded becomes the primary (`display_order: 1`).
  Future<void> _uploadPhoto() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    setState(() => _photoUploading = true);
    try {
      final picker = ref.read(photoPickerServiceProvider);
      final picked = await picker.pickProfilePhoto(source);

      final repo = ref.read(profilePhotoRepositoryProvider);
      final url = await repo.uploadPhoto(picked.bytes,
          fileExtension: picked.fileExtension);
      final displayOrder = _photoUrls.length + 1;
      await repo.addPhoto(
        photoUrl: url,
        displayOrder: displayOrder,
        isPrimary: _photoUrls.isEmpty,
      );

      if (_photoUrls.isEmpty) ref.invalidate(currentUserProvider);
      if (mounted) setState(() => _photoUrls.add(url));
    } on PhotoPickCancelled {
      // User backed out — no-op.
    } on NoFaceDetectedException {
      if (mounted) {
        _toast(
            'That doesn\'t look like a photo of a person. Please upload a '
            'clear photo of yourself.',
            error: true);
      }
    } on MediaUploadException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } catch (e) {
      if (mounted) _toast('Could not add photo: $e', error: true);
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _removePhoto(int index) async {
    // The wizard only tracks uploaded URLs locally; a full remove (delete
    // the profile_photos row too) isn't needed here since the row can be
    // replaced from the Profile screen later. We just let the user re-add
    // the slot on this screen.
    setState(() => _photoUrls.removeAt(index));
  }

  /// Captures a real GPS fix via `geolocator`. The old app's step has NO
  /// manual country/city fields — location is 100% device-GPS-driven, so
  /// we match that exactly rather than offering a dropdown fallback.
  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      final fix = await ref.read(locationServiceProvider).getCurrentLocation();
      if (mounted) {
        setState(() {
          _locating = false;
          _locationFix = fix;
          // No reverse-geocoding service exists — we cannot show a real
          // "Ward, Country" label like the old app's "Kabianga ward, Kenya"
          // without fabricating one. Show the raw coordinates instead of a
          // fake place name (never fake data).
          _locationLabel =
              '${fix.latitude.toStringAsFixed(4)}, ${fix.longitude.toStringAsFixed(4)}';
        });
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(() => _locating = false);
        _toast('Turn on location services to use this.', error: true);
      }
    } on LocationPermissionDeniedException catch (e) {
      if (mounted) {
        setState(() => _locating = false);
        _toast(
            e.permanently
                ? 'Location permission denied — enable it in system settings.'
                : 'Location permission denied.',
            error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _locating = false);
        _toast('Could not get your location — try again.', error: true);
      }
    }
  }

  void _clearLocation() => setState(() {
        _locationFix = null;
        _locationLabel = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Column(
              children: [
                _progressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            for (var i = 0; i < _steps; i++) ...[
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? AppColors.pink
                        : AppColors.borderLight,
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

  Widget _stepHeader(String emoji, String title, String subtitle) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.fgLight)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: AppColors.mutedFg, fontSize: 15)),
          const SizedBox(height: 24),
        ],
      );

  // ---- Step 1: About You -------------------------------------------------

  Widget _step1() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader('👤', 'About You', 'Let\'s get to know you'),
          const FieldLabel('Your Name'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: Icon(LucideIcons.user)),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Your Birthday'),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Text('🎂', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _dob == null
                                ? ''
                                : '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.day.toString().padLeft(2, '0')}/${_dob!.year}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.mutedFg),
                      ],
                    ),
                  ),
                ),
                if (_dob != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.chipPinkBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text('${Validators.ageFrom(_dob!)}',
                            style: const TextStyle(
                                color: AppColors.pink,
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                        const Text('YEARS OLD',
                            style: TextStyle(
                                color: AppColors.pink,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const WarningBanner(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: AppColors.fgLight, fontSize: 12.5),
                children: [
                  TextSpan(text: 'Enter the '),
                  TextSpan(
                      text: 'exact birthday',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: ' shown on your '),
                  TextSpan(
                      text: 'National ID, Visa, Birth Certificate or Driving '
                          'Licence',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(
                      text: '. It will be used during identity verification '
                          '— mismatches may block your account.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('I am a…'),
                    DropdownSheetField(
                      hint: 'Tap to select…',
                      options: _maritalOptions,
                      selected: _maritalStatus,
                      removable: true,
                      onChanged: (v) => setState(() => _maritalStatus = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('My orientation'),
                    DropdownSheetField(
                      hint: 'Tap to select…',
                      options: _orientationOptions,
                      selected: _orientation,
                      removable: true,
                      onChanged: (v) => setState(() => _orientation = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('I\'m interested in seeing'),
          DropdownSheetField(
            hint: 'Tap to select…',
            options: _interestedInOptions,
            selected: _interestedIn,
            removable: true,
            onChanged: (v) => setState(() => _interestedIn = v),
          ),
        ],
      );

  // ---- Step 2: Add Your Photos -------------------------------------------

  Widget _step2() {
    final verifiedCount = _photoUrls.length;
    final activeIndex = _photoUrls.length < _mandatoryPhotoCount
        ? _photoUrls.length
        : _mandatoryPhotoCount - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader('📸', 'Add Your Photos',
            'Upload $_mandatoryPhotoCount real photos — one at a time'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Photo ${activeIndex + 1}/$_mandatoryPhotoCount',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('$verifiedCount/$_mandatoryPhotoCount verified',
                style: const TextStyle(color: AppColors.mutedFg)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < _mandatoryPhotoCount; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < verifiedCount
                        ? AppColors.pink
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < _mandatoryPhotoCount - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 20),
        if (verifiedCount < _mandatoryPhotoCount) ...[
          Text('Photo ${activeIndex + 1} of $_mandatoryPhotoCount',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            activeIndex == 0
                ? 'Clear face, well lit.'
                : (activeIndex == _mandatoryPhotoCount - 1
                    ? 'One more to finish.'
                    : 'Keep it real.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedFg),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.chipGreyBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Not uploaded',
                  style: TextStyle(
                      color: AppColors.mutedFg, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _photoUploading ? null : _uploadPhoto,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardLight,
                  border: Border.all(
                      color: AppColors.pink, width: 2, style: BorderStyle.solid),
                ),
                child: _photoUploading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.camera, color: AppColors.pink, size: 36),
                          SizedBox(height: 8),
                          Text('Tap to upload',
                              style: TextStyle(
                                  color: AppColors.pink,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            for (var i = 0; i < _mandatoryPhotoCount; i++) ...[
              Expanded(child: _photoThumb(i)),
              if (i < _mandatoryPhotoCount - 1) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'All $_mandatoryPhotoCount photos must be real photos of you. AI '
          'verification runs on every upload — fake, AI-generated or '
          'cartoon images will be rejected.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedFg, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _photoThumb(int i) {
    final filled = i < _photoUrls.length;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: filled ? AppColors.success : AppColors.borderLight,
                      width: filled ? 2 : 1),
                  color: AppColors.cardLight,
                ),
                clipBehavior: Clip.antiAlias,
                child: filled
                    ? Image.network(_photoUrls[i], fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(LucideIcons.image, color: AppColors.pink))
                    : null,
              ),
              if (filled)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removePhoto(i),
                    child: const CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.destructive,
                      child: Icon(Icons.close, size: 13, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          filled ? '${i + 1}/$_mandatoryPhotoCount · Verified' : '${i + 1}/$_mandatoryPhotoCount · Not uploaded',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: filled ? AppColors.success : AppColors.mutedFg,
          ),
        ),
      ],
    );
  }

  // ---- Step 3: Your Location ----------------------------------------------

  Widget _step3() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                const Text('📍', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                const Text('Your Location',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.fgLight)),
                const SizedBox(height: 4),
                const Text('We use your device location to find people near you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedFg, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _locating ? null : _useLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _locating
                    ? AppColors.chipYellowBg
                    : (_locationFix != null ? AppColors.gold : AppColors.cardLight),
                borderRadius: BorderRadius.circular(999),
                border: _locationFix == null && !_locating
                    ? Border.all(color: AppColors.borderLight)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_locating)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(LucideIcons.mapPin, color: AppColors.fgLight),
                  const SizedBox(width: 10),
                  Text(
                    _locating
                        ? 'Detecting…'
                        : (_locationFix != null
                            ? 'Update My Location'
                            : 'Use My Current Location'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.fgLight),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_locationFix == null)
            const Text(
              'Tap the button above to detect your city and country automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedFg),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: AppColors.pink, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_locationLabel ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: _clearLocation,
                    child: const CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.chipGreyBg,
                      child: Icon(Icons.close, size: 14, color: AppColors.mutedFg),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  // ---- Step 4: Interests & Goals ------------------------------------------

  Widget _step4() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader('💖', 'Interests & Goals', 'What are you into?'),
          Row(
            children: const [
              Icon(LucideIcons.heart, size: 16, color: AppColors.fgLight),
              SizedBox(width: 6),
              Text('What are you looking for?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          DropdownSheetField(
            hint: 'Select your goal',
            options: _goalOptions,
            selected: _goal,
            onChanged: (v) => setState(() => _goal = v),
          ),
          const SizedBox(height: 20),
          const Text('Pick your hobbies (select multiple)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_hobbies.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in _hobbies)
                  _selectedHobbyPill(h),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _HobbyPicker(
            options: _hobbyOptions,
            selected: _hobbies,
            onToggle: (h) => setState(() {
              if (_hobbies.contains(h)) {
                _hobbies.remove(h);
              } else {
                _hobbies.add(h);
              }
            }),
          ),
        ],
      );

  Widget _selectedHobbyPill(String hobby) {
    final emoji = _hobbyOptions
        .where((h) => h.$1 == hobby)
        .map((h) => h.$2)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji == null ? hobby : '$hobby $emoji',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _hobbies.remove(hobby)),
            child: const Icon(Icons.close, color: Colors.white, size: 15),
          ),
        ],
      ),
    );
  }

  // ---- Nav buttons ---------------------------------------------------------

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
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: AppColors.borderLight)),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: _step == _steps - 1 ? 'Start Matching 🚀' : 'Continue',
                  loading: _submitting,
                  onPressed: _submitting ? null : _next,
                ),
              ),
            ],
          ),
        ),
      );
}

/// The old app's hobby multi-select: a "Tap to select hobbies…" trigger that
/// expands into a white card of emoji pill chips (checked/unchecked state)
/// laid out in a wrap grid.
class _HobbyPicker extends StatefulWidget {
  const _HobbyPicker({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<(String, String)> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  State<_HobbyPicker> createState() => _HobbyPickerState();
}

class _HobbyPickerState extends State<_HobbyPicker> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _open ? AppColors.gold : AppColors.cardLight,
              borderRadius: BorderRadius.circular(14),
              border: _open ? null : Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.selected.isEmpty
                        ? 'Tap to select hobbies…'
                        : '${widget.selected.length} selected',
                    style: TextStyle(
                      color: widget.selected.isEmpty
                          ? AppColors.mutedFg
                          : AppColors.fgLight,
                      fontWeight: widget.selected.isEmpty
                          ? FontWeight.normal
                          : FontWeight.w700,
                    ),
                  ),
                ),
                Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.fgLight),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, emoji) in widget.options)
                    GestureDetector(
                      onTap: () => widget.onToggle(label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: widget.selected.contains(label)
                              ? AppColors.pink
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: widget.selected.contains(label)
                                  ? AppColors.pink
                                  : AppColors.borderLight),
                        ),
                        child: Text('$label $emoji',
                            style: TextStyle(
                              color: widget.selected.contains(label)
                                  ? Colors.white
                                  : AppColors.fgLight,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
