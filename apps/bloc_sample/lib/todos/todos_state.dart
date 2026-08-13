part of 'todos_bloc.dart';

enum TodosStatus { initial, loading, success, failure }

enum TodosFilter { all, active, completed }

class Todo extends Equatable {
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

  @override
  List<Object?> get props => [id, title, completed];
}

class TodosState extends Equatable {
  const TodosState({
    this.status = TodosStatus.initial,
    this.todos = const [],
    this.filter = TodosFilter.all,
  });

  final TodosStatus status;
  final List<Todo> todos;
  final TodosFilter filter;

  List<Todo> get visibleTodos => switch (filter) {
        TodosFilter.all => todos,
        TodosFilter.active => todos.where((t) => !t.completed).toList(),
        TodosFilter.completed => todos.where((t) => t.completed).toList(),
      };

  TodosState copyWith({
    TodosStatus? status,
    List<Todo>? todos,
    TodosFilter? filter,
  }) {
    return TodosState(
      status: status ?? this.status,
      todos: todos ?? this.todos,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [status, todos, filter];
}
