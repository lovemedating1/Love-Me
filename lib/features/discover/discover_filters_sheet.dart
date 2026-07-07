import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'discover_providers.dart';

/// Bottom sheet for Discover feed filters (age, distance, gender, toggles).
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
  late DiscoverFilters _draft = ref.read(discoverFiltersProvider);

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
          Text('Filters', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Age: ${_draft.minAge} – ${_draft.maxAge}'),
          RangeSlider(
            min: 18,
            max: 80,
            divisions: 62,
            values: RangeValues(
                _draft.minAge.toDouble(), _draft.maxAge.toDouble()),
            labels: RangeLabels('${_draft.minAge}', '${_draft.maxAge}'),
            onChanged: (v) => setState(() => _draft = _draft.copyWith(
                minAge: v.start.round(), maxAge: v.end.round())),
          ),
          Text('Distance: up to ${_draft.maxDistanceKm.round()} km'),
          Slider(
            min: 1,
            max: 500,
            divisions: 499,
            value: _draft.maxDistanceKm,
            label: '${_draft.maxDistanceKm.round()} km',
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(maxDistanceKm: v)),
          ),
          const SizedBox(height: 8),
          Text('Show me', style: theme.textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              _genderChip('Everyone', null),
              _genderChip('Men', 'male'),
              _genderChip('Women', 'female'),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Online only'),
            value: _draft.onlineOnly,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(onlineOnly: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verified only'),
            value: _draft.verifiedOnly,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(verifiedOnly: v)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    ref.read(discoverFiltersProvider.notifier).reset();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(discoverFiltersProvider.notifier).set(_draft);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderChip(String label, String? value) => ChoiceChip(
        label: Text(label),
        selected: _draft.gender == value,
        onSelected: (_) => setState(() => _draft = value == null
            ? _draft.copyWith(clearGender: true)
            : _draft.copyWith(gender: value)),
      );
}
