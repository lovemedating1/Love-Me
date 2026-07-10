import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';
import 'discover_providers.dart';

/// Search-radius bottom sheet (old app: `4`/`WA0030`) — Worldwide toggle,
/// a big "N km" readout, a slider, and 9 preset chips. Replaces the old
/// generic age/gender/online filters sheet per UI_REBUILD_PLAN.md §2.5.
class DiscoverFiltersSheet extends ConsumerStatefulWidget {
  const DiscoverFiltersSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const DiscoverFiltersSheet(),
      );

  @override
  ConsumerState<DiscoverFiltersSheet> createState() =>
      _DiscoverFiltersSheetState();
}

class _DiscoverFiltersSheetState extends ConsumerState<DiscoverFiltersSheet> {
  late bool _worldwide = ref.read(worldwideSearchProvider);
  late int _radiusKm = ref.read(searchRadiusKmProvider);

  void _apply() {
    ref.read(worldwideSearchProvider.notifier).state = _worldwide;
    ref.read(searchRadiusKmProvider.notifier).state = _radiusKm;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Search Radius', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('🌍 Worldwide',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('See profiles from anywhere in the world'),
            value: _worldwide,
            onChanged: (v) => setState(() => _worldwide = v),
          ),
          if (!_worldwide) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$_radiusKm km',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.pink),
              ),
            ),
            Slider(
              min: 5,
              max: 5000,
              value: _radiusKm.toDouble().clamp(5, 5000),
              label: '$_radiusKm km',
              onChanged: (v) => setState(() => _radiusKm = v.round()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in kRadiusPresetsKm)
                  ChoiceChip(
                    label: Text('$preset km'),
                    selected: _radiusKm == preset,
                    onSelected: (_) => setState(() => _radiusKm = preset),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 12),
          GradientButton(
            label: _worldwide ? 'Apply worldwide' : 'Apply',
            onPressed: _apply,
          ),
        ],
      ),
    );
  }
}
