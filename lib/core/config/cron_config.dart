import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/l10n.dart';

/// How sessions are managed for cron executions.
enum SessionStrategy { newEach, sameThread }

/// Schedule type: fixed interval or specific times of day.
enum ScheduleType { interval, timeOfDay }

/// Defines when a cron should run.
class CronSchedule {
  final ScheduleType type;

  /// For interval type: duration between runs (min 15 minutes).
  final Duration? interval;

  /// For timeOfDay type: list of times to run (e.g., 09:00, 18:00).
  final List<TimeOfDay>? times;

  /// Days of week to run (1=Mon..7=Sun). Null = every day.
  final List<int>? daysOfWeek;

  const CronSchedule({
    required this.type,
    this.interval,
    this.times,
    this.daysOfWeek,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'intervalMinutes': interval?.inMinutes,
        'times': times
            ?.map((t) => {'hour': t.hour, 'minute': t.minute})
            .toList(),
        'daysOfWeek': daysOfWeek,
      };

  factory CronSchedule.fromJson(Map<String, dynamic> json) => CronSchedule(
        type: ScheduleType.values.byName(json['type'] as String),
        interval: json['intervalMinutes'] != null
            ? Duration(minutes: json['intervalMinutes'] as int)
            : null,
        times: (json['times'] as List?)
            ?.map((t) => TimeOfDay(
                hour: t['hour'] as int, minute: t['minute'] as int))
            .toList(),
        daysOfWeek: (json['daysOfWeek'] as List?)?.cast<int>(),
      );

  String localizedDisplayText(AppLocalizations l) {
    switch (type) {
      case ScheduleType.interval:
        final minutes = interval!.inMinutes;
        if (minutes < 60) return l.cronDisplayEveryMinutes(minutes);
        final hours = minutes ~/ 60;
        return hours == 1 ? l.cronDisplayEveryHour : l.cronDisplayEveryHours(hours);
      case ScheduleType.timeOfDay:
        final timeStrs = times!
            .map((t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
            .join(', ');
        if (daysOfWeek == null) return l.cronDisplayDailyAt(timeStrs);
        return l.cronDisplayAt(timeStrs);
    }
  }
}

/// A scheduled prompt definition.
class CronDefinition {
  final String id;
  final String name;
  final String prompt;
  final CronSchedule schedule;
  final bool enabled;
  final SessionStrategy sessionStrategy;
  final DateTime? lastRun;
  final DateTime created;

  CronDefinition({
    String? id,
    required this.name,
    required this.prompt,
    required this.schedule,
    this.enabled = true,
    this.sessionStrategy = SessionStrategy.newEach,
    this.lastRun,
    DateTime? created,
  })  : id = id ?? const Uuid().v4(),
        created = created ?? DateTime.now();

  CronDefinition copyWith({
    String? name,
    String? prompt,
    CronSchedule? schedule,
    bool? enabled,
    SessionStrategy? sessionStrategy,
    DateTime? lastRun,
  }) =>
      CronDefinition(
        id: id,
        name: name ?? this.name,
        prompt: prompt ?? this.prompt,
        schedule: schedule ?? this.schedule,
        enabled: enabled ?? this.enabled,
        sessionStrategy: sessionStrategy ?? this.sessionStrategy,
        lastRun: lastRun ?? this.lastRun,
        created: created,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'prompt': prompt,
        'schedule': schedule.toJson(),
        'enabled': enabled,
        'sessionStrategy': sessionStrategy.name,
        'lastRun': lastRun?.toIso8601String(),
        'created': created.toIso8601String(),
      };

  factory CronDefinition.fromJson(Map<String, dynamic> json) =>
      CronDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        prompt: json['prompt'] as String,
        schedule:
            CronSchedule.fromJson(json['schedule'] as Map<String, dynamic>),
        enabled: json['enabled'] as bool? ?? true,
        sessionStrategy: SessionStrategy.values
            .byName(json['sessionStrategy'] as String? ?? 'newEach'),
        lastRun: json['lastRun'] != null
            ? DateTime.parse(json['lastRun'] as String)
            : null,
        created: json['created'] != null
            ? DateTime.parse(json['created'] as String)
            : DateTime.now(),
      );
}
