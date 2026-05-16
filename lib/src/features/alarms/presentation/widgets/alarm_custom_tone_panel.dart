import 'package:flutter/material.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_tone.dart';
import 'package:neoalarm/src/features/alarms/presentation/widgets/alarm_editor_widgets.dart';

class AlarmCustomTonePanel extends StatelessWidget {
  const AlarmCustomTonePanel({
    required this.tones,
    required this.tonesLoading,
    required this.toneLibraryError,
    required this.selectedToneId,
    required this.onToneSelected,
    required this.onImportTone,
    required this.onManageTones,
    super.key,
  });

  final List<AlarmTone> tones;
  final bool tonesLoading;
  final String? toneLibraryError;
  final String? selectedToneId;
  final ValueChanged<String?> onToneSelected;
  final VoidCallback onImportTone;
  final VoidCallback? onManageTones;

  AlarmTone? get _selectedTone {
    for (final tone in tones) {
      if (tone.id == selectedToneId) {
        return tone;
      }
    }
    return null;
  }

  bool get _hasMissingSelectedTone =>
      selectedToneId != null && _selectedTone == null;

  @override
  Widget build(BuildContext context) {
    final selectedTone = _selectedTone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CUSTOM TONE', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        if (tonesLoading)
          const LinearProgressIndicator()
        else if (toneLibraryError != null)
          Text(
            toneLibraryError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: NeoColors.warningText),
          )
        else if (tones.isEmpty)
          Text(
            'No custom tones imported yet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NeoColors.subtext),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: selectedTone?.id,
            decoration: const InputDecoration(border: InputBorder.none),
            icon: const Icon(Icons.expand_more),
            isExpanded: true,
            items: tones
                .map(
                  (tone) => DropdownMenuItem<String>(
                    value: tone.id,
                    child: Text(
                      tone.displayName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            selectedItemBuilder: (context) => tones
                .map(
                  (tone) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tone.displayName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: onToneSelected,
          ),
        if (selectedTone != null) ...[
          const SizedBox(height: 8),
          Text(
            selectedTone.metadataSummary,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: NeoColors.subtext),
          ),
          if (!selectedTone.isHealthy || selectedTone.warning != null) ...[
            const SizedBox(height: 8),
            AlarmEditorWarning(
              title: 'Custom tone needs attention',
              detail:
                  selectedTone.warning ??
                  'This custom tone is unavailable. NeoAlarm will fall back to the bundled alarm tone until you repair it.',
            ),
          ],
        ],
        if (_hasMissingSelectedTone) ...[
          const SizedBox(height: 8),
          const AlarmEditorWarning(
            title: 'Missing custom tone',
            detail:
                'This alarm points at a custom tone that no longer exists. NeoAlarm will fall back to the bundled alarm tone until you choose another tone.',
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NeoActionButton(
                label: 'Import tone',
                backgroundColor: NeoColors.primary,
                onPressed: onImportTone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeoActionButton(
                label: 'Manage imports',
                backgroundColor: NeoColors.panel,
                onPressed: onManageTones,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AlarmToneManagementSheet extends StatelessWidget {
  const AlarmToneManagementSheet({
    required this.tones,
    required this.onDelete,
    super.key,
  });

  final List<AlarmTone> tones;
  final Future<void> Function(AlarmTone tone) onDelete;

  static Future<void> show(
    BuildContext context, {
    required List<AlarmTone> tones,
    required Future<void> Function(AlarmTone tone) onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AlarmToneManagementSheet(tones: tones, onDelete: onDelete),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: NeoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MANAGE TONES',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Imported tones can be reused across alarms. Removing one will make affected alarms fall back to the bundled alarm tone until repaired.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: NeoColors.subtext),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: tones.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tone = tones[index];
                    return NeoPanel(
                      color: NeoColors.panel,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tone.displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tone.metadataSummary,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: NeoColors.subtext),
                                ),
                                if (!tone.isHealthy ||
                                    tone.warning != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    tone.warning ??
                                        'This tone is currently unhealthy and may fall back at playback time.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: NeoColors.warningText,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          NeoSquareIconButton(
                            icon: Icons.delete,
                            backgroundColor: NeoColors.warm,
                            foregroundColor: Colors.red.shade700,
                            onPressed: () async {
                              await onDelete(tone);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ),
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
