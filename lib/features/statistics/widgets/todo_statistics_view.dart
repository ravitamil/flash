import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/widgets/app_empty_state.dart';
import 'package:streak/core/widgets/stat_columns.dart';
import 'package:streak/features/statistics/data/todo_stats.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';
import 'package:streak/features/statistics/widgets/stat_donut.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';
import 'package:streak/features/statistics/widgets/stat_line_charts.dart';
import 'package:streak/features/statistics/widgets/statistics_filters.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/state/todo_tags_controller.dart';

class TodoStatisticsView extends StatefulWidget {
  const TodoStatisticsView({
    super.key,
    required this.todos,
    required this.year,
    required this.onYearChanged,
  });

  final List<Todo> todos;
  final int year;
  final ValueChanged<int> onYearChanged;

  @override
  State<TodoStatisticsView> createState() => _TodoStatisticsViewState();
}

class _TodoStatisticsViewState extends State<TodoStatisticsView> {
  String? _projectId;

  @override
  Widget build(BuildContext context) {
    final todos = widget.todos;
    final year = widget.year;
    final accent = context.colors.primary;
    final currentYear = AppClock.now().year;

    final tagsController = context.watch<TodoTagsController>();
    final projects = tagsController.projects;

    final stats = TodoStats.compute(todos, year, projectId: _projectId);

    if (stats.allTimeCompleted == 0 && stats.pendingCount == 0) {
      return AppEmptyState(
        icon: LucideIcons.listTodo,
        title: 'No tasks yet',
        message: 'Create and complete tasks in To-Do to see productivity analytics here.',
      );
    }

    // Prepare priority breakdown entries
    final priorityEntries = <({String name, Color color, int count})>[
      if ((stats.byPriority[TodoPriority.high] ?? 0) > 0)
        (
          name: 'High Priority (P1)',
          color: todoPriorityColor(context, TodoPriority.high),
          count: stats.byPriority[TodoPriority.high]!,
        ),
      if ((stats.byPriority[TodoPriority.medium] ?? 0) > 0)
        (
          name: 'Medium Priority (P2)',
          color: todoPriorityColor(context, TodoPriority.medium),
          count: stats.byPriority[TodoPriority.medium]!,
        ),
      if ((stats.byPriority[TodoPriority.low] ?? 0) > 0)
        (
          name: 'Low Priority (P3)',
          color: todoPriorityColor(context, TodoPriority.low),
          count: stats.byPriority[TodoPriority.low]!,
        ),
      if ((stats.byPriority[TodoPriority.none] ?? 0) > 0)
        (
          name: 'Standard (P4)',
          color: context.tokens.muted,
          count: stats.byPriority[TodoPriority.none]!,
        ),
    ];

    // Prepare project breakdown entries
    final projectEntries = <({String name, Color color, int count})>[];
    for (final entry in stats.byProject.entries) {
      if (entry.value <= 0) continue;
      if (entry.key.isEmpty) {
        projectEntries.add((
          name: 'No Project',
          color: context.tokens.muted,
          count: entry.value,
        ));
      } else {
        final project = tagsController.byId(entry.key);
        if (project != null) {
          projectEntries.add((
            name: project.name,
            color: project.color,
            count: entry.value,
          ));
        }
      }
    }
    projectEntries.sort((a, b) => b.count.compareTo(a.count));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spanned(context, [
        if (projects.isNotEmpty) ...[
          _ProjectChipsBar(
            projects: projects,
            selected: _projectId,
            onSelected: (id) => setState(() => _projectId = id),
          ),
          const SizedBox(height: 12),
        ],
        YearNavigator(
          year: year,
          canGoForward: year < currentYear,
          onChanged: (delta) => widget.onYearChanged(year + delta),
        ),
        const SizedBox(height: 16),
        // MiniStats 2x2
        StatReveal(
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MiniStat(
                    icon: LucideIcons.checkCheck,
                    color: accent,
                    value: '${stats.totalCompleted}',
                    label: 'Completed ($year)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MiniStat(
                    icon: LucideIcons.calendarCheck,
                    color: context.tokens.info,
                    value: '${stats.completedThisWeek}',
                    label: 'This Week',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StatReveal(
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MiniStat(
                    icon: LucideIcons.target,
                    color: context.tokens.success,
                    value: '${stats.onTimeRate}%',
                    label: 'On-Time Rate',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MiniStat(
                    icon: LucideIcons.zap,
                    color: context.tokens.warning,
                    value: stats.completionVelocity > 0
                        ? stats.completionVelocity.toStringAsFixed(1)
                        : '0',
                    label: 'Avg / Active Day',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Weekday Bars
        StatReveal(
          child: StatCard(
            title: 'Completions by Weekday',
            icon: LucideIcons.calendarDays,
            color: accent,
            child: WeekdayBars(
              values: stats.weekdayCounts,
              color: accent,
              height: 150,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Monthly trend line
        StatReveal(
          child: StatCard(
            title: 'Completions per Month',
            icon: LucideIcons.chartSpline,
            color: accent,
            child: stats.totalCompleted > 0
                ? MonthlyLine(
                    key: ValueKey('todo-monthly-$year-$_projectId'),
                    values: stats.monthlyCounts,
                    color: accent,
                    year: year,
                  )
                : const _TodoChartPlaceholder(text: 'Not enough completion data'),
          ),
        ),
        if (priorityEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          StatReveal(
            child: StatCard(
              title: 'By Priority',
              icon: LucideIcons.flag,
              color: accent,
              child: HabitRanking(
                key: ValueKey('priority-${priorityEntries.length}'),
                entries: priorityEntries,
              ),
            ),
          ),
        ],
        if (_projectId == null && projectEntries.length > 1) ...[
          const SizedBox(height: 16),
          StatReveal(
            child: StatCard(
              title: 'By Project',
              icon: LucideIcons.folder,
              color: accent,
              child: HabitDonut(entries: projectEntries),
            ),
          ),
          const SizedBox(height: 16),
          StatReveal(
            child: StatCard(
              title: 'Project Breakdown',
              icon: LucideIcons.listOrdered,
              color: accent,
              child: HabitRanking(
                key: ValueKey('projects-${projectEntries.length}'),
                entries: projectEntries,
              ),
            ),
          ),
        ],
        if (stats.hourSamples >= 3) ...[
          const SizedBox(height: 16),
          StatReveal(
            child: StatCard(
              title: 'Completion Time',
              icon: LucideIcons.clock,
              color: accent,
              child: HourArea(values: stats.hourCounts, color: accent),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Secondary Overview
        StatReveal(
          child: _TodoSecondaryStats(stats: stats, accent: accent),
        ),
      ]),
    );
  }
}

class _ProjectChipsBar extends StatelessWidget {
  const _ProjectChipsBar({
    required this.projects,
    required this.selected,
    required this.onSelected,
  });

  final List<dynamic> projects;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Projects'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          for (final project in projects) ...[
            const SizedBox(width: 8),
            FilterChip(
              avatar: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: project.color as Color,
                ),
              ),
              label: Text(project.name as String),
              selected: selected == project.id,
              onSelected: (_) => onSelected(project.id as String),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodoSecondaryStats extends StatelessWidget {
  const _TodoSecondaryStats({required this.stats, required this.accent});

  final TodoStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OVERVIEW',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: context.tokens.muted,
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MiniStat(
                  value: '${stats.activeDays}',
                  label: 'Active Days',
                  icon: LucideIcons.calendarCheck,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MiniStat(
                  value: '${stats.allTimeCompleted}',
                  label: 'All-Time Completed',
                  icon: LucideIcons.trophy,
                  color: context.tokens.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MiniStat(
                  value: '${stats.completedThisMonth}',
                  label: 'This Month',
                  icon: LucideIcons.calendarRange,
                  color: context.tokens.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MiniStat(
                  value: '${stats.pendingCount}',
                  label: 'Pending Tasks',
                  icon: LucideIcons.clockAlert,
                  color: context.tokens.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodoChartPlaceholder extends StatelessWidget {
  const _TodoChartPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 120),
      child: AppEmptyState(
        icon: LucideIcons.sparkles,
        title: text,
        compact: true,
      ),
    );
  }
}
