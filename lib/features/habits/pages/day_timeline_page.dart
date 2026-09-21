import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/express/express_button.dart';
import 'package:streak/core/express/express_motion.dart';
import 'package:streak/core/express/express_surface.dart';
import 'package:streak/core/express/express_type.dart';
import 'package:streak/features/settings/widgets/minimal_settings_widgets.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/extensions/inset_extensions.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/core/minimal/minimal_type.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/icons/habit_glyph.dart';
import 'package:streak/core/routing/app_navigator.dart';
import 'package:streak/core/widgets/app_empty_state.dart';
import 'package:streak/core/widgets/celebration_overlay.dart';
import 'package:streak/core/widgets/entrance.dart';
import 'package:streak/core/widgets/section_label.dart';
import 'package:streak/features/habits/data/day_plan.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/pages/habit_details_page.dart';
import 'package:streak/features/habits/pages/habit_form_page.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/habits/widgets/day_timeline_parts.dart';
import 'package:streak/features/habits/widgets/focus_only_dialog.dart';
import 'package:streak/features/habits/widgets/unscheduled_day_dialog.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/state/todos_controller.dart';
import 'package:streak/features/todos/state/todo_tags_controller.dart';
import 'package:streak/features/todos/widgets/todo_composer.dart';
import 'package:streak/features/todos/widgets/todo_preview.dart';

const _entrance = Duration(milliseconds: 320);

class DayTimelinePage extends StatefulWidget {
  const DayTimelinePage({super.key});

  @override
  State<DayTimelinePage> createState() => _DayTimelinePageState();
}

class _DayTimelinePageState extends State<DayTimelinePage> {
  late DateTime _day = AppClock.today();
  final _celebration = ValueNotifier(0);
  PlanFilter _filter = PlanFilter.all;

  @override
  void dispose() {
    _celebration.dispose();
    super.dispose();
  }

  bool get _isToday => _day.isSameDay(AppClock.now());

  void _select(DateTime day) => setState(() => _day = day.atMidnight);

  void _shiftWeek(int weeks) => setState(
        () => _day = DateTime(_day.year, _day.month, _day.day + weeks * 7),
      );

  Future<void> _check(Habit habit) async {
    final controller = context.read<HabitsController>();
    if (!await allowManualCheck(context, habit: habit, date: _day)) return;
    if (!mounted) return;
    if (!await confirmUnscheduledDay(context, habit: habit, date: _day)) return;

    final wasDone = habit.isCompletedOn(_day);
    if (habit.kind == HabitKind.quantitative) {
      await controller.addProgress(habit.id, _day, habit.incrementAmount);
    } else {
      await controller.toggle(habit.id, _day);
    }
    if (!mounted) return;

    final updated = controller.byId(habit.id);
    if (_isToday && !wasDone && (updated?.isCompletedOn(_day) ?? false)) {
      _celebration.value++;
    }
  }

  Future<void> _checkTodo(Todo todo) async {
    final controller = context.read<TodosController>();
    final wasDone = todo.isCompletedOn(_day);
    await controller.toggle(todo.id);
    if (!mounted) return;

    final updated = controller.byId(todo.id);
    if (_isToday && !wasDone && (updated?.isCompletedOn(_day) ?? false)) {
      _celebration.value++;
    }
  }

  Future<void> _openTodo(Todo todo) async {
    final action = await showTodoPreview(context, todo);
    if (!mounted || action == null) return;
    if (action == 'edit') {
      final fresh = context.read<TodosController>().byId(todo.id) ?? todo;
      await showTodoComposer(context, todo: fresh);
    }
  }

