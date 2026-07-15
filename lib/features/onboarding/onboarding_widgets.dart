import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// One selectable option in a [DropdownSheetField] — a label plus a
/// trailing emoji (e.g. "Single", "💫").
class SheetOption {
  const SheetOption(this.value, this.label, {this.emoji});
  final String value;
  final String label;
  final String? emoji;
}

/// Bold black label above a field, matching the old app's field-label style
/// (used throughout onboarding instead of Material's floating labelText).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: AppColors.fgSoft,
      ),
    ),
  );
}

/// The old app's "tap to select…" field — an outlined rounded box that
/// opens a white rounded-list overlay directly below it (inline, not a full
/// modal sheet) with one full-width row per option, a trailing emoji, and
/// the selected row highlighted with a solid gold fill.
///
/// If [selected] is non-null and [removable] is true, the field renders as
/// a solid pink pill with the value + a white ✕ instead of the plain
/// outline box, matching the old app's post-selection look on some fields.
class DropdownSheetField extends StatefulWidget {
  const DropdownSheetField({
    super.key,
    required this.hint,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.removable = false,
  });

  final String hint;
  final List<SheetOption> options;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool removable;

  @override
  State<DropdownSheetField> createState() => _DropdownSheetFieldState();
}

class _DropdownSheetFieldState extends State<DropdownSheetField> {
  bool _open = false;

  SheetOption? get _selectedOption => widget.selected == null
      ? null
      : widget.options.where((o) => o.value == widget.selected).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final option = _selectedOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.removable && option != null)
          _pill(option)
        else
          _field(option),
        if (_open) _optionsList(),
      ],
    );
  }

  Widget _pill(SheetOption option) => GestureDetector(
    onTap: () => setState(() => _open = !_open),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.pink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              option.emoji == null
                  ? option.label
                  : '${option.label} ${option.emoji}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => widget.onChanged(null),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    ),
  );

  Widget _field(SheetOption? option) => GestureDetector(
    onTap: () => setState(() => _open = !_open),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              option == null
                  ? widget.hint
                  : (option.emoji == null
                        ? option.label
                        : '${option.label} ${option.emoji}'),
              style: TextStyle(
                color: option == null ? AppColors.mutedFg : AppColors.fgSoft,
                fontWeight: option == null
                    ? FontWeight.normal
                    : FontWeight.w600,
              ),
            ),
          ),
          Icon(
            _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: AppColors.mutedFg,
          ),
        ],
      ),
    ),
  );

  Widget _optionsList() => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final o in widget.options) _optionRow(o)],
    ),
  );

  Widget _optionRow(SheetOption o) {
    final selected = o.value == widget.selected;
    return GestureDetector(
      onTap: () {
        widget.onChanged(o.value);
        setState(() => _open = false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: selected ? AppColors.gold : Colors.transparent,
        child: Text(
          o.emoji == null ? o.label : '${o.label} ${o.emoji}',
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: AppColors.fgSoft,
          ),
        ),
      ),
    );
  }
}

/// Amber warning banner (old app: birthday-accuracy warning under Step 1's
/// date field). Bold spans render the important phrases.
class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.chipYellowBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.goldWarm, size: 18),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    ),
  );
}
