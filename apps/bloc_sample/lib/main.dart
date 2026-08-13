import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'counter/counter_cubit.dart';
import 'todos/todos_bloc.dart';

void main() {
  runApp(const BlocSampleApp());
}

class BlocSampleApp extends StatelessWidget {
  const BlocSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloc Sample',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bloc Sample')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.exposure_plus_1),
            title: const Text('Counter (Cubit)'),
            subtitle: const Text('Simple state with CounterCubit'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CounterPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Todos (Bloc)'),
            subtitle: const Text('Events, states and filtering'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TodosPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: const CounterView(),
    );
  }
}

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CounterCubit')),
      body: Center(
        child: BlocBuilder<CounterCubit, int>(
          builder: (context, count) => Text(
            '$count',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'increment',
            onPressed: () => context.read<CounterCubit>().increment(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'decrement',
            onPressed: () => context.read<CounterCubit>().decrement(),
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TodosBloc()..add(const TodosStarted()),
      child: const TodosView(),
    );
  }
}

class TodosView extends StatefulWidget {
  const TodosView({super.key});

  @override
  State<TodosView> createState() => _TodosViewState();
}

class _TodosViewState extends State<TodosView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<TodosBloc>().add(TodoAdded(text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TodosBloc'),
        actions: [
          BlocSelector<TodosBloc, TodosState, TodosFilter>(
            selector: (state) => state.filter,
            builder: (context, filter) => SegmentedButton<TodosFilter>(
              segments: const [
                ButtonSegment(value: TodosFilter.all, label: Text('All')),
                ButtonSegment(
                  value: TodosFilter.active,
                  label: Text('Active'),
                ),
                ButtonSegment(
                  value: TodosFilter.completed,
                  label: Text('Done'),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (selection) => context
                  .read<TodosBloc>()
                  .add(TodosFilterChanged(selection.first)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'What needs to be done?',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<TodosBloc, TodosState>(
              builder: (context, state) {
                if (state.status == TodosStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final todos = state.visibleTodos;
                if (todos.isEmpty) {
                  return const Center(child: Text('No todos'));
                }
                return ListView.builder(
                  itemCount: todos.length,
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return CheckboxListTile(
                      title: Text(
                        todo.title,
                        style: todo.completed
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      value: todo.completed,
                      onChanged: (_) => context
                          .read<TodosBloc>()
                          .add(TodoToggled(todo.id)),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => context
                            .read<TodosBloc>()
                            .add(TodoDeleted(todo.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
