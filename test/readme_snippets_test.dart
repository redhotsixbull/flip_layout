// Compile-check for the Dart snippets in README.md / doc/API.md.
// Nothing here asserts animation behaviour — that's `flip_layout_test.dart`.
// The point is that every API the docs show actually exists with the shown
// name, arity and types. If a snippet is edited, edit it here too.
//
// Snippets that trail off with `...` inside a constructor call are shown here
// with the required arguments filled in; everything else is verbatim.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flip_layout/flip_layout.dart';

class _Item {
  const _Item(this.id);
  final Object id;
}

Widget _thumb(_Item item) => SizedBox(key: ValueKey(item.id), height: 40);
Widget _bigCard(_Item item) => SizedBox(key: ValueKey(item.id), height: 200);

/// README "Shared-element magic move" — the layered grid → detail pattern,
/// with the `selected` / `setState` scaffolding a snippet can't show.
class _SharedPage extends StatefulWidget {
  const _SharedPage();
  @override
  State<_SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<_SharedPage> {
  static const items = [_Item('a'), _Item('b')];
  _Item? selected;

  @override
  Widget build(BuildContext context) => MotionSharedScope(
        // keep the grid mounted and LAYER the detail on top → scroll/state
        // preserved, and the element flies back to its tile automatically.
        child: Stack(children: [
          GridView(
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
            children: [
              for (final item in items)
                GestureDetector(
                  onTap: () => setState(() => selected = item),
                  child: MotionSharedId(id: item.id, child: _thumb(item)),
                ),
            ],
          ),
          if (selected != null)
            Center(
              child: MotionSharedId(
                id: selected!.id,
                child: _bigCard(selected!),
              ),
            ),
        ]),
      );
}

void main() {
  const visibleTags = ['a', 'b'];

  testWidgets('README: MotionGroup — the main event', (tester) async {
    // Scaffold only so `Chip` finds its required Material ancestor.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MotionGroup(
          // adding/removing/reordering these just works
          children: [
            for (final tag in visibleTags)
              Chip(key: ValueKey(tag), label: Text(tag)),
          ],
          builder: (context, children) => Wrap(spacing: 8, children: children),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNWidgets(2));
  });

  testWidgets('README: shared-element scope, layered pattern', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _SharedPage()));
    await tester.pumpAndSettle();
    expect(find.byType(MotionSharedId), findsNWidgets(2));
  });

  testWidgets('README: crossFade / flightShuttleBuilder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MotionSharedScope(
        crossFade: true, // built-in source→destination dissolve
        // …or take full control:
        flightShuttleBuilder: (context, animation, fromChild, toChild) =>
            FadeTransition(opacity: animation, child: toChild),
        child: const SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('README: MotionConfig defaults', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MotionConfig(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        // reduceMotion: null → follows the OS "reduce motion" setting
        child: SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('README: SpringCurve and MotionSpring on MotionGroup',
      (tester) async {
    Widget group({Curve? curve, MotionSpring? spring}) => MotionGroup(
          duration: const Duration(milliseconds: 520),
          curve: curve,
          spring: spring,
          children: const [SizedBox(key: ValueKey('x'))],
          builder: (context, children) => Column(children: children),
        );

    await tester.pumpWidget(MaterialApp(
      home: Column(children: [
        group(curve: SpringCurve(stiffness: 220, damping: 14)),
        group(spring: const MotionSpring(stiffness: 220, damping: 16)),
        // MotionSpring.gentle / MotionSpring.bouncy are ready-made presets
        group(spring: MotionSpring.gentle),
        group(spring: MotionSpring.bouncy),
      ]),
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('README: LayoutMotion for a single widget', (tester) async {
    const id = 1;
    await tester.pumpWidget(const MaterialApp(
      home: LayoutMotion(
        key: ValueKey(id),
        child: Card(child: ListTile(title: Text('Item $id'))),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('doc/API.md: every documented constructor argument',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MotionConfig(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        stagger: const Duration(milliseconds: 20),
        spring: const MotionSpring(mass: 1, stiffness: 180, damping: 20),
        reduceMotion: false,
        child: Column(children: [
          MotionGroup(
            builder: (context, children) => Column(children: children),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            spring: MotionSpring.gentle,
            stagger: const Duration(milliseconds: 20),
            exitStagger: const Duration(milliseconds: 20),
            animateInitial: true,
            transitionBuilder: (context, animation, child) =>
                FadeTransition(opacity: animation, child: child),
            exitTransitionBuilder: (context, animation, child) =>
                FadeTransition(opacity: animation, child: child),
            onEnter: (key) {},
            onExitComplete: (key) {},
            children: const [SizedBox(key: ValueKey('k'))],
          ),
          LayoutMotion(
            key: const ValueKey('lm'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            spring: MotionSpring.bouncy,
            animateSize: false,
            onEnd: () {},
            child: const SizedBox(),
          ),
          AnimatedLayout(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            animateSize: false,
            builder: (context, wrap) =>
                Column(children: [wrap(const SizedBox(key: ValueKey('al')))]),
          ),
          MotionSharedScope(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            crossFade: false,
            child: MotionSharedId(
              id: 'shared',
              child: const SizedBox(),
            ),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    // Debug-only knob documented in doc/API.md.
    expect(MotionGroup.debugChildCountWarningThreshold, isA<int?>());
    // SpringCurve's documented constructor arguments.
    expect(SpringCurve(mass: 1.0, stiffness: 180.0, damping: 12.0),
        isA<Curve>());
  });
}
