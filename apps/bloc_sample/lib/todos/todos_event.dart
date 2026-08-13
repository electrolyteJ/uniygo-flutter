part of 'todos_bloc.dart';

sealed class TodosEvent extends Equatable {
  const TodosEvent();

  @override
  List<Object?> get props => [];
}

final class TodosStarted extends TodosEvent {
  const TodosStarted();
}

final class TodoAdded extends TodosEvent {
  const TodoAdded(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

final class TodoToggled extends TodosEvent {
  const TodoToggled(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

final class TodoDeleted extends TodosEvent {
  const TodoDeleted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

final class TodosFilterChanged extends TodosEvent {
  const TodosFilterChanged(this.filter);

  final TodosFilter filter;

  @override
  List<Object?> get props => [filter];
}
