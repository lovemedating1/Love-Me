import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_paths.dart';
import '../../core/media/photo_picker_service.dart';
import '../../core/media/photo_source_sheet.dart';
import '../../core/settings/local_settings_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../shared/data/repositories.dart';
import '../../shared/data/support_email_repository.dart';
import '../../shared/models/profile.dart';
import '../../shared/models/verification_request.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/info_modals.dart';
import '../../shared/widgets/sub_page_header.dart';

/// 13 — SettingsPage.
///
/// Rebuilt for UI parity (Phase 4, `WA0055`-family) — see
/// UI_REBUILD_PLAN.md §4.1: a stack of white rounded section cards instead
/// of a flat grouped list.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _verificationExpanded = false;
  bool _helpExpanded = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: const SubPageHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _subscriptionCard(context, me.valueOrNull),
          const SizedBox(height: 14),
          _appearanceCard(),
          const SizedBox(height: 14),
          _locationCard(),
          const SizedBox(height: 14),
          _notificationsCard(),
          const SizedBox(height: 14),
          _ringtoneCard(),
          const SizedBox(height: 14),
          _vibrationCard(),
          const SizedBox(height: 14),
          _verificationCard(),
          const SizedBox(height: 14),
          _helpCard(),
          const SizedBox(height: 14),
          _deleteAccountCard(context),
          const SizedBox(height: 14),
          _legalCard(),
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: AppTheme.cardShadow,
  );

  Widget _cardTitle(String emoji, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    ),
  );

  // ---- Subscription card --------------------------------------------------

  Widget _subscriptionCard(BuildContext context, Profile? me) {
    final isPremium = ref.watch(isPremiumProvider);
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('👑', 'Subscription'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPremium) ...[
                  const Text(
                    'Gold — \$10.00 USD / 30 days',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (me?.premiumUntil != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Active until ${_formatDate(me!.premiumUntil!)}',
                        style: const TextStyle(
                          color: AppColors.mutedFg,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ] else
                  const Text(
                    'No active plan',
                    style: TextStyle(color: AppColors.mutedFg),
                  ),
                const SizedBox(height: 12),
                GradientButton(
                  label: '⬇ Download Receipt (PDF)',
                  height: 46,
                  // PDF generation isn't built server-side yet — disabled
                  // rather than faking a download. See BACKEND_REMAINING.md.
                  onPressed: null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push(RoutePaths.subscription),
                  child: const Text('Manage Subscription'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }

  // ---- Appearance -----------------------------------------------------

  Widget _appearanceCard() {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('☀️', 'Appearance'),
          SwitchListTile(
            secondary: Icon(isDark ? LucideIcons.moon : LucideIcons.sun),
            title: const Text('Dark Mode'),
            value: isDark,
            onChanged: (v) =>
                ref.read(themeModeProvider.notifier).setDarkMode(v),
          ),
          Builder(
            builder: (context) {
              final settings = ref.watch(localSettingsProvider);
              return SwitchListTile(
                secondary: const Icon(LucideIcons.mail),
                title: const Text('Remember email after inactivity logout'),
                value: settings.rememberEmail,
                onChanged: (v) => ref
                    .read(localSettingsProvider.notifier)
                    .setRememberEmail(v),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ---- Location -----------------------------------------------------------
  // "Worldwide" is real: it PATCHes profiles.distance_preference_km (the
  // live column Discover's radius filter already reads) to a sentinel value
  // (AppConstants.kWorldwideDistanceKm) larger than any real preset, rather than adding a
  // fake local-only toggle.

  Widget _locationCard() {
    final me = ref.watch(currentUserProvider);
    final worldwide =
        (me.valueOrNull?.distancePreferenceKm ?? 50) >=
        AppConstants.kWorldwideDistanceKm;
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('🧭', 'Location Settings'),
          const ListTile(
            leading: Icon(LucideIcons.circleCheck, color: AppColors.success),
            title: Text('Location enabled'),
          ),
          ListTile(
            leading: const Icon(LucideIcons.globe),
            title: const Text('Discovery Distance'),
            trailing: Text(
              worldwide ? '🌍 Worldwide' : 'Nearby',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SwitchListTile(
            title: const Text('Worldwide'),
            value: worldwide,
            onChanged: (v) => _setWorldwide(v),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _setWorldwide(bool worldwide) async {
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateMyProfile(
            distancePreferenceKm: worldwide
                ? AppConstants.kWorldwideDistanceKm
                : 50,
          );
      ref.invalidate(currentUserProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not save — try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  // ---- Notifications (collapsed 8 -> 1, per Phase 0 §0.4 #13) -------------

  Widget _notificationsCard() {
    final prefs = ref.watch(notificationPreferencesProvider);
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('🔔', 'Push Notifications'),
          prefs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => ListTile(
              leading: const Icon(
                LucideIcons.triangleAlert,
                color: AppColors.destructive,
              ),
              title: const Text('Could not load notification settings'),
              trailing: TextButton(
                onPressed: () =>
                    ref.invalidate(notificationPreferencesProvider),
                child: const Text('Retry'),
              ),
            ),
            data: (p) => SwitchListTile(
              title: const Text('Background Alerts'),
              subtitle: const Text(
                'Get notified about likes & messages even when the app is closed',
              ),
              value: p.pushEnabled,
              onChanged: (v) => _saveBackgroundAlerts(p.pushEnabled, v),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Old app exposes a single "Background Alerts" toggle; our schema has 8
  /// real columns. Per Phase 0 §0.4 #13 we follow the old app's UI and only
  /// drive `pushEnabled` — the other 7 stay at their existing values
  /// (untouched, not deleted) so NotificationRepository.updatePreferences()
  /// can re-expose them later without a migration.
  Future<void> _saveBackgroundAlerts(bool wasEnabled, bool enabled) async {
    final current = ref.read(notificationPreferencesProvider).valueOrNull;
    if (current == null) return;
    try {
      await ref
          .read(notificationRepositoryProvider)
          .updatePreferences(current.copyWith(pushEnabled: enabled));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not save notification settings.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      ref.invalidate(notificationPreferencesProvider);
    }
  }

  // ---- Call Ringtone / Vibration (device-local, Phase 0 §0.5) -----------

  Widget _ringtoneCard() {
    final settings = ref.watch(localSettingsProvider);
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('🎵', 'Call Ringtone'),
          ListTile(
            leading: const Icon(LucideIcons.music),
            title: const Text('Ringtone'),
            subtitle: Text(settings.ringtone.description),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<CallRingtone>(
                  value: settings.ringtone,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final r in CallRingtone.values)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                  ],
                  onChanged: (r) {
                    if (r != null) {
                      ref.read(localSettingsProvider.notifier).setRingtone(r);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.play),
                  tooltip: 'Preview',
                  // No bundled Classic/Modern/Marimba audio files exist, so
                  // all 3 options play the device's system notification
                  // sound as a real (if not yet distinct-per-option)
                  // preview — user-approved stand-in until real ringtone
                  // assets are provided.
                  onPressed: () => FlutterRingtonePlayer().playNotification(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _vibrationCard() {
    final settings = ref.watch(localSettingsProvider);
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('📳', 'Vibration'),
          SwitchListTile(
            secondary: const Icon(LucideIcons.vibrate),
            title: const Text('Vibrate on incoming call'),
            value: settings.vibrateOnCall,
            onChanged: (v) =>
                ref.read(localSettingsProvider.notifier).setVibrateOnCall(v),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ---- Verification (expandable) -----------------------------------------

  Widget _verificationCard() {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final request = ref.watch(myVerificationRequestProvider).valueOrNull;
    final (label, color) = _verificationStatusLabel(me, request);
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () =>
                setState(() => _verificationExpanded = !_verificationExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Text('🛡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => InfoModals.getVerified(context),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _verificationExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                  ),
                ],
              ),
            ),
          ),
          if (_verificationExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: (me?.isVerified ?? false)
                  ? const Text(
                      'Your identity is verified.',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : _VerificationFlow(existingRequest: request),
            ),
        ],
      ),
    );
  }

  /// `profiles.is_verified` (live, admin-set) takes priority over the
  /// client's own submission-status read — a request can be `approved` and
  /// still show "Not verified" for a beat until `is_verified` flips, so we
  /// never contradict the authoritative column.
  (String, Color) _verificationStatusLabel(
    Profile? me,
    VerificationRequest? request,
  ) {
    if (me?.isVerified ?? false) return ('Verified', AppColors.success);
    return switch (request?.status) {
      VerificationStatus.pending => ('Under review', AppColors.gold),
      VerificationStatus.rejected => (
        'Rejected — resubmit',
        AppColors.destructive,
      ),
      _ => ('Not verified', AppColors.pink),
    };
  }

  // ---- Help & Support (expandable) ---------------------------------------

  Widget _helpCard() => Container(
    decoration: _cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _helpExpanded = !_helpExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Text('❓', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Help & Support',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                Icon(
                  _helpExpanded
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                ),
              ],
            ),
          ),
        ),
        if (_helpExpanded)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _HelpContent(),
          ),
      ],
    ),
  );

  // ---- Delete account / Sign out / Legal ---------------------------------

  Widget _deleteAccountCard(BuildContext context) => Container(
    decoration: _cardDecoration,
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: const Icon(LucideIcons.trash2, color: AppColors.destructive),
      title: const Text(
        'Delete Account',
        style: TextStyle(
          color: AppColors.destructive,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: () => context.push(RoutePaths.deleteAccount),
    ),
  );

  Widget _legalCard() => Container(
    decoration: _cardDecoration,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _nav(LucideIcons.fileText, 'Privacy Policy', RoutePaths.privacy),
        const Divider(height: 1),
        _nav(LucideIcons.fileText, 'Terms of Service', RoutePaths.terms),
        const Divider(height: 1),
        _nav(LucideIcons.fileText, 'Refund Policy', RoutePaths.refund),
        const Divider(height: 1),
        _nav(LucideIcons.shield, 'Child Safety', RoutePaths.childSafety),
      ],
    ),
  );

  Widget _nav(IconData icon, String label, String route) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(LucideIcons.chevronRight, size: 18),
    onTap: () => context.push(route),
  );
}

/// Verification: doc-type picker -> Step 1 upload document -> Step 2 selfie
/// -> submit. Uploads to the private `verification-documents` bucket (NOT
/// `avatars` — that bucket is public, and ID documents/selfies must not be
/// publicly reachable) and inserts a real `verification_requests` row so
/// status persists across sessions. Both the bucket and table are proposed,
/// not yet live server-side — see `BACKEND_VERIFICATION_HANDOFF.md`;
/// [VerificationFeatureUnavailableException] is caught and shown as
/// "not available yet" rather than a raw error in the meantime.
class _VerificationFlow extends ConsumerStatefulWidget {
  const _VerificationFlow({this.existingRequest});

  /// The user's most recent submission, if any — used to skip straight to
  /// a status message for a `pending`/`approved` request rather than
  /// re-showing the doc-type picker (a `rejected` request still allows
  /// resubmission).
  final VerificationRequest? existingRequest;

  @override
  ConsumerState<_VerificationFlow> createState() => _VerificationFlowState();
}

class _VerificationFlowState extends ConsumerState<_VerificationFlow> {
  VerificationDocType? _docType;
  String? _documentPath;
  bool _submitted = false;
  bool _busy = false;
  String? _error;

  Future<void> _uploadDocument() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picker = ref.read(photoPickerServiceProvider);
      final picked = await picker.pickVerificationDocument(source);
      final path = await ref
          .read(verificationRepositoryProvider)
          .uploadDocument(picked.bytes, fileExtension: picked.fileExtension);
      setState(() => _documentPath = path);
    } on PhotoPickCancelled {
      // No-op.
    } on VerificationFeatureUnavailableException {
      if (mounted) {
        setState(
          () => _error =
              'Verification isn\'t available yet — please try again soon.',
        );
      }
    } on MediaUploadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not upload: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadSelfieAndSubmit() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picker = ref.read(photoPickerServiceProvider);
      final picked = await picker.pickProfilePhoto(source);
      final verificationRepo = ref.read(verificationRepositoryProvider);
      final selfiePath = await verificationRepo.uploadDocument(
        picked.bytes,
        fileExtension: picked.fileExtension,
      );
      await verificationRepo.submitRequest(
        documentType: _docType!,
        documentPath: _documentPath!,
        selfiePath: selfiePath,
      );
      ref.invalidate(myVerificationRequestProvider);
      setState(() => _submitted = true);
    } on PhotoPickCancelled {
      // No-op.
    } on NoFaceDetectedException {
      if (mounted) {
        setState(() => _error = 'That doesn\'t look like a photo of a person.');
      }
    } on VerificationFeatureUnavailableException {
      if (mounted) {
        setState(
          () => _error =
              'Verification isn\'t available yet — please try again soon.',
        );
      }
    } on MediaUploadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not upload: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted ||
        widget.existingRequest?.status == VerificationStatus.pending) {
      return const Row(
        children: [
          Icon(LucideIcons.clock, color: AppColors.mutedFg),
          SizedBox(width: 8),
          Expanded(child: Text('Submitted — under review.')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.existingRequest?.status == VerificationStatus.rejected) ...[
          Text(
            widget.existingRequest!.rejectionReason == null
                ? 'Your last submission was rejected — please resubmit.'
                : 'Rejected: ${widget.existingRequest!.rejectionReason}',
            style: const TextStyle(color: AppColors.destructive),
          ),
          const SizedBox(height: 10),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          const SizedBox(height: 10),
        ],
        if (_docType == null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in VerificationDocType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: false,
                  onSelected: (_) => setState(() => _docType = t),
                ),
            ],
          )
        else if (_documentPath == null) ...[
          const Text(
            'Step 1 of 2: Upload document',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _uploadZone(
            icon: LucideIcons.fileUp,
            label: 'Upload ${_docType!.label}',
            onTap: _busy ? null : _uploadDocument,
          ),
        ] else ...[
          const Text(
            'Step 2 of 2: Take a selfie',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _uploadZone(
            icon: LucideIcons.camera,
            label: 'Take selfie',
            onTap: _busy ? null : _uploadSelfieAndSubmit,
          ),
        ],
      ],
    );
  }

  Widget _uploadZone({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBoxLike(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, color: AppColors.pink, size: 28),
              const SizedBox(height: 8),
              Text(_busy ? 'Uploading…' : label),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashed-border container (Flutter has no built-in dashed border).
class DottedBoxLike extends StatelessWidget {
  const DottedBoxLike({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      border: Border.all(
        color: AppColors.mutedFg.withValues(alpha: 0.4),
        width: 1.4,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _HelpContent extends StatelessWidget {
  const _HelpContent();

  static const _faqs = [
    (
      'How do I get more likes?',
      'Complete your profile with clear photos and a full bio — profiles with 3+ photos get significantly more likes.',
    ),
    (
      'How do matches work?',
      'When you and someone else both like each other, it\'s a match — you can then message each other.',
    ),
    (
      'Can I change my subscription plan?',
      'Yes — open Manage Subscription from Settings or your Profile to switch plans anytime.',
    ),
    (
      'How do I report someone?',
      'Use the Report button on their profile card, or the shield icon in a chat.',
    ),
    (
      'How do I delete my account?',
      'Go to Settings → Delete Account. This is permanent and cannot be undone.',
    ),
  ];

  static const _safetyTips = [
    'Never send money to someone you haven\'t met in person.',
    'Video chat before meeting in person.',
    'Meet in a public place for your first date.',
    'Tell a friend or family member where you\'re going.',
    'Trust your instincts — report anything that feels off.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FAQ', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final (q, a) in _faqs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  a,
                  style: const TextStyle(
                    color: AppColors.mutedFg,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(LucideIcons.mail, size: 16, color: AppColors.mutedFg),
            SizedBox(width: 6),
            Text(AppConstants.supportEmail),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            Icon(LucideIcons.messageSquare, size: 16, color: AppColors.mutedFg),
            SizedBox(width: 6),
            Text('Chat on Google Chat'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showContactSupportDialog(context),
            icon: const Icon(LucideIcons.send, size: 16),
            label: const Text('Send us a message'),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Safety Tips',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final tip in _safetyTips)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: Text(tip, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _showContactSupportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ContactSupportDialog(),
  );
}

/// Sends a message to [AppConstants.supportEmail] via the live `send-email`
/// Edge Function (generic mailer, confirmed deployed 2026-07-13 — see
/// `app doctumant/BACKEND_EMAIL_HANDOFF.md`).
class _ContactSupportDialog extends ConsumerStatefulWidget {
  const _ContactSupportDialog();

  @override
  ConsumerState<_ContactSupportDialog> createState() =>
      _ContactSupportDialogState();
}

class _ContactSupportDialogState extends ConsumerState<_ContactSupportDialog> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (subject.isEmpty || body.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(supportEmailRepositoryProvider)
          .sendSupportMessage(
            to: AppConstants.supportEmail,
            subject: subject,
            body: body,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent — we\'ll get back to you soon.'),
        ),
      );
    } on SendEmailException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send your message — please try again later.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send us a message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
