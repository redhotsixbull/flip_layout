import 'package:flutter/material.dart';
import 'package:flip_layout/flip_layout.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flip_layout example',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
            Tab(icon: Icon(Icons.shuffle), text: 'Reorder'),
            Tab(icon: Icon(Icons.filter_alt), text: 'Filter'),
            Tab(icon: Icon(Icons.expand), text: 'Expand'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ReorderDemo(),
          _FilterDemo(),
          _ExpandDemo(),
        ],
      ),
    );
  }
}

// -- 1. Reorder demo ---------------------------------------------------------

class _ReorderDemo extends StatefulWidget {
  const _ReorderDemo();

  @override
  State<_ReorderDemo> createState() => _ReorderDemoState();
}

class _ReorderDemoState extends State<_ReorderDemo> {
  List<int> _items = List.generate(8, (i) => i + 1);

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
            child: Column(
              children: [
                for (final i in _items)
                  LayoutMotion(
                    key: ValueKey('item-$i'),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('$i')),
                        title: Text('Card $i'),
                        subtitle: const Text('Drag the shuffle to see me slide.'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -- 2. Filter demo ----------------------------------------------------------

class _FilterDemo extends StatefulWidget {
  const _FilterDemo();

  @override
  State<_FilterDemo> createState() => _FilterDemoState();
}

class _FilterDemoState extends State<_FilterDemo> {
  static const _allTags = [
    'dart', 'flutter', 'riverpod', 'bloc', 'hooks', 'test',
    'canvas', 'gesture', 'router', 'query', 'floating', 'motion',
    'anim', 'physics', 'sliver', 'render',
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
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Filter tags (try "an" or "flu")',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in visible)
                  LayoutMotion(
                    key: ValueKey('tag-$t'),
                    duration: const Duration(milliseconds: 250),
                    child: Chip(
                      label: Text(t),
                      backgroundColor: Colors.deepOrange.shade100,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -- 3. Expand demo ----------------------------------------------------------

class _ExpandDemo extends StatefulWidget {
  const _ExpandDemo();

  @override
  State<_ExpandDemo> createState() => _ExpandDemoState();
}

class _ExpandDemoState extends State<_ExpandDemo> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (context, i) {
        final isOpen = _expanded == i;
        return LayoutMotion(
          key: ValueKey('exp-$i'),
          duration: const Duration(milliseconds: 300),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _expanded = isOpen ? null : i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(16),
                height: isOpen ? 160 : 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card $i', style: Theme.of(context).textTheme.titleMedium),
                    if (isOpen) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'When this card expands, its siblings slide to make room '
                        '— and LayoutMotion animates the slide automatically.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
