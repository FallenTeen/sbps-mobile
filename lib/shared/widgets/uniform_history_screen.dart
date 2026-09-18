import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Uniform History Screen Component (Fase 2)
/// Provides consistent period chips, status filters, and pagination across history screens.
///
/// Usage: Wrap your history screen content with this widget to get consistent UI.
class UniformHistoryScreen extends ConsumerStatefulWidget {
  const UniformHistoryScreen({
    super.key,
    required this.title,
    required this.periodOptions,
    required this.statusOptions,
    required this.child,
    this.onPeriodChanged,
    this.onStatusChanged,
    this.selectedPeriod,
    this.selectedStatus,
    this.showPeriodChips = true,
    this.showStatusChips = true,
  });

  final String title;
  final List<String> periodOptions;
  final List<String> statusOptions;
  final Widget child;
  final ValueChanged<String?>? onPeriodChanged;
  final ValueChanged<String?>? onStatusChanged;
  final String? selectedPeriod;
  final String? selectedStatus;
  final bool showPeriodChips;
  final bool showStatusChips;

  @override
  ConsumerState<UniformHistoryScreen> createState() =>
      _UniformHistoryScreenState();
}

class _UniformHistoryScreenState extends ConsumerState<UniformHistoryScreen> {
  String? _selectedPeriod;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.selectedPeriod;
    _selectedStatus = widget.selectedStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: []),
      body: Column(
        children: [
          // Period Filter Chips (Fase 2)
          if (widget.showPeriodChips)
            _PeriodFilterSection(
              options: widget.periodOptions,
              selected: _selectedPeriod,
              onChanged: (value) {
                setState(() => _selectedPeriod = value);
                widget.onPeriodChanged?.call(value);
              },
            ),

          // Status Filter Chips (Fase 2)
          if (widget.showStatusChips)
            _StatusFilterSection(
              options: widget.statusOptions,
              selected: _selectedStatus,
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                widget.onStatusChanged?.call(value);
              },
            ),

          // Content
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _PeriodFilterSection extends StatelessWidget {
  const _PeriodFilterSection({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Periode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option),
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                    labelPadding: EdgeInsets.symmetric(horizontal: 4),
                    selected: selected == option,
                    onSelected: (bool isSelected) {
                      onChanged(isSelected ? option : null);
                    },
                    selectedColor: context.colors.primary.withValues(
                      alpha: 0.1,
                    ),
                    checkmarkColor: context.colors.primary,
                    labelStyle: TextStyle(
                      color: selected == option
                          ? context.colors.primary
                          : context.colors.textPrimary,
                      fontWeight: selected == option
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterSection extends StatelessWidget {
  const _StatusFilterSection({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option),
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                    labelPadding: EdgeInsets.symmetric(horizontal: 4),
                    selected: selected == option,
                    onSelected: (bool isSelected) {
                      onChanged(isSelected ? option : null);
                    },
                    selectedColor: context.colors.primary.withValues(
                      alpha: 0.1,
                    ),
                    checkmarkColor: context.colors.primary,
                    labelStyle: TextStyle(
                      color: selected == option
                          ? context.colors.primary
                          : context.colors.textPrimary,
                      fontWeight: selected == option
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pagination Widget (Fase 2)
/// Provides consistent "Load More" functionality for paginated lists.
class PaginationWidget extends StatelessWidget {
  const PaginationWidget({
    super.key,
    required this.hasMore,
    required this.isLoading,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool isLoading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Tidak ada data lagi',
            style: TextStyle(color: context.colors.textTertiary),
          ),
        ),
      );
    }

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: onLoadMore,
        icon: const Icon(Icons.expand_more),
        label: const Text('Muat lebih banyak'),
      ),
    );
  }
}
