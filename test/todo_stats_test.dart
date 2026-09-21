import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_recurrence.dart';
import 'package:streak/features/statistics/data/todo_stats.dart';

void main() {
  group('TodoStats', () {
    test('compute on empty list returns empty-like stats', () {
      final stats = TodoStats.compute([], 2026);
      expect(stats.totalCompleted, 0);
      expect(stats.allTimeCompleted, 0);
      expect(stats.pendingCount, 0);
      expect(stats.onTimeRate, 100);
      expect(stats.completionVelocity, 0.0);
      expect(stats.dailyCounts, isEmpty);
    });

    test('computes completed single todo with on-time performance', () {
      final today = AppClock.today();
      final now = DateTime(today.year, today.month, today.day, 14, 30);
      final todo = Todo(
        id: '1',
        text: 'Finish presentation',
        createdAt: today.subtract(const Duration(days: 1)),
        done: true,
        doneAt: now,
        date: today.dayKey,
        priority: TodoPriority.high,
        project: 'work',
      );

      final stats = TodoStats.compute([todo], today.year);
      expect(stats.totalCompleted, 1);
      expect(stats.allTimeCompleted, 1);
      expect(stats.completedToday, 1);
      expect(stats.onTimeRate, 100);
      expect(stats.byPriority[TodoPriority.high], 1);
      expect(stats.byProject['work'], 1);
      expect(stats.hourSamples, 1);
      expect(stats.hourCounts[14], 1);
      expect(stats.monthlyCounts[today.month - 1], 1);
    });

    test('computes recurring todo with multiple completion dates', () {
      final todo = Todo(
        id: '2',
        text: 'Drink water',
        createdAt: DateTime(2026, 9, 1),
        done: false,
        recurrence: const TodoRecurrence.daily(),
        completedDates: const ['2026-09-18', '2026-09-19', '2026-09-20'],
        priority: TodoPriority.medium,
      );

      final stats = TodoStats.compute([todo], 2026);
      expect(stats.totalCompleted, 3);
      expect(stats.allTimeCompleted, 3);
      expect(stats.byPriority[TodoPriority.medium], 3);
      expect(stats.activeDays, 3);
      expect(stats.completionVelocity, 1.0);
    });

    test('computes overdue completed task correctly', () {
      final doneDate = DateTime(2026, 9, 21);
      final dueDate = DateTime(2026, 9, 15); // due 6 days before
      final todo = Todo(
        id: '3',
        text: 'Late task',
        createdAt: DateTime(2026, 9, 10),
        done: true,
        doneAt: doneDate,
        date: dueDate.dayKey,
      );

      final stats = TodoStats.compute([todo], 2026);
      expect(stats.totalCompleted, 1);
      expect(stats.onTimeCount, 0);
      expect(stats.dueCompletedCount, 1);
      expect(stats.onTimeRate, 0);
    });

    test('filters by projectId', () {
      final t1 = Todo(
        id: '1',
        text: 'Work task',
        createdAt: DateTime(2026, 9, 21),
        done: true,
        doneAt: DateTime(2026, 9, 21),
        project: 'work',
      );
      final t2 = Todo(
        id: '2',
        text: 'Personal task',
        createdAt: DateTime(2026, 9, 21),
        done: true,
        doneAt: DateTime(2026, 9, 21),
        project: 'personal',
      );

      final workStats = TodoStats.compute([t1, t2], 2026, projectId: 'work');
      expect(workStats.totalCompleted, 1);
      expect(workStats.byProject['work'], 1);
      expect(workStats.byProject.containsKey('personal'), isFalse);
    });
  });
}
