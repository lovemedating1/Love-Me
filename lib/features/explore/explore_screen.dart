import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/data/repositories.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/profile_preview_modal.dart';
import '../../shared/widgets/state_views.dart';

/// 09 — ExplorePage (tab body).
///
/// Rebuilt for UI parity (Phase 3, `WA0043`) — see UI_REBUILD_PLAN.md §3.4:
/// a searchable **3-column grid of all countries** (flag · name · user
/// count) instead of the old horizontal flag-chip strip; tapping a country
/// opens a user-list modal, and tapping a user opens the shared
/// profile-preview modal instead of jumping straight to chat.
///
/// Country counts come from `MockData.countries` — there is no
/// `get_country_counts` RPC server-side yet ([BE-9]), so these are the same
/// placeholder counts the mock feed has always used, not live data.
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
    final countries = MockData.countries
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text('Explore',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Discover people worldwide',
            style: TextStyle(color: AppColors.mutedFg)),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(LucideIcons.globe, size: 16, color: AppColors.pink),
            SizedBox(width: 6),
            Text('Browse by Country',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.pink)),
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
        if (countries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyView(
                icon: LucideIcons.globe, message: 'No countries match your search.'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: countries.length,
            itemBuilder: (_, i) => _countryCard(context, countries[i]),
          ),
      ],
    );
  }

  Widget _countryCard(BuildContext context, ({String flag, String name, int count}) c) =>
      Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openCountry(context, c),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 8),
                Text(c.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${c.count} users',
                    style: const TextStyle(color: AppColors.mutedFg, fontSize: 11)),
              ],
            ),
          ),
        ),
      );

  void _openCountry(BuildContext context, ({String flag, String name, int count}) c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CountryUsersSheet(country: c),
    );
  }
}

class _CountryUsersSheet extends ConsumerWidget {
  const _CountryUsersSheet({required this.country});

  final ({String flag, String name, int count}) country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final people = ref.watch(profilesByCountryProvider(country.name));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(country.flag, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${country.name} (${country.count} users)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
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
                  onRetry: () => ref.invalidate(profilesByCountryProvider(country.name))),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                      icon: LucideIcons.globe,
                      message: 'No users in ${country.name} yet.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      leading: AppAvatar(photoUrl: p.photoUrl, size: 44, isVerified: p.isVerified),
                      title: Text(p.name),
                      subtitle: Text('${p.city}, ${p.country}'),
                      trailing: Text(p.ageLabel,
                          style: const TextStyle(color: AppColors.mutedFg)),
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
