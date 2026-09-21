import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/utils/cover_storage.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_groups.dart';
import 'package:streak/features/todos/data/todo_recurrence.dart';
import 'package:streak/services/notification_service.dart';
import 'package:streak/services/todos_widget_service.dart';
import 'package:uuid/uuid.dart';

class TodosController extends ChangeNotifier {
  TodosController() {
    _todos = LocalStore.readTodos();
    if (!NotificationService.armedToday('todoRemindersArmedOn')) {
      unawaited(_notifications.rescheduleTodos(_todos));
    }
  }

  final _notifications = NotificationService();

  late List<Todo> _todos;

  List<Todo> get all => List.unmodifiable(_todos);

  List<TodoSection> get sections => groupPending(_todos, AppClock.today());

  List<Todo> get completed => sortCompleted(_todos);

  int get pendingCount => _todos.where((t) => !t.done).length;

  int get completedCount => _todos.where((t) => t.hasCompletions).length;

  int get dueTodayCount {
    final today = AppClock.today().epochDay;
    return _todos.where((t) {
      final due = t.due;
      return !t.done && due != null && due.epochDay <= today;
    }).length;
  }

  void reload() {
    _todos = LocalStore.readTodos();
    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
  }

  Todo? byId(String id) => _todos.where((t) => t.id == id).firstOrNull;

  Future<Todo> create({
    required String text,
    String date = '',
    int? minutes,
    int? durationMinutes,
    TodoRecurrence? recurrence,
    TodoPriority priority = TodoPriority.none,
    List<String> photos = const [],
    List<String> tags = const [],
    String project = '',
    List<TodoStep> steps = const [],
  }) async {
    final todo = Todo(
      id: const Uuid().v4(),
      text: text.trim(),
      date: date,
      minutes: minutes,
      durationMinutes: durationMinutes,
      recurrence: recurrence,
      priority: priority,
      photos: photos,
      tags: tags,
      project: project,
      steps: steps,
      createdAt: DateTime.now(),
    );
    _todos.add(todo);
    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
    await LocalStore.writeTodo(todo);
    await _notifications.scheduleTodo(todo);
    return todo;
  }

