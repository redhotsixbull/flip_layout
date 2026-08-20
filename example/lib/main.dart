import 'package:flutter/material.dart';
import 'package:flip_layout/flip_layout.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Deep-link a single tab via ?demo=filter|reorder|addremove (for docs
    // screenshots). Falls back to the tabbed demo.
    final demo = Uri.base.queryParameters['demo'];
    const order = ['filter', 'reorder', 'addremove'];
    final initial = order.indexOf(demo ?? '');

    return MaterialApp(
      title: 'flip_layout example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: DemoPage(initialTab: initial < 0 ? 0 : initial),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flip_layout'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.filter_alt), text: 'Filter'),
            Tab(icon: Icon(Icons.shuffle), text: 'Reorder'),
            Tab(icon: Icon(Icons.playlist_add), text: 'Add / remove'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FilterDemo(),
          _ReorderDemo(),
          _AddRemoveDemo(),
        ],
      ),
    );
  }
}

// -- 1. Filter demo (the flagship: a Wrap that Material can't animate) --------

class _FilterDemo extends StatefulWidget {
  const _FilterDemo();

  @override
  State<_FilterDemo> createState() => _FilterDemoState();
}

class _FilterDemoState extends State<_FilterDemo> {
  static const _allTags = [
    'dart', 'flutter', 'riverpod', 'bloc', 'hooks', 'test',
    'canvas', 'gesture', 'router', 'query', 'floating', 'motion',
    'anim', 'physics', 'sliver', 'render', 'layout', 'overlay',
  ];
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final visible = _allTags.where((t) => t.contains(_filter)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Filter tags — try "an", "flu", "re"',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: MotionGroup(
              duration: const Duration(milliseconds: 260),
              children: [
                for (final t in visible)
                  Chip(
                    key: ValueKey(t),
                    label: Text(t),
                    backgroundColor: Colors.deepOrange.shade100,
                  ),
              ],
              builder: (context, children) =>
                  Wrap(spacing: 8, runSpacing: 8, children: children),
            ),
          ),
        ),
      ],
    );
  }
}

// -- 2. Reorder demo (layout FLIP + staggered reveal) ------------------------

class _ReorderDemo extends StatefulWidget {
  const _ReorderDemo();

  @override
  State<_ReorderDemo> createState() => _ReorderDemoState();
}

class _ReorderDemoState extends State<_ReorderDemo> {
  List<int> _items = List.generate(12, (i) => i + 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.shuffle),
                label: const Text('Shuffle'),
                onPressed: () => setState(() => _items = [..._items]..shuffle()),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () =>
                    setState(() => _items = _items.reversed.toList()),
                child: const Text('Reverse'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: MotionGroup(
              duration: const Duration(milliseconds: 520),
              curve: SpringCurve(stiffness: 220, damping: 14), // springy slide
              stagger: const Duration(milliseconds: 25),
              children: [
                for (final i in _items)
                  _Bubble(key: ValueKey(i), label: '$i'),
              ],
              builder: (context, children) =>
                  Wrap(spacing: 10, runSpacing: 10, children: children),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer)),
    );
  }
}

// -- 3. Add / remove demo (declarative enter/exit in a Column) ---------------

class _AddRemoveDemo extends StatefulWidget {
  const _AddRemoveDemo();

  @override
  State<_AddRemoveDemo> createState() => _AddRemoveDemoState();
}

class _AddRemoveDemoState extends State<_AddRemoveDemo> {
  final List<int> _items = [1, 2, 3];
  int _next = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
              onPressed: () => setState(() => _items.insert(0, _next++)),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MotionGroup(
              duration: const Duration(milliseconds: 280),
              children: [
                for (final i in _items)
                  Card(
                    key: ValueKey(i),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('$i')),
                      title: Text('Item $i'),
                      subtitle: const Text('Delete me — I fade out, the rest slide up.'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _items.remove(i)),
                      ),
                    ),
                  ),
              ],
              builder: (context, children) => Column(children: children),
            ),
          ),
        ),
      ],
    );
  }
}
