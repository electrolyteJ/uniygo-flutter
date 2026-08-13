import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TodosFilter { all, active, completed }

class Todo {
  const Todo({required this.id, required this.title, this.completed = false});

  final int id;
  final String title;
  final bool completed;

  Todo copyWith({String? title, bool? completed}) {
    return Todo(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}

/// Holds the todo list; simulates an async repository fetch on startup.
final todosProvider = AsyncNotifierProvider<TodosNotifier, List<Todo>>(
  TodosNotifier.new,
);

class TodosNotifier extends AsyncNotifier<List<Todo>> {
  @override
  Future<List<Todo>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      Todo(id: 1, title: 'Learn Riverpod', completed: true),
      Todo(id: 2, title: 'Build a sample app'),
    ];
  }

  void add(String title) {
    final todos = state.value ?? [];
    final nextId = todos.isEmpty
        ? 1
        : todos.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    state = AsyncData([...todos, Todo(id: nextId, title: title)]);
  }

  void toggle(int id) {
    final todos = state.value ?? [];
    state = AsyncData([
      for (final todo in todos)
        todo.id == id ? todo.copyWith(completed: !todo.completed) : todo,
    ]);
  }

  void remove(int id) {
    final todos = state.value ?? [];
    state = AsyncData(todos.where((t) => t.id != id).toList());
  }
}

final todosFilterProvider = NotifierProvider<TodosFilterNotifier, TodosFilter>(
  TodosFilterNotifier.new,
);

class TodosFilterNotifier extends Notifier<TodosFilter> {
  @override
  TodosFilter build() => TodosFilter.all;

  void set(TodosFilter filter) => state = filter;
}

/// Derived provider combining the list and the current filter.
final filteredTodosProvider = Provider<AsyncValue<List<Todo>>>((ref) {
  final filter = ref.watch(todosFilterProvider);
  final todos = ref.watch(todosProvider);
  return todos.whenData(
    (list) => switch (filter) {
      TodosFilter.all => list,
      TodosFilter.active => list.where((t) => !t.completed).toList(),
      TodosFilter.completed => list.where((t) => t.completed).toList(),
    },
  );
});
