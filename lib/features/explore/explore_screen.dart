import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/data/repositories.dart';
import '../../shared/widgets/profile_tile.dart';
import '../../shared/widgets/state_views.dart';

/// 09 — ExplorePage (tab body). Country flag chips + 2-col profile grid.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _country = MockData.countries.first.name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = ref.watch(profilesByCountryProvider(_country));

    return Column(
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: MockData.countries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = MockData.countries[i];
              final selected = c.name == _country;
              return GestureDetector(
                onTap: () => setState(() => _country = c.name),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : Colors.transparent),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 24)),
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall),
                      Text('${c.count}', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: grid.when(
            loading: () => GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: List.generate(
                  6, (_) => const SkeletonBox(height: double.infinity, radius: 16)),
            ),
            error: (_, _) => ErrorView(
                message: 'Could not load profiles.',
                onRetry: () =>
                    ref.invalidate(profilesByCountryProvider(_country))),
            data: (people) {
              if (people.isEmpty) {
                return EmptyView(
                    icon: LucideIcons.globe,
                    message: 'No users in $_country yet.');
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: people.length,
                itemBuilder: (_, i) => ProfileTile(
                  profile: people[i],
                  onTap: () => context.push(RoutePaths.chatTo(people[i].userId)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
