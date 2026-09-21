import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/routing/app_navigator.dart';
import 'package:streak/core/widgets/photo_deck.dart';
import 'package:streak/features/focus/pages/focus_page.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/habits/data/category.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/state/todo_tags_controller.dart';
import 'package:streak/features/todos/widgets/todo_labels.dart';

class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.overdue,
    this.completedView = false,
    this.corners,
    this.showProject = false,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final bool overdue;
  final bool completedView;
  final BorderRadius? corners;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final accent = todoPriorityColor(context, todo.priority);
    final due = todo.due;
    final isDone = todo.done || completedView;
    final style = context.watch<SettingsController>();
    final minimal = style.isMinimalStyle;
    final express = style.isExpressStyle;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final project = showProject && todo.project.isNotEmpty
        ? context.watch<TodoTagsController>().byId(todo.project)
        : null;

    final cardBg = minimal
        ? (isDark ? scheme.surfaceContainer : scheme.surface)
        : express
            ? scheme.surfaceContainer
            : (isDark ? scheme.surfaceContainerLow : scheme.surface);

    final borderColor = isDone
        ? Colors.transparent
        : (minimal
            ? muted.withValues(alpha: 0.22)
            : scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55));

    final hasBadges = !isDone
        ? (due != null ||
            project != null ||
            todo.tags.isNotEmpty ||
            todo.steps.isNotEmpty ||
            todo.isRecurring ||
            todo.durationMinutes != null ||
            todo.priority != TodoPriority.none)
        : (project != null ||
            todo.isRecurring ||
            todo.lastCompletedAt != null ||
            due != null ||
            todo.durationMinutes != null ||
            todo.steps.isNotEmpty ||
            todo.tags.isNotEmpty);

    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: isDone ? cardBg.withValues(alpha: 0.65) : cardBg,
          borderRadius: corners ?? BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: (!minimal && !isDone && !isDark)
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: _CheckButton(
                todo: todo,
                checked: isDone,
                onToggle: onToggle,
                priorityColor: todo.priority == TodoPriority.none || isDone
                    ? null
                    : accent,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                      height: 1.3,
                      color: isDone ? muted : scheme.onSurface,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: muted,
                    ),
                  ),
                  if (todo.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      todo.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: muted.withValues(alpha: isDone ? 0.65 : 0.9),
                      ),
                    ),
                  ],
                  if (hasBadges) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!isDone && todo.priority != TodoPriority.none)
                          _TodoBadge(
                            icon: LucideIcons.flag,
                            label: todoPriorityLabels(context)[todo.priority.index],
                            color: accent,
                            background: accent.withValues(alpha: 0.14),
                          ),
                        if (project != null)
                          _TodoBadge(
                            icon: CategoryIcons.resolve(project.icon),
                            label: project.name,
                            color: project.color,
                            background: project.color.withValues(alpha: 0.16),
                          ),
                        if (!isDone && due != null)
                          _TodoBadge(
                            icon: overdue
                                ? LucideIcons.alertCircle
                                : (todo.time == null
                                    ? LucideIcons.calendar
                                    : LucideIcons.clock),
                            label: todoDueLabel(context, todo),
                            color: overdue ? context.tokens.danger : muted,
                            background: overdue
                                ? context.tokens.danger.withValues(alpha: 0.12)
                                : scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                          ),
                        if (todo.isRecurring)
                          _TodoBadge(
                            icon: LucideIcons.repeat,
                            label: todo.recurrence!.shortBadge,
                            color: scheme.primary,
                            background: scheme.primary.withValues(alpha: 0.12),
                          ),
                        if (isDone && todo.isRecurring) ...[
                          _TodoBadge(
                            icon: LucideIcons.checkCheck,
                            label: '${todo.completedDates.length} completed',
                            color: scheme.primary,
                            background: scheme.primary.withValues(alpha: 0.12),
                          ),
                          if (todo.lastCompletedAt != null)
                            _TodoBadge(
                              icon: LucideIcons.calendarCheck,
                              label:
                                  'Last: ${_formatCompletedDay(context, todo.lastCompletedAt!)}',
                              color: muted,
                              background: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                            ),
                        ] else if (isDone) ...[
                          if (todo.lastCompletedAt != null)
                            _TodoBadge(
                              icon: LucideIcons.calendarCheck,
                              label:
                                  'Done ${_formatCompletedDay(context, todo.lastCompletedAt!)}',
                              color: muted,
                              background: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                            )
                          else if (due != null)
                            _TodoBadge(
                              icon: LucideIcons.calendar,
                              label: todoDueLabel(context, todo),
                              color: muted,
                              background: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                            ),
                        ],
                        if (todo.durationMinutes != null &&
                            todo.durationMinutes! > 0)
                          _TodoBadge(
                            icon: LucideIcons.hourglass,
                            label: formatTodoDuration(todo.durationMinutes!),
                            color: muted,
                            background: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                          ),
                        if (todo.steps.isNotEmpty)
                          _TodoBadge(
                            icon: todo.steps.every((s) => s.done)
                                ? LucideIcons.checkCheck
                                : LucideIcons.listChecks,
                            label:
                                '${todo.steps.where((s) => s.done).length}/${todo.steps.length}',
                            color: todo.steps.every((s) => s.done)
                                ? context.tokens.success
                                : muted,
                            background: (todo.steps.every((s) => s.done)
                                    ? context.tokens.success
                                    : muted)
                                .withValues(alpha: 0.12),
                          ),
                        for (final tag in context
                            .watch<TodoTagsController>()
                            .resolve(todo.tags))
                          _TodoBadge(
                            icon: CategoryIcons.resolve(tag.icon),
                            label: tag.name,
                            color: tag.color,
                            background: tag.color.withValues(alpha: 0.14),
                          ),
                      ],
                    ),
                  ],
                  if (todo.photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    PhotoDeck(
                      shots: todoPhotoShots(todo),
                      size: 56,
                      swipe: false,
                    ),
                  ],
                ],
              ),
            ),
            if (!isDone) ...[
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Focus',
                child: IconButton(
                  icon: const Icon(LucideIcons.timer, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Start Focus Timer',
                  color: muted.withValues(alpha: 0.65),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: () => AppNavigator.push(
                    FocusPage(startTodo: todo),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatCompletedDay(BuildContext context, DateTime day) {
  final now = DateTime.now();
  if (day.year == now.year && day.month == now.month && day.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (day.year == yesterday.year &&
      day.month == yesterday.month &&
      day.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${day.day}/${day.month}';
}

class _TodoBadge extends StatelessWidget {
  const _TodoBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: color),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckButton extends StatefulWidget {
  const _CheckButton({
    required this.todo,
    required this.onToggle,
    this.checked = false,
    this.priorityColor,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final bool checked;
  final Color? priorityColor;

  @override
  State<_CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<_CheckButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.15), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _anim,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.lightImpact();
    _anim.forward(from: 0.0);
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final circle = context.watch<SettingsController>().isCircleCheck;
    final radius = BorderRadius.circular(circle ? 13 : 8);
    final muted = context.tokens.muted;
    final borderColor = widget.checked
        ? scheme.primary
        : (widget.priorityColor != null
            ? widget.priorityColor!.withValues(alpha: 0.75)
            : muted.withValues(alpha: 0.45));

    return Semantics(
      container: true,
      button: true,
      checked: widget.checked,
      label: widget.checked
          ? context.l10n.a11y_mark_not_done(widget.todo.title)
          : context.l10n.a11y_mark_done(widget.todo.title),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _tap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: widget.checked ? scheme.primary : Colors.transparent,
                borderRadius: radius,
                border: Border.all(
                  color: borderColor,
                  width: widget.checked ? 1.8 : 1.8,
                ),
                boxShadow: widget.checked
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: widget.checked
                  ? Icon(LucideIcons.check, size: 14.5, color: scheme.onPrimary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
