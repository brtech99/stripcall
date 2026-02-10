import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Adaptive dropdown that uses Material DropdownButtonFormField on Android/web
/// and a Cupertino-style picker on iOS.
///
/// Usage:
/// ```dart
/// AppDropdown<String>(
///   value: selectedValue,
///   items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
///   onChanged: (value) => setState(() => selectedValue = value),
///   label: 'Select Option',
/// )
/// ```
class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final bool isExpanded;
  final double? menuMaxHeight;
  final Key? dropdownKey;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.isExpanded = true,
    this.menuMaxHeight,
    this.dropdownKey,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _buildCupertinoDropdown(context);
    }

    return _buildMaterialDropdown(context);
  }

  Widget _buildCupertinoDropdown(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Find current selection label
    String currentLabel = hint ?? 'Select...';
    for (final item in items) {
      if (item.value == value && item.child is Text) {
        currentLabel = (item.child as Text).data ?? currentLabel;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: onChanged == null ? null : () => _showCupertinoPicker(context),
          child: Container(
            key: dropdownKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surface,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    currentLabel,
                    style: TextStyle(
                      color: value == null 
                          ? colorScheme.onSurfaceVariant 
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCupertinoPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Find current index
    int initialIndex = 0;
    for (int i = 0; i < items.length; i++) {
      if (items[i].value == value) {
        initialIndex = i;
        break;
      }
    }

    T? selectedValue = value;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                color: colorScheme.surfaceContainerHighest,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onChanged?.call(selectedValue);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  itemExtent: 32,
                  onSelectedItemChanged: (int index) {
                    selectedValue = items[index].value;
                  },
                  children: items.map((item) {
                    if (item.child is Text) {
                      return Center(child: item.child);
                    }
                    return Center(child: item.child);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaterialDropdown(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: dropdownKey,
      value: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      isExpanded: isExpanded,
      menuMaxHeight: menuMaxHeight,
      items: items,
      onChanged: onChanged,
    );
  }
}
