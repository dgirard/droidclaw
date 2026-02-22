import 'package:flutter/material.dart';

import '../../core/config/cron_config.dart';
import '../../l10n/l10n.dart';

/// Create/edit a scheduled prompt.
class CronEditScreen extends StatefulWidget {
  const CronEditScreen({super.key});

  @override
  State<CronEditScreen> createState() => _CronEditScreenState();
}

class _CronEditScreenState extends State<CronEditScreen> {
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();
  ScheduleType _scheduleType = ScheduleType.interval;
  Duration _interval = const Duration(hours: 1);
  List<TimeOfDay> _times = [];
  List<int>? _daysOfWeek;
  SessionStrategy _sessionStrategy = SessionStrategy.newEach;
  bool _isEditing = false;
  String? _editingId;

  static List<(String, Duration)> _intervalPresets(AppLocalizations l) => [
    (l.cronEditInterval15, const Duration(minutes: 15)),
    (l.cronEditInterval30, const Duration(minutes: 30)),
    (l.cronEditInterval1h, const Duration(hours: 1)),
    (l.cronEditInterval2h, const Duration(hours: 2)),
    (l.cronEditInterval6h, const Duration(hours: 6)),
    (l.cronEditInterval12h, const Duration(hours: 12)),
    (l.cronEditInterval24h, const Duration(hours: 24)),
  ];

  static List<String> _dayNames(AppLocalizations l) => [
    l.cronEditMon, l.cronEditTue, l.cronEditWed, l.cronEditThu,
    l.cronEditFri, l.cronEditSat, l.cronEditSun,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEditing) {
      final cron =
          ModalRoute.of(context)?.settings.arguments as CronDefinition?;
      if (cron != null) {
        _isEditing = true;
        _editingId = cron.id;
        _nameController.text = cron.name;
        _promptController.text = cron.prompt;
        _scheduleType = cron.schedule.type;
        _interval = cron.schedule.interval ?? const Duration(hours: 1);
        _times = cron.schedule.times ?? [];
        _daysOfWeek = cron.schedule.daysOfWeek;
        _sessionStrategy = cron.sessionStrategy;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _save() {
    final l = AppLocalizations.of(context);
    if (_nameController.text.trim().isEmpty ||
        _promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.cronEditNameRequired)),
      );
      return;
    }
    if (_scheduleType == ScheduleType.timeOfDay && _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.cronEditTimeRequired)),
      );
      return;
    }

    final cron = CronDefinition(
      id: _editingId,
      name: _nameController.text.trim(),
      prompt: _promptController.text.trim(),
      schedule: CronSchedule(
        type: _scheduleType,
        interval: _scheduleType == ScheduleType.interval ? _interval : null,
        times: _scheduleType == ScheduleType.timeOfDay ? _times : null,
        daysOfWeek: _daysOfWeek,
      ),
      sessionStrategy: _sessionStrategy,
    );

    Navigator.pop(context, cron);
  }

  Future<void> _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _times.add(time));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final presets = _intervalPresets(l);
    final dayNamesList = _dayNames(l);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId != null ? l.cronEditTitleEdit : l.cronEditTitle),
        actions: [
          TextButton(onPressed: _save, child: Text(l.cronEditSave)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l.cronEditName,
              hintText: l.cronEditNameHint,
            ),
          ),
          const SizedBox(height: 16),

          // Prompt
          TextField(
            controller: _promptController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l.cronEditPrompt,
              hintText: l.cronEditPromptHint,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // Schedule type
          Text(l.cronEditSchedule, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ScheduleType>(
            segments: [
              ButtonSegment(
                value: ScheduleType.interval,
                label: Text(l.cronEditInterval),
                icon: const Icon(Icons.timer_outlined),
              ),
              ButtonSegment(
                value: ScheduleType.timeOfDay,
                label: Text(l.cronEditSpecificTimes),
                icon: const Icon(Icons.access_time),
              ),
            ],
            selected: {_scheduleType},
            onSelectionChanged: (s) =>
                setState(() => _scheduleType = s.first),
          ),
          const SizedBox(height: 16),

          // Interval presets
          if (_scheduleType == ScheduleType.interval) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((preset) {
                final isSelected = _interval == preset.$2;
                return ChoiceChip(
                  label: Text(preset.$1),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _interval = preset.$2),
                );
              }).toList(),
            ),
          ],

          // Time picker
          if (_scheduleType == ScheduleType.timeOfDay) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._times.asMap().entries.map((entry) {
                  final time = entry.value;
                  final label =
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  return InputChip(
                    label: Text(label),
                    onDeleted: () =>
                        setState(() => _times.removeAt(entry.key)),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l.cronEditAddTime),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Days of week
            Text(l.cronEditDays, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final day = index + 1; // 1=Mon..7=Sun
                final isSelected =
                    _daysOfWeek == null || _daysOfWeek!.contains(day);
                return FilterChip(
                  label: Text(dayNamesList[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (_daysOfWeek == null) {
                        // All selected → deselect one
                        _daysOfWeek =
                            List.generate(7, (i) => i + 1)
                              ..remove(day);
                      } else if (selected) {
                        _daysOfWeek!.add(day);
                        if (_daysOfWeek!.length == 7) {
                          _daysOfWeek = null; // All = every day
                        }
                      } else {
                        _daysOfWeek!.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
          ],

          const SizedBox(height: 24),

          // Session strategy
          Text(l.cronEditConversation, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          RadioGroup<SessionStrategy>(
            groupValue: _sessionStrategy,
            onChanged: (v) {
              if (v != null) setState(() => _sessionStrategy = v);
            },
            child: Column(
              children: [
                RadioListTile<SessionStrategy>(
                  title: Text(l.cronEditNewEach),
                  subtitle: Text(l.cronEditNewEachSubtitle),
                  value: SessionStrategy.newEach,
                ),
                RadioListTile<SessionStrategy>(
                  title: Text(l.cronEditSameThread),
                  subtitle: Text(l.cronEditSameThreadSubtitle),
                  value: SessionStrategy.sameThread,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
