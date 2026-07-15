import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_paths.dart';
import '../../core/media/photo_picker_service.dart';
import '../../core/media/photo_source_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/profile.dart';
import '../../shared/models/profile_photo.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/state_views.dart';
import '../auth/auth_controller.dart';

/// 10 — ProfilePage (tab body).
///
/// Rebuilt for UI parity (Phase 3, `WA0045`) — see UI_REBUILD_PLAN.md §3.2.
/// Per Phase 0 §0.4 (match the old app exactly), this REMOVES the stats row,
/// the 4-photo gallery grid, the "Premium (demo toggle)" switch, and the
/// bio block — none of those exist in the old app's Profile tab. Photo
/// changes now happen only via the avatar's camera badge.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final isPremium = ref.watch(isPremiumProvider);
    return me.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorView(
        message: 'Could not load your profile.',
        onRetry: () => ref.invalidate(currentUserProvider),
      ),
      data: (p) => _content(context, ref, p, isPremium),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    Profile p,
    bool isPremium,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _profileCard(context, ref, p),
        const SizedBox(height: 14),
        if (isPremium) _managePlanCard(context, p),
        if (!isPremium) _upgradeCard(context),
        const SizedBox(height: 14),
        _rowsCard(context, ref),
      ],
    );
  }

  // ---- White profile card -------------------------------------------------

  Widget _profileCard(BuildContext context, WidgetRef ref, Profile p) {
    final theme = Theme.of(context);
    final photos = ref.watch(myPhotosProvider).valueOrNull ?? const [];
    final primary = photos.where((ph) => ph.isPrimary).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(top: 0, right: 0, child: _pencilFab(context, ref, p)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: double.infinity),
              Stack(
                children: [
                  AppAvatar(
                    photoUrl: p.photoUrl,
                    size: 88,
                    isVerified: p.isVerified,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => _changeAvatar(context, ref),
                      child: const CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white,
                        child: Icon(
                          LucideIcons.camera,
                          size: 15,
                          color: AppColors.pink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (primary != null &&
                  primary.moderationStatus !=
                      PhotoModerationStatus.approved) ...[
                const SizedBox(height: 8),
                _moderationBadge(primary.moderationStatus),
              ],
              const SizedBox(height: 12),
              Text(
                '${p.name}, ${p.ageLabel}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '📍 ${p.city}, ${p.country}',
                style: const TextStyle(color: AppColors.mutedFg),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  const AppChip(
                    label: 'Location is on',
                    icon: LucideIcons.compass,
                    tone: AppChipTone.grey,
                    dense: true,
                  ),
                  if (p.isPremium)
                    AppChip(
                      label: p.premiumDaysLeft == null
                          ? 'Premium Active'
                          : 'Premium Active · ${p.premiumDaysLeft}d left',
                      emoji: '👑',
                      tone: AppChipTone.pink,
                      dense: true,
                    ),
                ],
              ),
              if (p.relationshipGoal != null) ...[
                const SizedBox(height: 10),
                Text(
                  '♥ Need a ${p.relationshipGoal}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if ((p.occupation ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '💼 ${p.occupation}',
                  style: const TextStyle(color: AppColors.mutedFg),
                ),
              ],
              if ((p.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.bio!, textAlign: TextAlign.center),
              ],
              if (p.interests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final interest in p.interests)
                      AppChip(
                        label: interest,
                        tone: AppChipTone.pink,
                        dense: true,
                      ),
                  ],
                ),
              ],
              if (p.hobbies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final hobby in p.hobbies)
                      AppChip(
                        label: hobby,
                        tone: AppChipTone.grey,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Shown when the primary photo's `moderation_status` (proposed column,
  /// see `BACKEND_ATIER_HANDOFF.md` §5) isn't `approved` yet. Never shown
  /// today since that column doesn't exist server-side ([BE-5]/[BE-8]) —
  /// [ProfilePhoto.fromJson] defaults every photo to `approved` until then.
  Widget _moderationBadge(PhotoModerationStatus status) {
    final (label, color, icon) = switch (status) {
      PhotoModerationStatus.pending => (
        'Photo under review',
        AppColors.gold,
        LucideIcons.clock,
      ),
      PhotoModerationStatus.rejected => (
        'Photo rejected — please update it',
        AppColors.destructive,
        LucideIcons.circleAlert,
      ),
      PhotoModerationStatus.approved => (
        '',
        AppColors.success,
        LucideIcons.check,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pencilFab(BuildContext context, WidgetRef ref, Profile p) => Material(
    color: AppColors.pink,
    shape: const CircleBorder(),
    elevation: 2,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _editSheet(context, ref, p),
      child: const Padding(
        padding: EdgeInsets.all(9),
        child: Icon(LucideIcons.pencil, color: Colors.white, size: 17),
      ),
    ),
  );

  Widget _managePlanCard(BuildContext context, Profile p) => GestureDetector(
    onTap: () => context.push(RoutePaths.subscription),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.managePlan,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.crown, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Plan: Gold',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (p.premiumUntil != null)
                  Text(
                    'Expires ${_formatDate(p.premiumUntil!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: Colors.white),
        ],
      ),
    ),
  );

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _upgradeCard(BuildContext context) => GestureDetector(
    onTap: () => context.push(RoutePaths.subscription),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.managePlan,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.crown, color: Colors.white),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Upgrade to Premium',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(LucideIcons.chevronRight, color: Colors.white),
        ],
      ),
    ),
  );

  // ---- 3 rows: Settings · Safety Reports · Log Out ------------------------

  Widget _rowsCard(BuildContext context, WidgetRef ref) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppTheme.cardShadow,
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _row(context, LucideIcons.settings, 'Settings', RoutePaths.settings),
        const Divider(height: 1),
        _row(
          context,
          LucideIcons.shield,
          'My Safety Reports',
          RoutePaths.safetyReports,
        ),
        const Divider(height: 1),
        _row(
          context,
          LucideIcons.userX,
          'Blocked Users',
          RoutePaths.blockedUsers,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(LucideIcons.logOut, color: AppColors.destructive),
          title: const Text(
            'Log Out',
            style: TextStyle(color: AppColors.destructive),
          ),
          onTap: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    ),
  );

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(LucideIcons.chevronRight, size: 18),
    onTap: () => context.push(route),
  );

  // ---- Actions --------------------------------------------------------

  void _editSheet(BuildContext context, WidgetRef ref, Profile p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProfileSheet(profile: p),
    );
  }

  /// Avatar camera badge — the sole photo-change entry point now that the
  /// gallery grid is removed (per Phase 0 §0.4 #4). Picks/validates a face,
  /// uploads, and makes it primary; replaces the current primary if the
  /// gallery is already at the 4-photo cap.
  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null) return;

    try {
      final picker = ref.read(photoPickerServiceProvider);
      final picked = await picker.pickProfilePhoto(source);

      final repo = ref.read(profilePhotoRepositoryProvider);
      final photos = await repo.myPhotos();
      final usedSlots = photos.map((p) => p.displayOrder).toSet();
      final freeSlot = [
        1,
        2,
        3,
        4,
      ].where((s) => !usedSlots.contains(s)).firstOrNull;

      var slot = freeSlot;
      if (slot == null) {
        final primary =
            photos.where((p) => p.isPrimary).firstOrNull ??
            (photos.isNotEmpty ? photos.first : null);
        if (primary != null) {
          await repo.deletePhoto(primary.id);
          slot = primary.displayOrder;
        } else {
          slot = 1;
        }
      }

      final url = await repo.uploadPhoto(
        picked.bytes,
        fileExtension: picked.fileExtension,
      );
      await repo.addPhoto(photoUrl: url, displayOrder: slot, isPrimary: true);

      ref.invalidate(currentUserProvider);
    } on PhotoPickCancelled {
      // User backed out — no-op.
    } on NoFaceDetectedException {
      if (context.mounted) {
        _toast(
          context,
          'That doesn\'t look like a photo of a person. Please upload a '
          'clear photo of yourself.',
          error: true,
        );
      }
    } on MediaUploadException catch (e) {
      if (context.mounted) _toast(context, e.message, error: true);
    } catch (e) {
      if (context.mounted) {
        _toast(context, 'Could not update photo: $e', error: true);
      }
    }
  }

  void _toast(BuildContext context, String msg, {bool error = false}) {
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
}

