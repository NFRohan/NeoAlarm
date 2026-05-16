import 'package:flutter/material.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_timezone.dart';

class AlarmTimezonePickerSheet extends StatefulWidget {
  const AlarmTimezonePickerSheet({
    required this.timezones,
    required this.initialTimezoneId,
    required this.currentTimezoneId,
    super.key,
  });

  final List<String> timezones;
  final String initialTimezoneId;
  final String currentTimezoneId;

  static Future<String?> show(
    BuildContext context, {
    required List<String> timezones,
    required String initialTimezoneId,
    required String currentTimezoneId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlarmTimezonePickerSheet(
        timezones: timezones,
        initialTimezoneId: initialTimezoneId,
        currentTimezoneId: currentTimezoneId,
      ),
    );
  }

  @override
  State<AlarmTimezonePickerSheet> createState() =>
      _AlarmTimezonePickerSheetState();
}

class _AlarmTimezonePickerSheetState extends State<AlarmTimezonePickerSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredTimezones {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.timezones;
    }

    return widget.timezones
        .where((timezoneId) {
          final displayName = formatTimezoneDisplayName(
            timezoneId,
          ).toLowerCase();
          return timezoneId.toLowerCase().contains(query) ||
              displayName.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTimezones = _filteredTimezones;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: NeoPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    NeoSquareIconButton(
                      icon: Icons.close,
                      size: 42,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'TIME ZONE',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search city or timezone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Specific timezone alarms stay pinned to that location’s clock, even when you travel.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: NeoColors.subtext),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredTimezones.isEmpty
                    ? const Center(child: Text('No matching timezones found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredTimezones.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final timezoneId = filteredTimezones[index];
                          final isSelected =
                              timezoneId == widget.initialTimezoneId;
                          final isCurrent =
                              timezoneId == widget.currentTimezoneId;
                          return _TimezoneRow(
                            timezoneId: timezoneId,
                            isSelected: isSelected,
                            isCurrent: isCurrent,
                            onTap: () {
                              Navigator.of(context).pop(timezoneId);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimezoneRow extends StatelessWidget {
  const _TimezoneRow({
    required this.timezoneId,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  final String timezoneId;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected ? NeoColors.primary : NeoColors.panel;
    final foregroundColor = NeoColors.foregroundOn(backgroundColor);

    return InkWell(
      onTap: onTap,
      child: NeoPanel(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTimezoneDisplayName(timezoneId).toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: foregroundColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timezoneId,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isCurrent)
              _TimezoneBadge(label: 'Current', backgroundColor: NeoColors.cyan),
            if (isSelected) ...[
              if (isCurrent) const SizedBox(width: 8),
              _TimezoneBadge(
                label: 'Selected',
                backgroundColor: NeoColors.warm,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimezoneBadge extends StatelessWidget {
  const _TimezoneBadge({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: NeoColors.ink, width: 2),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: NeoColors.foregroundOn(backgroundColor),
        ),
      ),
    );
  }
}
