import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/habits/data/day_plan.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/todos/data/todo.dart';

final _day = DateTime(2026, 8, 12);

Habit _habit({
  required String id,
  int start = -1,
  int duration = 0,
  int order = 0,
  HabitKind kind = HabitKind.positive,
  HabitInterval interval = HabitInterval.daily,
  List<int> scheduleWeekdays = const [],
  List<int> restDays = const [],
  DateTime? createdAt,
}) =>
    Habit(
      id: id,
      name: id,
      color: const Color(0xFF00FF00),
      order: order,
      kind: kind,
      interval: interval,
      scheduleWeekdays: scheduleWeekdays,
      restDays: restDays,
      startMinute: start,
      durationMinutes: duration,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );

Todo _todo({
  required String id,
  required String text,
  DateTime? due,
  int? minutes,
  int? durationMinutes,
  bool done = false,
  TodoPriority priority = TodoPriority.none,
}) =>
    Todo(
      id: id,
      text: text,
      date: due?.dayKey ?? '',
      minutes: minutes,
      durationMinutes: durationMinutes,
      done: done,
      priority: priority,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('planned habits come out sorted with the gaps between them', () {
    final plan = DayPlan.of([
      _habit(id: 'late', start: 13 * 60, duration: 30),
      _habit(id: 'early', start: 9 * 60, duration: 60),
    ], _day);

    expect(plan.slots.length, 3);
    expect(plan.slots[0].habit?.id, 'early');
    expect(plan.slots[1].isGap, isTrue);
    expect(plan.slots[1].minutes, 3 * 60);
    expect(plan.slots[2].habit?.id, 'late');
  });

  test('back to back habits leave no gap', () {
    final plan = DayPlan.of([
      _habit(id: 'a', start: 9 * 60, duration: 30),
      _habit(id: 'b', start: 9 * 60 + 30, duration: 30),
    ], _day);

    expect(plan.slots.length, 2);
    expect(plan.slots.every((s) => !s.isGap), isTrue);
  });

  test('overlapping habits never make a negative gap', () {
    final plan = DayPlan.of([
      _habit(id: 'long', start: 9 * 60, duration: 120),
      _habit(id: 'inside', start: 9 * 60 + 30, duration: 15),
      _habit(id: 'after', start: 12 * 60, duration: 30),
    ], _day);

    expect(plan.slots.where((s) => s.isGap).length, 1);
    expect(plan.slots.where((s) => s.isGap).single.minutes, 60);
    expect(plan.slots.every((s) => s.minutes >= 0), isTrue);
  });

  test('habits with no time land in the anytime list', () {
    final plan = DayPlan.of([
      _habit(id: 'planned', start: 8 * 60),
      _habit(id: 'loose'),
    ], _day);

    expect(plan.planned.map((h) => h.id), ['planned']);
    expect(plan.anytime.map((h) => h.id), ['loose']);
  });

  test('a habit that is not due that day is left out', () {
    final plan = DayPlan.of([
      _habit(
        id: 'monday',
        start: 8 * 60,
        interval: HabitInterval.weekdays,
        scheduleWeekdays: const [DateTime.monday],
      ),
      _habit(
        id: 'resting',
        start: 9 * 60,
        restDays: [_day.weekday],
      ),
      _habit(
        id: 'future',
        start: 10 * 60,
        createdAt: DateTime(2026, 9, 1),
      ),
      _habit(id: 'negative', kind: HabitKind.negative),
    ], _day);

    expect(plan.isEmpty, isTrue);
  });

  test('a duration that runs past midnight stops at the end of the day', () {
    final habit = _habit(id: 'late', start: 23 * 60 + 30, duration: 120);

    expect(habit.endMinute, Habit.dayMinutes);
    expect(minuteLabel(habit.endMinute), '00:00');
  });

  test('labels read the way a clock does', () {
    expect(minuteLabel(0), '00:00');
    expect(minuteLabel(9 * 60 + 5), '09:05');
    expect(spanLabel(45), '45m');
    expect(spanLabel(60), '1h');
    expect(spanLabel(95), '1h 35m');
  });

  test('timed habits and timed todos are sorted together with gaps', () {
    final habits = [
      _habit(id: 'habit1', start: 8 * 60, duration: 30),
      _habit(id: 'habit2', start: 11 * 60, duration: 60),
    ];
    final todos = [
      _todo(
        id: 'todo1',
        text: 'Morning Standup',
        due: _day,
        minutes: 9 * 60,
        durationMinutes: 45,
      ),
      _todo(
        id: 'todo2',
        text: 'Review PR',
        due: _day,
        minutes: 10 * 60,
        durationMinutes: 30,
      ),
    ];

    final plan = DayPlan.of(habits, _day, todos: todos);

    expect(plan.slots.length, 7);
    expect(plan.slots[0].isHabit, isTrue);
    expect(plan.slots[0].habit?.id, 'habit1'); // 08:00 - 08:30

    expect(plan.slots[1].isGap, isTrue); // 08:30 - 09:00 (30m gap)
    expect(plan.slots[1].minutes, 30);

    expect(plan.slots[2].isTodo, isTrue);
    expect(plan.slots[2].todo?.id, 'todo1'); // 09:00 - 09:45

    expect(plan.slots[3].isGap, isTrue); // 09:45 - 10:00 (15m gap)
    expect(plan.slots[3].minutes, 15);

    expect(plan.slots[4].isTodo, isTrue);
    expect(plan.slots[4].todo?.id, 'todo2'); // 10:00 - 10:30

    expect(plan.slots[5].isGap, isTrue); // 10:30 - 11:00 (30m gap)
    expect(plan.slots[5].minutes, 30);

    expect(plan.slots[6].isHabit, isTrue);
    expect(plan.slots[6].habit?.id, 'habit2'); // 11:00 - 12:00
  });

  test('untimed todos land in anytimeTodos', () {
    final habits = [_habit(id: 'h1', start: 8 * 60)];
    final todos = [
      _todo(id: 'timed', text: 'Call Mom', due: _day, minutes: 14 * 60),
      _todo(id: 'untimed1', text: 'Groceries', due: _day),
      _todo(id: 'untimed2', text: 'Laundry', due: _day),
    ];

    final plan = DayPlan.of(habits, _day, todos: todos);

    expect(plan.plannedHabits.map((h) => h.id), ['h1']);
    expect(plan.plannedTodos.map((t) => t.id), ['timed']);
    expect(plan.anytimeTodos.map((t) => t.id), ['untimed1', 'untimed2']);
  });

  test('filtering isolates habits or todos and recalculates gaps', () {
    final habits = [
      _habit(id: 'h1', start: 8 * 60, duration: 30),
      _habit(id: 'h2', start: 12 * 60, duration: 30),
    ];
    final todos = [
      _todo(id: 't1', text: 'Sync', due: _day, minutes: 9 * 60, durationMinutes: 60),
    ];

    final habitsOnly = DayPlan.of(habits, _day, todos: todos, filter: PlanFilter.habits);
    expect(habitsOnly.slots.where((s) => s.isTodo), isEmpty);
    expect(habitsOnly.slots.where((s) => s.isHabit).length, 2);
    // Gap between 08:30 and 12:00 is 3h 30m (210m)
    expect(habitsOnly.slots.where((s) => s.isGap).single.minutes, 210);

    final todosOnly = DayPlan.of(habits, _day, todos: todos, filter: PlanFilter.todos);
    expect(todosOnly.slots.where((s) => s.isHabit), isEmpty);
    expect(todosOnly.slots.where((s) => s.isTodo).length, 1);
  });

  test('plan calculates metrics correctly', () {
    final habits = [
      _habit(id: 'h1', start: 8 * 60, duration: 30),
    ];
    final todos = [
      _todo(id: 't1', text: 'Sync', due: _day, minutes: 9 * 60, durationMinutes: 60, done: true),
      _todo(id: 't2', text: 'Groceries', due: _day),
    ];

    final plan = DayPlan.of(habits, _day, todos: todos);
    expect(plan.totalHabits, 1);
    expect(plan.totalTodos, 2);
    expect(plan.completedTodos, 1);
    expect(plan.totalScheduledMinutes, 90); // 30m habit + 60m todo
  });
}
