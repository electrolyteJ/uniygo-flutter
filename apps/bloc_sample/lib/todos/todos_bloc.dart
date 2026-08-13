import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'todos_event.dart';
part 'todos_state.dart';

class TodosBloc extends Bloc<TodosEvent, TodosState> {
  TodosBloc() : super(const TodosState()) {
    on<TodosStarted>(_onStarted);
    on<TodoAdded>(_onAdded);
    on<TodoToggled>(_onToggled);
    on<TodoDeleted>(_onDeleted);
    on<TodosFilterChanged>(_onFilterChanged);
  }

  Future<void> _onStarted(
    TodosStarted event,
    Emitter<TodosState> emit,
  ) async {
    emit(state.copyWith(status: TodosStatus.loading));
    // Simulate a repository fetch.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    emit(
      state.copyWith(
        status: TodosStatus.success,
        todos: const [
          Todo(id: 1, title: 'Learn Bloc', completed: true),
          Todo(id: 2, title: 'Build a sample app'),
        ],
      ),
    );
  }

  void _onAdded(TodoAdded event, Emitter<TodosState> emit) {
    final nextId = state.todos.isEmpty
        ? 1
        : state.todos.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    emit(
      state.copyWith(
        todos: [...state.todos, Todo(id: nextId, title: event.title)],
      ),
    );
  }

  void _onToggled(TodoToggled event, Emitter<TodosState> emit) {
    emit(
      state.copyWith(
        todos: [
          for (final todo in state.todos)
            todo.id == event.id
                ? todo.copyWith(completed: !todo.completed)
                : todo,
        ],
      ),
    );
  }

  void _onDeleted(TodoDeleted event, Emitter<TodosState> emit) {
    emit(
      state.copyWith(
        todos: state.todos.where((t) => t.id != event.id).toList(),
      ),
    );
  }

  void _onFilterChanged(TodosFilterChanged event, Emitter<TodosState> emit) {
    emit(state.copyWith(filter: event.filter));
  }
}