  Future<void> update(Todo todo) async {
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index == -1) return;
    final dropped =
        _todos[index].photos.where((p) => !todo.photos.contains(p)).toList();
    _todos[index] = todo;
    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
    await LocalStore.writeTodo(todo);
    await CoverStorage.forgetAll(dropped);
    await _notifications.scheduleTodo(todo);
  }

  Future<void> toggle(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final current = _todos[index];

    if (current.isRecurring) {
      // Recurring to-do completion logic
      final today = AppClock.today();
      final todayKey = today.dayKey;
      final isAlreadyCompletedToday = current.completedDates.contains(todayKey);

      if (!isAlreadyCompletedToday) {
        // Complete current occurrence and advance to next recurrence
        final base = current.due != null && current.due!.isAfter(today)
            ? current.due!
            : today;
        final nextDate = current.recurrence!.nextOccurrence(base);
        final completed = [...current.completedDates, todayKey];
        final resetSteps = [
          for (final step in current.steps) step.copyWith(done: false),
        ];
        final updated = current.copyWith(
          date: nextDate.dayKey,
          completedDates: completed,
          steps: resetSteps,
          done: false,
          doneAt: DateTime.now(),
        );
        _todos[index] = updated;
        notifyListeners();
        TodosWidgetService.syncSoon(_todos);
        await LocalStore.writeTodo(updated);
        await _notifications.scheduleTodo(updated);
        return;
      } else {
        // Undo today's completion
        final completed = [...current.completedDates]..remove(todayKey);
        final updated = current.copyWith(
          date: todayKey,
          completedDates: completed,
          done: false,
          clearDoneAt: true,
        );
        _todos[index] = updated;
        notifyListeners();
        TodosWidgetService.syncSoon(_todos);
        await LocalStore.writeTodo(updated);
        await _notifications.scheduleTodo(updated);
        return;
      }
    }

    final done = !current.done;
    final updated = current.copyWith(
      done: done,
      doneAt: done ? DateTime.now() : null,
      clearDoneAt: !done,
    );
    _todos[index] = updated;
    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
    await LocalStore.writeTodo(updated);
    await _notifications.scheduleTodo(updated);
  }

  Future<void> undoLastCompletion(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final current = _todos[index];

    if (current.isRecurring && current.completedDates.isNotEmpty) {
      final today = AppClock.today();
      final todayKey = today.dayKey;
      final targetKey = current.completedDates.contains(todayKey)
          ? todayKey
          : current.completedDates.last;
      final completed = [...current.completedDates]..remove(targetKey);
      final updated = current.copyWith(
        date: targetKey,
        completedDates: completed,
        done: false,
        clearDoneAt: completed.isEmpty,
      );
      _todos[index] = updated;
      notifyListeners();
      TodosWidgetService.syncSoon(_todos);
      await LocalStore.writeTodo(updated);
      await _notifications.scheduleTodo(updated);
      return;
    }

    if (current.done) {
      final updated = current.copyWith(
        done: false,
        clearDoneAt: true,
      );
      _todos[index] = updated;
      notifyListeners();
      TodosWidgetService.syncSoon(_todos);
      await LocalStore.writeTodo(updated);
      await _notifications.scheduleTodo(updated);
    }
  }

  Future<void> updateNotes(String id, String newText) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final updated = _todos[index].copyWith(text: newText.trim());
    _todos[index] = updated;
    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
    await LocalStore.writeTodo(updated);
  }

  Future<void> appendNote(String id, String note, {DateTime? date}) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final current = _todos[index];
    final timestamp = date ?? DateTime.now();
    final dateLabel =
        '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final entry = '\n\n— Note ($dateLabel):\n${note.trim()}';
    final updated = current.copyWith(text: '${current.text.trim()}$entry');
    _todos[index] = updated;
    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
    await LocalStore.writeTodo(updated);
  }

  Future<void> toggleStep(String id, String stepId) async {
    final todo = _todos.where((t) => t.id == id).firstOrNull;
    if (todo == null) return;
    await update(
      todo.copyWith(
        steps: [
          for (final step in todo.steps)
            step.id == stepId ? step.copyWith(done: !step.done) : step,
        ],
      ),
    );
  }

  Future<void> remove(String id) async {
    final photos = [
      for (final todo in _todos.where((t) => t.id == id)) ...todo.photos,
    ];
    _todos.removeWhere((t) => t.id == id);
    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
    await _notifications.cancelTodo(id);
    await LocalStore.removeTodo(id);
    await CoverStorage.forgetAll(photos);
  }

  Future<void> forgetTag(String tagId) async {
    final touched = _todos.where((t) => t.tags.contains(tagId)).toList();
    if (touched.isEmpty) return;
    for (final todo in touched) {
      final updated = todo.copyWith(
        tags: [...todo.tags]..remove(tagId),
      );
      _todos[_todos.indexWhere((t) => t.id == todo.id)] = updated;
      await LocalStore.writeTodo(updated);
    }
    notifyListeners();
  }

  Future<void> forgetProject(String projectId) async {
    final touched = _todos.where((t) => t.project == projectId).toList();
    if (touched.isEmpty) return;
    for (final todo in touched) {
      final updated = todo.copyWith(project: '');
      _todos[_todos.indexWhere((t) => t.id == todo.id)] = updated;
      await LocalStore.writeTodo(updated);
    }
    notifyListeners();
  }

  bool _inProject(Todo todo, String? project) => switch (project) {
        null => true,
        '' => todo.project.isEmpty,
        final id => todo.project == id,
      };

  int countFor(String tagId, {String? project}) => _todos
      .where((t) => !t.done && t.tags.contains(tagId) && _inProject(t, project))
      .length;

  int untaggedCount({String? project}) => _todos
      .where((t) => !t.done && t.tags.isEmpty && _inProject(t, project))
      .length;

  int projectCount(String projectId) =>
      _todos.where((t) => !t.done && t.project == projectId).length;

  int get looseCount => _todos.where((t) => !t.done && t.project.isEmpty).length;

  Future<void> clearCompleted() async {
    final done = _todos.where((t) => t.done).toList();
    final recurringWithCompletions =
        _todos.where((t) => t.isRecurring && t.completedDates.isNotEmpty).toList();
    if (done.isEmpty && recurringWithCompletions.isEmpty) return;

    final photos = [for (final todo in done) ...todo.photos];
    _todos.removeWhere((t) => t.done);

    for (final rec in recurringWithCompletions) {
      final index = _todos.indexWhere((t) => t.id == rec.id);
      if (index != -1) {
        final reset = _todos[index].copyWith(
          completedDates: const [],
          clearDoneAt: true,
        );
        _todos[index] = reset;
        await LocalStore.writeTodo(reset);
      }
    }

    notifyListeners();
    TodosWidgetService.syncSoon(_todos);
    await LocalStore.removeTodos(done.map((t) => t.id));
    await CoverStorage.forgetAll(photos);
  }
}
