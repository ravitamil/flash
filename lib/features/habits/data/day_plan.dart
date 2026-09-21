import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/todos/data/todo.dart';

enum PlanFilter { all, habits, todos }

@immutable
class DaySlot {
  const DaySlot({
    required this.start,
    required this.end,
    this.habit,
    this.todo,
  });

  final int start;
  final int end;
  final Habit? habit;
  final Todo? todo;

  bool get isGap => habit == null && todo == null;
  bool get isHabit => habit != null;
  bool get isTodo => todo != null;

  int get minutes => end - start;
}

class _TimedPlanItem {
  const _TimedPlanItem({
    required this.start,
    required this.end,
    this.habit,
    this.todo,
    required this.order,
  });

  final int start;
  final int end;
  final Habit? habit;
  final Todo? todo;
  final int order;
}

@immutable
class DayPlan {
  const DayPlan({
    required this.slots,
    required this.anytimeHabits,
    this.anytimeTodos = const [],
    this.totalHabits = 0,
    this.completedHabits = 0,
    this.totalTodos = 0,
    this.completedTodos = 0,
  });

  final List<DaySlot> slots;
  final List<Habit> anytimeHabits;
  final List<Todo> anytimeTodos;
  final int totalHabits;
  final int completedHabits;
  final int totalTodos;
  final int completedTodos;

  List<Habit> get anytime => anytimeHabits;

  bool get isEmpty =>
      slots.isEmpty && anytimeHabits.isEmpty && anytimeTodos.isEmpty;

  Iterable<Habit> get plannedHabits =>
      slots.where((s) => s.isHabit).map((s) => s.habit!);

  Iterable<Todo> get plannedTodos =>
      slots.where((s) => s.isTodo).map((s) => s.todo!);

  Iterable<Habit> get planned => plannedHabits;

  int get totalScheduledMinutes =>
      slots.where((s) => !s.isGap).fold(0, (sum, s) => sum + s.minutes);

  static bool isDueOn(Habit habit, DateTime day) =>
      !habit.isArchived &&
      habit.kind != HabitKind.negative &&
      !day.atMidnight.isBefore(habit.startedAt) &&
      habit.isScheduledOn(day) &&
      !habit.isPausedOn(day);

  static bool isTodoDueOn(Todo todo, DateTime day) {
    if (todo.isCompletedOn(day)) return true;
    final due = todo.due;
    if (due != null && due.isSameDay(day)) return true;
    if (day.isSameDay(AppClock.today()) &&
        !todo.done &&
        due != null &&
        due.isBefore(day.atMidnight)) {
      return true;
    }
    return false;
  }

  static DayPlan of(
    List<Habit> habits,
    DateTime day, {
    List<Todo> todos = const [],
    PlanFilter filter = PlanFilter.all,
  }) {
    final includeHabits =
        filter == PlanFilter.all || filter == PlanFilter.habits;
    final includeTodos =
        filter == PlanFilter.all || filter == PlanFilter.todos;

    final dueHabits = habits.where((h) => isDueOn(h, day)).toList();
    final dueTodos = todos.where((t) => isTodoDueOn(t, day)).toList();

    final completedHabits =
        dueHabits.where((h) => h.isCompletedOn(day)).length;
    final completedTodos =
        dueTodos.where((t) => t.isCompletedOn(day)).length;

    final plannedHabits =
        includeHabits ? dueHabits.where((h) => h.isPlanned).toList() : <Habit>[];
    final anytimeHabits =
        includeHabits ? dueHabits.where((h) => !h.isPlanned).toList() : <Habit>[];

    final plannedTodos =
        includeTodos ? dueTodos.where((t) => t.minutes != null).toList() : <Todo>[];
    final anytimeTodos =
        includeTodos ? dueTodos.where((t) => t.minutes == null).toList() : <Todo>[];

    final items = <_TimedPlanItem>[
      for (final habit in plannedHabits)
        _TimedPlanItem(
          start: habit.startMinute,
          end: habit.endMinute,
          habit: habit,
          order: habit.order,
        ),
      for (final todo in plannedTodos)
        _TimedPlanItem(
          start: todo.minutes!,
          end: (todo.minutes! +
                  ((todo.durationMinutes != null && todo.durationMinutes! > 0)
                      ? todo.durationMinutes!
                      : 30))
              .clamp(0, Habit.dayMinutes),
          todo: todo,
          order: todo.priority.index,
        ),
    ]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        final byEnd = a.end.compareTo(b.end);
        if (byEnd != 0) return byEnd;
        return a.order.compareTo(b.order);
      });

    final slots = <DaySlot>[];
    var reached = -1;
    for (final item in items) {
      if (reached >= 0 && item.start > reached) {
        slots.add(DaySlot(start: reached, end: item.start));
      }
      slots.add(
        DaySlot(
          start: item.start,
          end: item.end,
          habit: item.habit,
          todo: item.todo,
        ),
      );
      if (item.end > reached) reached = item.end;
    }

    return DayPlan(
      slots: slots,
      anytimeHabits: anytimeHabits,
      anytimeTodos: anytimeTodos,
      totalHabits: dueHabits.length,
      completedHabits: completedHabits,
      totalTodos: dueTodos.length,
      completedTodos: completedTodos,
    );
  }
}

String minuteLabel(int minute, {bool hour24 = true}) {
  final total = minute.clamp(0, Habit.dayMinutes);
  final h = (total ~/ 60) % 24;
  final m = total % 60;
  if (hour24) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  final suffix = h < 12 ? 'AM' : 'PM';
  final display = h % 12 == 0 ? 12 : h % 12;
  return '$display:${m.toString().padLeft(2, '0')} $suffix';
}

String spanLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
