import 'package:flutter/material.dart';

class FilterChips extends StatelessWidget {
  final String categoryFilter;
  final String timeFilter;
  final Function(String) onCategoryChanged;
  final Function(String) onTimeChanged;

  const FilterChips({
    super.key,
    required this.categoryFilter,
    required this.timeFilter,
    required this.onCategoryChanged,
    required this.onTimeChanged,
  });

  final List<String> categories = const ['tümü', 'spor', 'müzik', 'eğlence'];
  final List<String> timeFilters = const ['Tümü', 'Bugün', 'Bu Hafta'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Tümü'),
              selected: categoryFilter == 'tümü',
              onSelected: (_) => onCategoryChanged('tümü'),
            ),
          ),
          ...categories.skip(1).map((filter) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: categoryFilter == filter,
              onSelected: (_) => onCategoryChanged(filter),
            ),
          )),
        ],
      ),
    );
  }
}