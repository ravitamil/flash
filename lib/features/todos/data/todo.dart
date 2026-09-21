import 'package:flutter/material.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/todos/data/todo_recurrence.dart';

enum TodoPriority { none, low, medium, high }

class Todo {
  const Todo({
    required this.id,
    required this.text,
    required this.createdAt,
    this.done = false,
    this.date = '',
    this.minutes,
    this.durationMinutes,
    this.recurrence,
    this.completedDates = const [],
    this.priority = TodoPriority.none,
    this.photos = const [],
    this.tags = const [],
    this.project = '',
    this.steps = const [],
    this.doneAt,
  });

  final String id;
  final String text;
  final bool done;
  final String date;
  final int? minutes;
  final int? durationMinutes;
  final TodoRecurrence? recurrence;
  final List<String> completedDates;
  final TodoPriority priority;
  final List<String> photos;
  final List<String> tags;
  final String project;
  final List<TodoStep> steps;
  final DateTime createdAt;
  final DateTime? doneAt;

  bool get isRecurring => recurrence != null && !recurrence!.isNone;
  int get duration => durationMinutes ?? 0;
  bool get hasCompletions => done || (isRecurring && completedDates.isNotEmpty);

  DateTime? get lastCompletedAt {
    if (doneAt != null) return doneAt;
    if (completedDates.isNotEmpty) {
      return parseDayKey(completedDates.last);
    }
    return null;
  }

  bool isCompletedOn(DateTime day) {
    if (completedDates.contains(day.dayKey)) return true;
    if (done && due != null && due!.isSameDay(day)) return true;
    return false;
  }

  String get title => text.trim().split('\n').first;

  String get body {
    final lines = text.trim().split('\n');
    return lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';
  }

  DateTime? get due => date.isEmpty ? null : parseDayKey(date);

  TimeOfDay? get time => minutes == null
      ? null
      : TimeOfDay(hour: minutes! ~/ 60, minute: minutes! % 60);

  DateTime? get dueAt {
    final day = due;
    if (day == null || minutes == null) return day;
    return day.add(Duration(minutes: minutes!));
  }

  DateTime? get endAt {
    final start = dueAt;
    if (start == null) return null;
    if (durationMinutes != null && durationMinutes! > 0) {
      return start.add(Duration(minutes: durationMinutes!));
    }
    return start;
  }

  Todo copyWith({
    String? text,
    bool? done,
    String? date,
    int? minutes,
    int? durationMinutes,
    TodoRecurrence? recurrence,
    List<String>? completedDates,
    TodoPriority? priority,
    List<String>? photos,
    List<String>? tags,
    String? project,
    List<TodoStep>? steps,
    DateTime? doneAt,
    bool clearDoneAt = false,
    bool clearMinutes = false,
    bool clearDuration = false,
    bool clearRecurrence = false,
  }) =>
      Todo(
        id: id,
        text: text ?? this.text,
        done: done ?? this.done,
        date: date ?? this.date,
        minutes: clearMinutes ? null : (minutes ?? this.minutes),
        durationMinutes:
            clearDuration ? null : (durationMinutes ?? this.durationMinutes),
        recurrence:
            clearRecurrence ? null : (recurrence ?? this.recurrence),
        completedDates: completedDates ?? this.completedDates,
        priority: priority ?? this.priority,
        photos: photos ?? this.photos,
        tags: tags ?? this.tags,
        project: project ?? this.project,
        steps: steps ?? this.steps,
        createdAt: createdAt,
        doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'done': done,
        'date': date,
        if (minutes != null) 'minutes': minutes,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (recurrence != null) 'recurrence': recurrence!.toMap(),
        if (completedDates.isNotEmpty) 'completedDates': completedDates,
        'priority': priority.index,
        'photos': photos,
        'tags': tags,
        'project': project,
        'steps': [for (final step in steps) step.toMap()],
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
      };

  factory Todo.fromMap(Map<String, dynamic> map) => Todo(
        id: map['id'] as String,
        text: (map['text'] ?? '') as String,
        done: (map['done'] ?? false) as bool,
        date: (map['date'] ?? '') as String,
        minutes: (map['minutes'] as num?)?.toInt(),
        durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
        recurrence: map['recurrence'] != null
            ? TodoRecurrence.fromMap(
                Map<String, dynamic>.from(map['recurrence'] as Map))
            : null,
        completedDates: (map['completedDates'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        priority: TodoPriority.values[((map['priority'] ?? 0) as num)
            .toInt()
            .clamp(0, TodoPriority.values.length - 1)],
        photos:
            (map['photos'] as List?)?.map((p) => p as String).toList() ?? const [],
        tags:
            (map['tags'] as List?)?.map((t) => t as String).toList() ?? const [],
        project: (map['project'] ?? '') as String,
        steps: (map['steps'] as List?)
                ?.map((s) => TodoStep.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            const [],
        createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ??
            DateTime.now(),
        doneAt: DateTime.tryParse((map['doneAt'] ?? '') as String),
      );
}

class TodoStep {
  const TodoStep({required this.id, required this.text, this.done = false});

  final String id;
  final String text;
  final bool done;

  TodoStep copyWith({bool? done}) =>
      TodoStep(id: id, text: text, done: done ?? this.done);

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'done': done};

  factory TodoStep.fromMap(Map<String, dynamic> map) => TodoStep(
        id: map['id'] as String,
        text: (map['text'] ?? '') as String,
        done: (map['done'] ?? false) as bool,
      );
}

Color todoPriorityColor(BuildContext context, TodoPriority priority) =>
    switch (priority) {
      TodoPriority.none => context.tokens.muted,
      TodoPriority.low => context.tokens.info,
      TodoPriority.medium => context.tokens.warning,
      TodoPriority.high => context.tokens.danger,
    };