  Future<void> _scheduleAt(int minutes) async {
    final todosEnabled = context.read<SettingsController>().todosEnabled;
    if (!todosEnabled) {
      await AppNavigator.push(const HabitFormPage());
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Schedule for ${minuteLabel(minutes)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.checkSquare2, color: context.colors.primary, size: 18),
                ),
                title: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Due ${minuteLabel(minutes)}'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(sheetContext, 'todo'),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.sparkles, color: context.colors.secondary, size: 18),
                ),
                title: const Text('Create Habit', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Routine or recurring activity'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(sheetContext, 'habit'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'todo') {
      await showTodoComposer(
        context,
        initialDate: _day.dayKey,
        initialMinutes: minutes,
      );
    } else if (choice == 'habit') {
      await AppNavigator.push(const HabitFormPage());
    }
  }

  Future<void> _quickAdd() async {
    final todosEnabled = context.read<SettingsController>().todosEnabled;
    if (!todosEnabled) {
      await AppNavigator.push(const HabitFormPage());
      return;
    }

    if (_filter == PlanFilter.todos) {
      await showTodoComposer(context, initialDate: _day.dayKey);
      return;
    }
    if (_filter == PlanFilter.habits) {
      await AppNavigator.push(const HabitFormPage());
      return;
    }

    final locale = Localizations.localeOf(context).toString();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat.yMMMMd(locale).format(_day),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.checkSquare2, color: context.colors.primary, size: 18),
                ),
                title: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Due on ${_day.dayKey}'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(sheetContext, 'todo'),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.sparkles, color: context.colors.secondary, size: 18),
                ),
                title: const Text('New Habit', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Routine or recurring activity'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(sheetContext, 'habit'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'todo') {
      await showTodoComposer(context, initialDate: _day.dayKey);
    } else if (choice == 'habit') {
      await AppNavigator.push(const HabitFormPage());
    }
  }

  Color _neighbourColor(DayPlan plan, int from, int step) {
    for (var i = from; i >= 0 && i < plan.slots.length; i += step) {
      final slot = plan.slots[i];
      if (slot.habit != null) return slot.habit!.color;
      if (slot.todo != null) {
        return slot.todo!.priority != TodoPriority.none
            ? todoPriorityColor(context, slot.todo!.priority)
            : context.colors.primary;
      }
    }
    return context.colors.primary;
  }

  List<Widget> _rows(BuildContext context, DayPlan plan) {
    final rows = <Widget>[];
    var index = 0;
    for (var i = 0; i < plan.slots.length; i++) {
      final slot = plan.slots[i];
      rows.add(
        Entrance(
          index: index,
          delay: _entrance,
          child: slot.isGap
              ? TimelineGap(
                  minutes: slot.minutes,
                  from: _neighbourColor(plan, i - 1, -1),
                  to: _neighbourColor(plan, i + 1, 1),
                  onTap: () => _scheduleAt(slot.start),
                )
              : slot.isHabit
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: TimelineBlock(
                        habit: slot.habit!,
                        date: _day,
                        done: slot.habit!.isCompletedOn(_day),
                        onOpen: () => AppNavigator.push(
                          HabitDetailsPage(habitId: slot.habit!.id),
                          fade: true,
                        ),
                        onCheck: () => _check(slot.habit!),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: TimelineTodoBlock(
                        todo: slot.todo!,
                        date: _day,
                        done: slot.todo!.isCompletedOn(_day),
                        onOpen: () => _openTodo(slot.todo!),
                        onCheck: () => _checkTodo(slot.todo!),
                      ),
                    ),
        ),
      );
      index++;
    }

    if (plan.anytimeHabits.isNotEmpty) {
      rows.add(const SizedBox(height: 22));
      rows.add(SectionLabel(context.l10n.day_timeline_anytime));
      for (final habit in plan.anytimeHabits) {
        rows.add(
          Entrance(
            index: index,
            delay: _entrance,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AnytimeRow(
                habit: habit,
                date: _day,
                done: habit.isCompletedOn(_day),
                onOpen: () => AppNavigator.push(
                  HabitDetailsPage(habitId: habit.id),
                  fade: true,
                ),
                onCheck: () => _check(habit),
              ),
            ),
          ),
        );
        index++;
      }
    }

    if (plan.anytimeTodos.isNotEmpty) {
      rows.add(const SizedBox(height: 22));
      rows.add(SectionLabel(context.l10n.todos));
      for (final todo in plan.anytimeTodos) {
        rows.add(
          Entrance(
            index: index,
            delay: _entrance,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AnytimeTodoRow(
                todo: todo,
                date: _day,
                done: todo.isCompletedOn(_day),
                onOpen: () => _openTodo(todo),
                onCheck: () => _checkTodo(todo),
              ),
            ),
          ),
        );
        index++;
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitsController>().habits;
    final todos = context.watch<TodosController>().all;
    final style = context.watch<SettingsController>();
    final todosEnabled = style.todosEnabled;
    final weekStart = style.weekStart;

    final plan = DayPlan.of(
      habits,
      _day,
      todos: todosEnabled ? todos : const [],
      filter: _filter,
    );
    final locale = Localizations.localeOf(context).toString();
    final first = _day.startOfWeek(weekStart);

    final express = style.isExpressStyle;
    final minimal = style.isMinimalStyle;
    final pushed = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: express ? 60 : null,
        leadingWidth: express && pushed ? 68 : null,
        leading: !pushed
            ? null
            : express
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(child: ExpressIconButton(
                  icon: LucideIcons.chevronLeft,
                  onPressed: () => AppNavigator.pop(),
                )),
              )
            : IconButton(
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: () => AppNavigator.pop(),
              ),
        title: express || minimal
            ? null
            : Text(DateFormat.yMMMM(locale).format(_day)),
        actions: [
          express
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    child: ExpressIconButton(
                      icon: LucideIcons.plus,
                      tooltip: 'Add',
                      onPressed: _quickAdd,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Add',
                  icon: const Icon(LucideIcons.plus),
                  onPressed: _quickAdd,
                ),
          if (!_isToday)
            express
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(child: ExpressIconButton(
                      icon: LucideIcons.calendarCheck,
                      tooltip: context.l10n.today,
                      onPressed: () => _select(AppClock.now()),
                    )),
                  )
                : IconButton(
                    tooltip: context.l10n.today,
                    icon: const Icon(LucideIcons.calendarCheck),
                    onPressed: () => _select(AppClock.now()),
                  ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (express)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: ExpressHeadline(
                    title: DateFormat.yMMMM(locale).format(_day),
                  ),
                ),
              if (minimal)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: MinimalTitle(
                    title: DateFormat.yMMMM(locale).format(_day),
                  ),
                ),
              _WeekStrip(
                first: first,
                selected: _day,
                habits: habits,
                todos: todosEnabled ? todos : const [],
                style: style.appStyle,
                onSelected: _select,
                onShift: _shiftWeek,
              ),
              if (todosEnabled)
                _PlanFilterBar(
                  selected: _filter,
                  totalAll: plan.totalHabits + plan.totalTodos,
                  totalHabits: plan.totalHabits,
                  totalTodos: plan.totalTodos,
                  style: style.appStyle,
                  onChanged: (f) => setState(() => _filter = f),
                ),
              _PlanSummaryStrip(
                plan: plan,
                todosEnabled: todosEnabled,
              ),
              Expanded(
                child: plan.isEmpty
                    ? AppEmptyState(
                        icon: LucideIcons.calendarClock,
                        title: context.l10n.day_timeline_empty,
                        message: todosEnabled
                            ? 'Schedule habits or tasks to build your day timeline.'
                            : context.l10n.day_timeline_empty_sub,
                      )
                    : ListView(
                        padding:
                            context.pagePadding(16, 8, 16, pushed ? 28 : 148),
                        children: _rows(context, plan),
                      ),
              ),
            ],
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _celebration,
                builder: (context, trigger, _) =>
                    CelebrationOverlay(trigger: trigger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanFilterBar extends StatelessWidget {
  const _PlanFilterBar({
    required this.selected,
    required this.totalAll,
    required this.totalHabits,
    required this.totalTodos,
    required this.style,
    required this.onChanged,
  });

  final PlanFilter selected;
  final int totalAll;
  final int totalHabits;
  final int totalTodos;
  final int style;
  final ValueChanged<PlanFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final express = style == 2;
    final minimal = style == 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(express ? 16 : 14, 0, express ? 16 : 14, 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius:
              BorderRadius.circular(express ? 20 : (minimal ? 12 : 14)),
          border: minimal
              ? Border.all(color: muted.withValues(alpha: 0.18))
              : null,
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: _FilterTab(
                label: 'All',
                count: totalAll,
                selected: selected == PlanFilter.all,
                express: express,
                minimal: minimal,
                onTap: () => onChanged(PlanFilter.all),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FilterTab(
                label: 'Habits',
                count: totalHabits,
                selected: selected == PlanFilter.habits,
                express: express,
                minimal: minimal,
                onTap: () => onChanged(PlanFilter.habits),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FilterTab(
                label: 'Tasks',
                count: totalTodos,
                selected: selected == PlanFilter.todos,
                express: express,
                minimal: minimal,
                onTap: () => onChanged(PlanFilter.todos),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.express,
    required this.minimal,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool express;
  final bool minimal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? (minimal
                    ? scheme.onSurface
                    : (express ? scheme.primary : scheme.surface))
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(express ? 16 : (minimal ? 9 : 11)),
            boxShadow: selected && !minimal
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? (minimal
                          ? scheme.surface
                          : (express ? scheme.onPrimary : scheme.onSurface))
                      : muted,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? (express
                            ? scheme.onPrimary.withValues(alpha: 0.22)
                            : scheme.surfaceContainerHighest)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? (minimal
                              ? scheme.surface
                              : (express ? scheme.onPrimary : scheme.onSurface))
                          : muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanSummaryStrip extends StatelessWidget {
  const _PlanSummaryStrip({
    required this.plan,
    required this.todosEnabled,
  });

  final DayPlan plan;
  final bool todosEnabled;

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) return const SizedBox.shrink();

    final muted = context.tokens.muted;
    final scheduledMinutes = plan.totalScheduledMinutes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            if (scheduledMinutes > 0) ...[
              Icon(LucideIcons.clock, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '${spanLabel(scheduledMinutes)} planned',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (plan.totalHabits > 0) ...[
              Icon(LucideIcons.sparkles, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '${plan.completedHabits}/${plan.totalHabits} habits',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (todosEnabled && plan.totalTodos > 0) ...[
              Icon(LucideIcons.checkSquare2, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '${plan.completedTodos}/${plan.totalTodos} tasks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.first,
    required this.selected,
    required this.habits,
    required this.todos,
    required this.style,
    required this.onSelected,
    required this.onShift,
  });

  final DateTime first;
  final DateTime selected;
  final List<Habit> habits;
  final List<Todo> todos;
  final int style;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final express = style == 2;
    final labels = WeekdayLabels.shortFrom(
      Localizations.localeOf(context).languageCode,
      first.weekday,
    );

    final row = Row(
      children: [
        express
            ? ExpressIconButton(
                icon: LucideIcons.chevronLeft,
                size: 26,
                tint: context.tokens.muted,
                background: Colors.transparent,
                tooltip: context.l10n.a11y_previous_week,
                onPressed: () => onShift(-1),
              )
            : IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                tooltip: context.l10n.a11y_previous_week,
                visualDensity: VisualDensity.compact,
                onPressed: () => onShift(-1),
              ),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayChip(
              day: DateTime(first.year, first.month, first.day + i),
              label: labels[i],
              selected: DateTime(
                first.year,
                first.month,
                first.day + i,
              ).isSameDay(selected),
              habits: habits,
              todos: todos,
              style: style,
              onTap: onSelected,
            ),
          ),
        express
            ? ExpressIconButton(
                icon: LucideIcons.chevronRight,
                size: 26,
                tint: context.tokens.muted,
                background: Colors.transparent,
                tooltip: context.l10n.a11y_next_week,
                onPressed: () => onShift(1),
              )
            : IconButton(
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                tooltip: context.l10n.a11y_next_week,
                visualDensity: VisualDensity.compact,
                onPressed: () => onShift(1),
              ),
      ],
    );

    return Column(
      children: [
        Padding(
          padding: express
              ? const EdgeInsets.symmetric(horizontal: 6)
              : const EdgeInsets.symmetric(horizontal: 4),
          child: express
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) =>
                      onShift((details.primaryVelocity ?? 0) < 0 ? 1 : -1),
                  child: row,
                )
              : row,
        ),
        SizedBox(height: express ? 14 : 8),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.label,
    required this.selected,
    required this.habits,
    required this.todos,
    required this.style,
    required this.onTap,
  });

  final DateTime day;
  final String label;
  final bool selected;
  final List<Habit> habits;
  final List<Todo> todos;
  final int style;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final express = style == 2;
    final minimal = style == 1;
    final scheme = context.colors;
    final accent = scheme.primary;
    final today = day.isSameDay(AppClock.now());
    final dots = [
      for (final habit in habits)
        if (DayPlan.isDueOn(habit, day) && habit.isPlanned) habit.color,
      for (final todo in todos)
        if (DayPlan.isTodoDueOn(todo, day) && todo.minutes != null)
          (todo.priority != TodoPriority.none
              ? todoPriorityColor(context, todo.priority)
              : accent),
    ].take(4).toList();

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () => onTap(day),
        child: AnimatedContainer(
          duration: express ? Express.morph : const Duration(milliseconds: 180),
          curve: express ? Express.bouncy : Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: express ? 1.5 : 2.5),
          padding: EdgeInsets.symmetric(vertical: express ? 8 : 7),
          decoration: express
              ? BoxDecoration(
                  color: selected
                      ? accent
                      : scheme.surfaceContainerHigh.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(selected ? 22 : 14),
                )
              : minimal
                  ? BoxDecoration(
                      color: selected
                          ? scheme.onSurface
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : BoxDecoration(
                      color: selected ? accent.withValues(alpha: 0.12) : null,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: selected
                            ? accent
                            : scheme.outlineVariant.withValues(alpha: 0.5),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.replaceAll('.', ''),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: express
                      ? ExpressType.body.at(
                          10,
                          weight: 800,
                          height: 1.1,
                          color: selected
                              ? scheme.onPrimary
                              : context.tokens.muted,
                        )
                      : minimal
                          ? MinimalType.label(
                              size: 10.5,
                              color: selected
                                  ? scheme.surface
                                  : context.tokens.muted,
                            )
                          : TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: selected ? accent : context.tokens.muted,
                            ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  maxLines: 1,
                  style: express
                      ? ExpressType.display.at(
                          17,
                          height: 1.1,
                          color: selected
                              ? scheme.onPrimary
                              : today
                                  ? scheme.onSurface
                                  : context.tokens.muted,
                          tabular: true,
                        )
                      : minimal
                          ? MinimalType.figure(
                              16,
                              height: 1.1,
                              color: selected
                                  ? scheme.surface
                                  : today
                                      ? scheme.onSurface
                                      : context.tokens.muted,
                            )
                          : TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: selected
                                  ? accent
                                  : today
                                      ? scheme.onSurface
                                      : context.tokens.muted,
                            ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final color in dots)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnytimeRow extends StatelessWidget {
  const _AnytimeRow({
    required this.habit,
    required this.date,
    required this.done,
    required this.onOpen,
    required this.onCheck,
  });

  final Habit habit;
  final DateTime date;
  final bool done;
  final VoidCallback onOpen;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(
              alpha: done ? 0.35 : 0.6,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: habit.color.withValues(alpha: done ? 0.5 : 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HabitGlyph(
                  glyph: habit.icon,
                  color: done ? scheme.surface : habit.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: done ? context.tokens.muted : scheme.onSurface,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: context.tokens.muted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TimelineCheck(
                habit: habit,
                date: date,
                done: done,
                onTap: onCheck,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnytimeTodoRow extends StatelessWidget {
  const _AnytimeTodoRow({
    required this.todo,
    required this.date,
    required this.done,
    required this.onOpen,
    required this.onCheck,
  });

  final Todo todo;
  final DateTime date;
  final bool done;
  final VoidCallback onOpen;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final priorityColor = todo.priority != TodoPriority.none
        ? todoPriorityColor(context, todo.priority)
        : scheme.primary;

    final project = todo.project.isNotEmpty
        ? context.watch<TodoTagsController>().byId(todo.project)
        : null;

    final accentColor = project != null ? project.color : priorityColor;

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(
              alpha: done ? 0.35 : 0.6,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: done ? 0.35 : 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    todo.isRecurring
                        ? LucideIcons.repeat
                        : LucideIcons.checkSquare2,
                    color: done ? scheme.surface : accentColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      todo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: done ? muted : scheme.onSurface,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: muted,
                      ),
                    ),
                    if (project != null ||
                        todo.priority != TodoPriority.none ||
                        todo.steps.isNotEmpty ||
                        todo.isRecurring) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (project != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.folder,
                                  size: 10,
                                  color: project.color,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  project.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: project.color,
                                  ),
                                ),
                              ],
                            ),
                          if (todo.priority != TodoPriority.none)
                            Text(
                              todo.priority.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: priorityColor,
                              ),
                            ),
                          if (todo.steps.isNotEmpty)
                            Text(
                              '${todo.steps.where((s) => s.done).length}/${todo.steps.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                          if (todo.isRecurring)
                            Icon(LucideIcons.repeat, size: 11, color: muted),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TimelineTodoCheck(
                todo: todo,
                done: done,
                onTap: onCheck,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
