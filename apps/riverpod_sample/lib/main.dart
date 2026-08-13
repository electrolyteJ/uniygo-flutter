import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'counter/counter_provider.dart';
import 'todos/todos_provider.dart';

void main() {
  runApp(const ProviderScope(child: RiverpodSampleApp()));
}

class RiverpodSampleApp extends StatelessWidget {
  const RiverpodSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riverpod Sample',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod Sample')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.exposure_plus_1),
            title: const Text('Counter (NotifierProvider)'),
            subtitle: const Text('Simple state with a Notifier'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CounterPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Todos (AsyncNotifier)'),
            subtitle: const Text('Async loading, derived providers'),
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

class CounterPage extends ConsumerWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Counter Notifier')),
      body: Center(
        child: Text('$count', style: Theme.of(context).textTheme.displayLarge),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'increment',
            onPressed: () => ref.read(counterProvider.notifier).increment(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'decrement',
            onPressed: () => ref.read(counterProvider.notifier).decrement(),
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({super.key});

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(todosProvider.notifier).add(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(filteredTodosProvider);
    final filter = ref.watch(todosFilterProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos Notifier'),
        actions: [
          SegmentedButton<TodosFilter>(
            segments: const [
              ButtonSegment(value: TodosFilter.all, label: Text('All')),
              ButtonSegment(value: TodosFilter.active, label: Text('Active')),
              ButtonSegment(
                value: TodosFilter.completed,
                label: Text('Done'),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (selection) =>
                ref.read(todosFilterProvider.notifier).set(selection.first),
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
            child: switch (todosAsync) {
              AsyncData(:final value) when value.isEmpty =>
                const Center(child: Text('No todos')),
              AsyncData(:final value) => ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final todo = value[index];
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
                      onChanged: (_) =>
                          ref.read(todosProvider.notifier).toggle(todo.id),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            ref.read(todosProvider.notifier).remove(todo.id),
                      ),
                    );
                  },
                ),
              AsyncError(:final error) => Center(child: Text('Error: $error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
