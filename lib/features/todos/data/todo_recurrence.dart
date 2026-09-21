import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';

enum TodoRecurrenceKind {
  none,
  daily,
  weekdays,
  weekly,
  monthly,
  custom,
}

@immutable
class TodoRecurrence {
  const TodoRecurrence({
    required this.kind,
    this.weekdays = const [],
    this.interval = 1,
  });

  const TodoRecurrence.daily({this.interval = 1})
      : kind = TodoRecurrenceKind.daily,
        weekdays = const [];

  const TodoRecurrence.weekdays()
      : kind = TodoRecurrenceKind.weekdays,
        weekdays = const [1, 2, 3, 4, 5],
        interval = 1;

  const TodoRecurrence.weekly({this.weekdays = const [], this.interval = 1})
      : kind = TodoRecurrenceKind.weekly;

  const TodoRecurrence.monthly({this.interval = 1})
      : kind = TodoRecurrenceKind.monthly,
        weekdays = const [];

  final TodoRecurrenceKind kind;
  final List<int> weekdays; // 1 = Monday, 7 = Sunday
  final int interval;

  bool get isNone => kind == TodoRecurrenceKind.none;
  bool get isDaily => kind == TodoRecurrenceKind.daily;
  bool get isWeekdays => kind == TodoRecurrenceKind.weekdays;
  bool get isWeekly => kind == TodoRecurrenceKind.weekly;
  bool get isMonthly => kind == TodoRecurrenceKind.monthly;
  bool get isCustom => kind == TodoRecurrenceKind.custom;

  String get label => switch (kind) {
        TodoRecurrenceKind.none => 'Does not repeat',
        TodoRecurrenceKind.daily => interval > 1 ? 'Every $interval days' : 'Daily',
        TodoRecurrenceKind.weekdays => 'Every weekday (Mon–Fri)',
        TodoRecurrenceKind.weekly => interval > 1 ? 'Every $interval weeks' : 'Weekly',
        TodoRecurrenceKind.monthly => interval > 1 ? 'Every $interval months' : 'Monthly',
        TodoRecurrenceKind.custom => 'Every $interval days',
      };

  String get shortBadge => switch (kind) {
        TodoRecurrenceKind.none => '',
        TodoRecurrenceKind.daily => interval > 1 ? 'Every ${interval}d' : 'Daily',
        TodoRecurrenceKind.weekdays => 'Weekdays',
        TodoRecurrenceKind.weekly => interval > 1 ? 'Every ${interval}w' : 'Weekly',
        TodoRecurrenceKind.monthly => interval > 1 ? 'Every ${interval}m' : 'Monthly',
        TodoRecurrenceKind.custom => 'Every ${interval}d',
      };

  DateTime nextOccurrence(DateTime fromDate) {
    final start = fromDate.atMidnight;
    switch (kind) {
      case TodoRecurrenceKind.none:
        return start;

      case TodoRecurrenceKind.daily:
        return start.addDays(interval > 0 ? interval : 1);

      case TodoRecurrenceKind.weekdays:
        var next = start.addDays(1);
        while (next.weekday == DateTime.saturday || next.weekday == DateTime.sunday) {
          next = next.addDays(1);
        }
        return next;

      case TodoRecurrenceKind.weekly:
        final days = weekdays.isNotEmpty ? (List<int>.from(weekdays)..sort()) : [start.weekday];
        // Check if there is a later weekday in the same week
        for (final day in days) {
          if (day > start.weekday) {
            return start.addDays(day - start.weekday);
          }
        }
        // Jump to next week (or interval weeks) and pick first weekday
        final weeksToAdd = interval > 0 ? interval : 1;
        final daysToFirst = (7 * weeksToAdd) - (start.weekday - days.first);
        return start.addDays(daysToFirst);

      case TodoRecurrenceKind.monthly:
        final monthsToAdd = interval > 0 ? interval : 1;
        var nextYear = start.year;
        var nextMonth = start.month + monthsToAdd;
        while (nextMonth > 12) {
          nextYear++;
          nextMonth -= 12;
        }
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final nextDay = start.day.clamp(1, daysInNextMonth);
        return DateTime(nextYear, nextMonth, nextDay);

      case TodoRecurrenceKind.custom:
        return start.addDays(interval > 0 ? interval : 1);
    }
  }

  Map<String, dynamic> toMap() => {
        'kind': kind.index,
        if (weekdays.isNotEmpty) 'weekdays': weekdays,
        if (interval > 1) 'interval': interval,
      };

  factory TodoRecurrence.fromMap(Map<String, dynamic> map) {
    final kindIndex = (map['kind'] as num?)?.toInt() ?? 0;
    final kind = TodoRecurrenceKind.values[
        kindIndex.clamp(0, TodoRecurrenceKind.values.length - 1)];
    final weekdays = (map['weekdays'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [];
    final interval = (map['interval'] as num?)?.toInt() ?? 1;
    return TodoRecurrence(
      kind: kind,
      weekdays: weekdays,
      interval: interval,
    );
  }

  TodoRecurrence copyWith({
    TodoRecurrenceKind? kind,
    List<int>? weekdays,
    int? interval,
  }) =>
      TodoRecurrence(
        kind: kind ?? this.kind,
        weekdays: weekdays ?? this.weekdays,
        interval: interval ?? this.interval,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoRecurrence &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          listEquals(weekdays, other.weekdays) &&
          interval == other.interval;

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(weekdays), interval);
}
