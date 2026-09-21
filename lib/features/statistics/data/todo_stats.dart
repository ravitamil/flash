import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/todos/data/todo.dart';

@immutable
class TodoStats {
  const TodoStats({
    required this.year,
    required this.totalCompleted,
    required this.allTimeCompleted,
    required this.completedToday,
    required this.completedThisWeek,
    required this.completedThisMonth,
    required this.pendingCount,
    required this.onTimeCount,
    required this.dueCompletedCount,
    required this.onTimeRate,
    required this.completionVelocity,
    required this.dailyCounts,
    required this.weekdayCounts,
    required this.monthlyCounts,
    required this.byPriority,
    required this.byProject,
    required this.hourCounts,
    required this.hourSamples,
    required this.activeDays,
  });

  final int year;
  final int totalCompleted;
  final int allTimeCompleted;
  final int completedToday;
  final int completedThisWeek;
  final int completedThisMonth;
  final int pendingCount;
  final int onTimeCount;
  final int dueCompletedCount;
  final int onTimeRate; // 0 to 100
  final double completionVelocity; // average per active day
  final Map<String, int> dailyCounts;
  final List<int> weekdayCounts; // 0 = Mon, 6 = Sun
  final List<int> monthlyCounts; // 0 = Jan, 11 = Dec
  final Map<TodoPriority, int> byPriority;
  final Map<String, int> byProject;
  final List<int> hourCounts; // 24 hours
  final int hourSamples;
  final int activeDays;

  static const empty = TodoStats(
    year: 0,
    totalCompleted: 0,
    allTimeCompleted: 0,
    completedToday: 0,
    completedThisWeek: 0,
    completedThisMonth: 0,
    pendingCount: 0,
    onTimeCount: 0,
    dueCompletedCount: 0,
    onTimeRate: 100,
    completionVelocity: 0,
    dailyCounts: {},
    weekdayCounts: [0, 0, 0, 0, 0, 0, 0],
    monthlyCounts: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    byPriority: {},
    byProject: {},
    hourCounts: [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ],
    hourSamples: 0,
    activeDays: 0,
  );

  int get bestWeekday => _argMax(weekdayCounts);
  int get peakHour => _argMax(hourCounts);

  static int _argMax(List<int> list) {
    var maxIndex = 0;
    var maxValue = -1;
    for (var i = 0; i < list.length; i++) {
      if (list[i] > maxValue) {
        maxValue = list[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  static TodoStats compute(
    List<Todo> todos,
    int year, {
    String? projectId,
  }) {
    final scoped = projectId == null || projectId.isEmpty
        ? todos
        : todos.where((t) => t.project == projectId).toList();

    final now = AppClock.now();
    final today = AppClock.today();
    final todayKey = today.dayKey;

    final weekStart = today.subtract(Duration(days: (today.weekday - 1) % 7));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final dailyCounts = <String, int>{};
    final weekdayCounts = List<int>.filled(7, 0);
    final monthlyCounts = List<int>.filled(12, 0);
    final hourCounts = List<int>.filled(24, 0);
    final byPriority = <TodoPriority, int>{
      TodoPriority.high: 0,
      TodoPriority.medium: 0,
      TodoPriority.low: 0,
      TodoPriority.none: 0,
    };
    final byProject = <String, int>{};

    var allTimeCompleted = 0;
    var yearCompleted = 0;
    var completedToday = 0;
    var completedThisWeek = 0;
    var completedThisMonth = 0;
    var onTimeCount = 0;
    var dueCompletedCount = 0;
    var hourSamples = 0;
    var pendingCount = 0;

    for (final todo in scoped) {
      if (!todo.done && (!todo.isRecurring || todo.completedDates.isEmpty)) {
        pendingCount++;
      }

      // Collect all completion dates for this todo
      final completionDates = <DateTime>[];
      if (todo.isRecurring) {
        for (final key in todo.completedDates) {
          final d = parseDayKey(key);
          completionDates.add(d);
        }
      } else if (todo.done) {
        final d = todo.doneAt ?? todo.lastCompletedAt ?? todo.createdAt;
        completionDates.add(d);
      }

      if (completionDates.isEmpty) continue;

      allTimeCompleted += completionDates.length;

      // Check on-time performance
      if (todo.due != null) {
        dueCompletedCount += completionDates.length;
        for (final comp in completionDates) {
          final compMid = comp.atMidnight;
          final dueMid = todo.due!.atMidnight;
          if (compMid.isBefore(dueMid) || compMid.isSameDay(dueMid)) {
            onTimeCount++;
          }
        }
      }

      // Group by priority and project
      byPriority[todo.priority] =
          (byPriority[todo.priority] ?? 0) + completionDates.length;
      byProject[todo.project] =
          (byProject[todo.project] ?? 0) + completionDates.length;

      // Hourly distribution
      if (todo.doneAt != null) {
        hourCounts[todo.doneAt!.hour]++;
        hourSamples++;
      }

      for (final date in completionDates) {
        final dayKey = date.dayKey;

        if (dayKey == todayKey) {
          completedToday++;
        }

        final dateMid = date.atMidnight;
        if (!dateMid.isBefore(weekStart.atMidnight) &&
            !dateMid.isAfter(weekEnd.atMidnight)) {
          completedThisWeek++;
        }

        if (date.year == now.year && date.month == now.month) {
          completedThisMonth++;
        }

        // Year-scoped metrics
        if (date.year == year) {
          yearCompleted++;
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
          weekdayCounts[(date.weekday - 1) % 7]++;
          if (date.month >= 1 && date.month <= 12) {
            monthlyCounts[date.month - 1]++;
          }
        }
      }
    }

    final activeDays = dailyCounts.length;
    final velocity = activeDays == 0 ? 0.0 : yearCompleted / activeDays;
    final onTimeRate = dueCompletedCount == 0
        ? 100
        : ((onTimeCount / dueCompletedCount) * 100).round().clamp(0, 100);

    return TodoStats(
      year: year,
      totalCompleted: yearCompleted,
      allTimeCompleted: allTimeCompleted,
      completedToday: completedToday,
      completedThisWeek: completedThisWeek,
      completedThisMonth: completedThisMonth,
      pendingCount: pendingCount,
      onTimeCount: onTimeCount,
      dueCompletedCount: dueCompletedCount,
      onTimeRate: onTimeRate,
      completionVelocity: velocity,
      dailyCounts: dailyCounts,
      weekdayCounts: List.unmodifiable(weekdayCounts),
      monthlyCounts: List.unmodifiable(monthlyCounts),
      byPriority: Map.unmodifiable(byPriority),
      byProject: Map.unmodifiable(byProject),
      hourCounts: List.unmodifiable(hourCounts),
      hourSamples: hourSamples,
      activeDays: activeDays,
    );
  }
}
