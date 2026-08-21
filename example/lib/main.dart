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
    const order = ['filter', 'reorder', 'addremove', 'shared'];
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
    _tab = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.filter_alt), text: 'Filter'),
            Tab(icon: Icon(Icons.shuffle), text: 'Reorder'),
            Tab(icon: Icon(Icons.playlist_add), text: 'Add / remove'),
            Tab(icon: Icon(Icons.open_in_full), text: 'Shared'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FilterDemo(),
          _ReorderDemo(),
          _AddRemoveDemo(),
          _SharedDemo(),
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
              // Velocity-preserving physics: shuffle mid-slide and the bubbles
              // carry momentum into the new target instead of restarting.
              spring: const MotionSpring(stiffness: 220, damping: 16),
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

// -- 4. Shared element demo (magic move, no route change) --------------------

class _SharedDemo extends StatefulWidget {
  const _SharedDemo();

  @override
  State<_SharedDemo> createState() => _SharedDemoState();
}

class _SharedDemoState extends State<_SharedDemo> {
  int? _selected;

  static const _colors = [
    Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835),
    Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA),
    Color(0xFF00ACC1), Color(0xFFF4511E), Color(0xFF6D4C41),
  ];

  Widget _tile(int i, {double radius = 16, bool detail = false}) => Container(
        decoration: BoxDecoration(
          color: _colors[i % _colors.length],
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                // Extra copy that only the detail shows — the cross-fade
                // dissolves the plain tile into this richer card in flight.
                if (detail)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Detail',
                        style: TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Keep the grid mounted and LAYER the detail on top (don't replace it), so
    // the grid's scroll position and state are preserved — and the shared
    // element flies back to its tile automatically on close.
    return MotionSharedScope(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      // Dissolve the plain grid tile into the richer detail card during flight
      // (and back) instead of carrying only the destination child.
      crossFade: true,
      child: Stack(
        children: [
          _grid(),
          if (_selected != null) _detail(_selected!),
        ],
      ),
    );
  }

  Widget _grid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tap a tile — it flies to the detail view (same page, no route).',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (var i = 0; i < 18; i++) // enough to scroll
                  GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: MotionSharedId(id: i, child: _tile(i)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(int i) {
    return GestureDetector(
      onTap: () => setState(() => _selected = null),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xCC000000))),
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: MotionSharedId(id: i, child: _tile(i, radius: 28, detail: true)),
            ),
          ),
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Text('Tap anywhere to go back',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _AddRemoveDemo extends StatefulWidget {
  const _AddRemoveDemo();

  @override
  State<_AddRemoveDemo> createState() => _AddRemoveDemoState();
}

class _AddRemoveDemoState extends State<_AddRemoveDemo> {
  final List<int> _items = [1, 2, 3];
  int _next = 4;
  String _status = 'Add, remove, or clear — watch the lifecycle callbacks.';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
                onPressed: () => setState(() => _items.insert(0, _next++)),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
                // Removing them all at once shows the staggered exit.
                onPressed: _items.isEmpty
                    ? null
                    : () => setState(_items.clear),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_status,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MotionGroup(
              duration: const Duration(milliseconds: 280),
              // Stagger the exit so a "Clear" cascades instead of vanishing.
              exitStagger: const Duration(milliseconds: 90),
              onEnter: (key) => setState(
                  () => _status = 'Entered ${(key as ValueKey).value}'),
              onExitComplete: (key) => setState(
                  () => _status = 'Removed ${(key as ValueKey).value}'),
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
