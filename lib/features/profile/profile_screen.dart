import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/media/photo_picker_service.dart';
import '../../core/media/photo_source_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/validators.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/profile.dart';
import '../../shared/models/profile_photo.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../auth/auth_controller.dart';

/// Gallery is capped at 4 photos total — the hard `display_order` (1-4)
/// constraint on `profile_photos`, not the front-end AppConstants figure.
const _maxProfilePhotos = 4;

/// 10 — ProfilePage (tab body). Own profile summary + entry to settings,
/// subscription, safety, sign out.
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
          onRetry: () => ref.invalidate(currentUserProvider)),
      data: (p) => _content(context, ref, p, isPremium),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Profile p, bool isPremium) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        _banner(context, ref, p, isPremium),
        const SizedBox(height: 12),
        _statsRow(theme, ref),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () => _editSheet(context, ref, p),
            icon: const Icon(LucideIcons.pencil),
            label: const Text('Edit Profile'),
          ),
        ),
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _upgradeCard(context),
          ),
        const SizedBox(height: 8),
        if (p.bio != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(p.bio!, style: theme.textTheme.bodyMedium),
          ),
        _gallerySection(context, ref),
        const Divider(height: 24),
        // Demo toggle so the free/premium gates are testable without a backend.
        SwitchListTile(
          secondary: const Icon(LucideIcons.crown, color: AppColors.gold),
          title: const Text('Premium (demo toggle)'),
          subtitle: const Text('Mock — flips free/premium gates'),
          value: isPremium,
          onChanged: (v) => ref.read(isPremiumProvider.notifier).state = v,
        ),
        _row(context, LucideIcons.settings, 'Settings', RoutePaths.settings),
        _row(context, LucideIcons.bell, 'Notifications', RoutePaths.notifications),
        _row(context, LucideIcons.monitor, 'Devices', RoutePaths.devices),
        _row(context, LucideIcons.shield, 'Safety Reports', RoutePaths.safetyReports),
        _row(context, LucideIcons.crown, 'Manage Subscription', RoutePaths.subscription),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive),
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Log out'),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.push(RoutePaths.deleteAccount),
            child: const Text('Delete account',
                style: TextStyle(color: AppColors.destructive)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _banner(
      BuildContext context, WidgetRef ref, Profile p, bool isPremium) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.header),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          Stack(
            children: [
              AppAvatar(photoUrl: p.photoUrl, size: 84, isVerified: p.isVerified),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _changeAvatar(context, ref),
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(LucideIcons.camera,
                        size: 14, color: AppColors.pink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('${p.name}, ${p.ageLabel}',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(color: Colors.white)),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.crown, color: AppColors.gold),
                    ],
                  ],
                ),
                Text('${p.city}, ${p.country}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live counts from `likes` / `matches`. **Views shows "–"**: the
  /// `profile_views` RLS only exposes views *you made*, not views *of you*,
  /// so "who viewed me" is not obtainable until a premium RPC exists
  /// (migration_002.md §5). Showing a dash beats inventing a number.
  Widget _statsRow(ThemeData theme, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _stat(theme, 'Views', null),
          _stat(theme, 'Likes', stats.valueOrNull?.likes),
          _stat(theme, 'Matches', stats.valueOrNull?.matches),
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, int? value) => Expanded(
        child: Column(
          children: [
            Text(value?.toString() ?? '–', style: theme.textTheme.titleLarge),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      );

  Widget _upgradeCard(BuildContext context) => GestureDetector(
        onTap: () => context.push(RoutePaths.subscription),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: AppGradients.premium,
              borderRadius: BorderRadius.circular(16)),
          child: const Row(
            children: [
              Icon(LucideIcons.crown, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Upgrade to Premium',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              Icon(LucideIcons.chevronRight, color: Colors.white),
            ],
          ),
        ),
      );

  Widget _gallerySection(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(myPhotosProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: photos.when(
        loading: () => const SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => ErrorView(
            message: 'Could not load photos.',
            onRetry: () => ref.invalidate(myPhotosProvider)),
        data: (list) => _gallery(context, ref, list),
      ),
    );
  }

  Widget _gallery(BuildContext context, WidgetRef ref, List<ProfilePhoto> photos) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final photo in photos)
          GestureDetector(
            onTap: photo.isPrimary ? null : () => _setPrimary(context, ref, photo),
            onLongPress: () => _deletePhoto(context, ref, photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(photo.photoUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: const Color(0x22E6287A))),
                  if (photo.isPrimary)
                    const Positioned(
                      top: 4,
                      left: 4,
                      child: Icon(LucideIcons.star,
                          color: AppColors.gold, size: 16),
                    ),
                ],
              ),
            ),
          ),
        if (photos.length < _maxProfilePhotos)
          GestureDetector(
            onTap: () => _addPhoto(context, ref, photos),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(LucideIcons.plus),
              ),
            ),
          ),
      ],
    );
  }

  /// Lets the user take/choose a photo, validates on-device that it contains
  /// a face (rejecting non-person photos), uploads it to the `avatars` bucket,
  /// and inserts a `profile_photos` row at the next free slot.
  Future<void> _addPhoto(
      BuildContext context, WidgetRef ref, List<ProfilePhoto> existing) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null) return;

    final usedSlots = existing.map((p) => p.displayOrder).toSet();
    final freeSlot = [1, 2, 3, 4].firstWhere((s) => !usedSlots.contains(s));
    try {
      final picker = ref.read(photoPickerServiceProvider);
      final picked = await picker.pickProfilePhoto(source);

      final repo = ref.read(profilePhotoRepositoryProvider);
      final url = await repo.uploadPhoto(picked.bytes,
          fileExtension: picked.fileExtension);
      await repo.addPhoto(
        photoUrl: url,
        displayOrder: freeSlot,
        isPrimary: existing.isEmpty,
      );
      ref.invalidate(myPhotosProvider);
      if (existing.isEmpty) ref.invalidate(currentUserProvider);
    } on PhotoPickCancelled {
      // User backed out — no-op.
    } on NoFaceDetectedException {
      if (context.mounted) {
        _toast(
            context,
            'That doesn\'t look like a photo of a person. Please upload a '
            'clear photo of yourself.',
            error: true);
      }
    } on ProfilePhotoSlotTakenException {
      if (context.mounted) _toast(context, 'That slot is taken — try again.', error: true);
    } on MediaUploadException catch (e) {
      if (context.mounted) _toast(context, e.message, error: true);
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not add photo: $e', error: true);
    }
  }

  Future<void> _setPrimary(
      BuildContext context, WidgetRef ref, ProfilePhoto photo) async {
    try {
      await ref.read(profilePhotoRepositoryProvider).setPrimary(photo.id);
      ref.invalidate(myPhotosProvider);
      ref.invalidate(currentUserProvider);
    } catch (_) {
      if (context.mounted) {
        _toast(context, 'Could not set primary photo — try again.', error: true);
      }
    }
  }

  /// Avatar camera badge — pick a new photo (face-validated), upload it, and
  /// make it the primary. If the gallery is already full (4), the current
  /// primary is replaced; otherwise the new photo is added at a free slot.
  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null) return;

    try {
      final picker = ref.read(photoPickerServiceProvider);
      final picked = await picker.pickProfilePhoto(source);

      final repo = ref.read(profilePhotoRepositoryProvider);
      final photos = await repo.myPhotos();
      final usedSlots = photos.map((p) => p.displayOrder).toSet();
      final freeSlot =
          [1, 2, 3, 4].where((s) => !usedSlots.contains(s)).firstOrNull;

      // Gallery full → free the current primary's slot first.
      var slot = freeSlot;
      if (slot == null) {
        final primary = photos.where((p) => p.isPrimary).firstOrNull ??
            (photos.isNotEmpty ? photos.first : null);
        if (primary != null) {
          await repo.deletePhoto(primary.id);
          slot = primary.displayOrder;
        } else {
          slot = 1;
        }
      }

      final url = await repo.uploadPhoto(picked.bytes,
          fileExtension: picked.fileExtension);
      await repo.addPhoto(photoUrl: url, displayOrder: slot, isPrimary: true);

      ref.invalidate(myPhotosProvider);
      ref.invalidate(currentUserProvider);
    } on PhotoPickCancelled {
      // User backed out — no-op.
    } on NoFaceDetectedException {
      if (context.mounted) {
        _toast(
            context,
            'That doesn\'t look like a photo of a person. Please upload a '
            'clear photo of yourself.',
            error: true);
      }
    } on MediaUploadException catch (e) {
      if (context.mounted) _toast(context, e.message, error: true);
    } catch (e) {
      if (context.mounted) {
        _toast(context, 'Could not update photo: $e', error: true);
      }
    }
  }

  Future<void> _deletePhoto(
      BuildContext context, WidgetRef ref, ProfilePhoto photo) async {
    try {
      await ref.read(profilePhotoRepositoryProvider).deletePhoto(photo.id);
      ref.invalidate(myPhotosProvider);
      if (photo.isPrimary) ref.invalidate(currentUserProvider);
    } catch (_) {
      if (context.mounted) {
        _toast(context, 'Could not delete photo — try again.', error: true);
      }
    }
  }

  void _toast(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.destructive : AppColors.pink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Widget _row(BuildContext context, IconData icon, String label, String route) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: () => context.push(route),
      );

  void _editSheet(BuildContext context, WidgetRef ref, Profile p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProfileSheet(profile: p),
    );
  }
}

/// Edit Profile — persists `name` to the live `profiles` row.
///
/// `bio` is deliberately absent: there is **no `bio` column** in the live
/// schema (it's a local-only field on [Profile]). It was previously rendered
/// with a throwaway controller and a Save button that saved nothing; showing
/// nothing is more honest than a field that silently discards input. Restore
/// it once the column ships (BACKEND_REMAINING.md [BE-13]).
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
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
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(name: name);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _error,
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
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