/// Edit Profile — persists `name` (live column) plus `bio`/`interests`/
/// `occupation` (proposed columns, see `BACKEND_BTIER_HANDOFF.md` §4,
/// [BE-13]) to the `profiles` row. The extended fields round-trip through
/// `Profile`/`updateMyProfile` like any other field — until backend adds
/// those columns, the PATCH simply won't have anywhere to write them and
/// they'll keep reading back empty next load, same as before this pass but
/// no longer silently discarded by a dead-end UI control.
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');
  late final _occupation = TextEditingController(
    text: widget.profile.occupation ?? '',
  );
  late final _interests = TextEditingController(
    text: widget.profile.interests.join(', '),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _occupation.dispose();
    _interests.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final invalid = Validators.displayName(name);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final interests = _interests.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(AppConstants.maxInterests)
        .toList();
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateMyProfile(
            name: name,
            bio: _bio.text.trim(),
            interests: interests,
            occupation: _occupation.text.trim(),
          );
      ref.invalidate(currentUserProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save — try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_saving,
              decoration: InputDecoration(labelText: 'Name', errorText: _error),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _occupation,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Occupation'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bio,
              enabled: !_saving,
              maxLines: 3,
              maxLength: AppConstants.maxBioChars,
              decoration: const InputDecoration(
                labelText: 'Bio',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _interests,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Interests',
                hintText: 'Comma-separated, up to ${AppConstants.maxInterests}',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
