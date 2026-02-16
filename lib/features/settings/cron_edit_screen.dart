import 'package:flutter/material.dart';

import '../../core/config/cron_config.dart';

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

  static const _intervalPresets = [
    ('15 min', Duration(minutes: 15)),
    ('30 min', Duration(minutes: 30)),
    ('1 hour', Duration(hours: 1)),
    ('2 hours', Duration(hours: 2)),
    ('6 hours', Duration(hours: 6)),
    ('12 hours', Duration(hours: 12)),
    ('24 hours', Duration(hours: 24)),
  ];

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
    if (_nameController.text.trim().isEmpty ||
        _promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and prompt are required')),
      );
      return;
    }
    if (_scheduleType == ScheduleType.timeOfDay && _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one time')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId != null ? 'Edit Prompt' : 'New Prompt'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g., Daily news brief',
            ),
          ),
          const SizedBox(height: 16),

          // Prompt
          TextField(
            controller: _promptController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Prompt',
              hintText: 'What should the AI do?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // Schedule type
          Text('Schedule', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ScheduleType>(
            segments: const [
              ButtonSegment(
                value: ScheduleType.interval,
                label: Text('Interval'),
                icon: Icon(Icons.timer_outlined),
              ),
              ButtonSegment(
                value: ScheduleType.timeOfDay,
                label: Text('Specific times'),
                icon: Icon(Icons.access_time),
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
              children: _intervalPresets.map((preset) {
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
                  label: const Text('Add time'),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Days of week
            Text('Days', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final day = index + 1; // 1=Mon..7=Sun
                final isSelected =
                    _daysOfWeek == null || _daysOfWeek!.contains(day);
                return FilterChip(
                  label: Text(_dayNames[index]),
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
          Text('Conversation', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          RadioGroup<SessionStrategy>(
            groupValue: _sessionStrategy,
            onChanged: (v) {
              if (v != null) setState(() => _sessionStrategy = v);
            },
            child: Column(
              children: [
                RadioListTile<SessionStrategy>(
                  title: const Text('New conversation each time'),
                  subtitle: const Text('Each execution is independent'),
                  value: SessionStrategy.newEach,
                ),
                RadioListTile<SessionStrategy>(
                  title: const Text('Continue in same thread'),
                  subtitle:
                      const Text('The AI remembers previous executions'),
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
