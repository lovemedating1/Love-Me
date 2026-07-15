import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/country_flags.dart';
import '../../shared/data/repositories.dart';
import '../../shared/widgets/profile_preview_modal.dart';
import '../../shared/widgets/profile_tile.dart';
import '../../shared/widgets/state_views.dart';

/// 09 — ExplorePage (tab body).
///
/// Rebuilt for UI parity (Phase 3, `WA0043`) — see UI_REBUILD_PLAN.md §3.4:
/// a searchable **3-column grid of all countries** (flag · name · user
/// count) instead of the old horizontal flag-chip strip; tapping a country
/// opens a user-list modal, and tapping a user opens the shared
/// profile-preview modal instead of jumping straight to chat.
///
/// Country counts come from [countryCountsProvider] — real
/// `profiles_discoverable` rows grouped by country (client-side aggregate
/// today; prefers the proposed `get_country_counts` RPC once backend ships
/// it, see `BACKEND_BTIER_HANDOFF.md` §1). Only countries with at least one
/// real user appear — no fabricated minimums.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countsAsync = ref.watch(countryCountsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Explore',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Discover people worldwide',
          style: TextStyle(color: AppColors.mutedFg),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(LucideIcons.globe, size: 16, color: AppColors.pink),
            SizedBox(width: 6),
            Text(
              'Browse by Country',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.pink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search countries…',
            prefixIcon: Icon(LucideIcons.search),
          ),
        ),
        const SizedBox(height: 16),
        countsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(top: 40),
            child: ErrorView(
              message: 'Could not load countries.',
              onRetry: () => ref.invalidate(countryCountsProvider),
            ),
          ),
          data: (counts) {
            final countries =
                counts.entries
                    .where(
                      (e) => e.key.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList()
                  ..sort((a, b) => a.key.compareTo(b.key));

            if (countries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyView(
                  icon: LucideIcons.globe,
                  message: 'No countries match your search.',
                ),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: countries.length,
              itemBuilder: (_, i) =>
                  _countryCard(context, countries[i].key, countries[i].value),
            );
          },
        ),
      ],
    );
  }

  Widget _countryCard(BuildContext context, String name, int count) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openCountry(context, name, count),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              CountryFlags.forCountry(name),
              style: const TextStyle(fontSize: 30),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '$count users',
              style: const TextStyle(color: AppColors.mutedFg, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );

  void _openCountry(BuildContext context, String name, int count) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CountryUsersSheet(countryName: name, count: count),
    );
  }
}

class _CountryUsersSheet extends ConsumerWidget {
  const _CountryUsersSheet({required this.countryName, required this.count});

  final String countryName;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final people = ref.watch(profilesByCountryProvider(countryName));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  CountryFlags.forCountry(countryName),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$countryName ($count users)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: people.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorView(
                message: 'Could not load profiles.',
                onRetry: () =>
                    ref.invalidate(profilesByCountryProvider(countryName)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    icon: LucideIcons.globe,
                    message: 'No users in $countryName yet.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ProfileTile(
                      profile: p,
                      onTap: () {
                        Navigator.of(context).pop();
                        ProfilePreviewModal.show(context, p);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
