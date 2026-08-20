import 'package:flutter/material.dart';
import 'package:flip_layout/flip_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the translation of the nearest [Transform] ancestor of [label].
Offset _translateOf(WidgetTester tester, String label) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byType(Transform),
        )
        .first,
  );
  final t = transform.transform.getTranslation();
  return Offset(t.x, t.y);
}

void main() {
  testWidgets('LayoutMotion renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LayoutMotion(child: Text('hello'))),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('reorder slides the moved child (FLIP inverse then settle)',
      (tester) async {
    var order = [1, 2, 3];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  for (final i in order)
                    LayoutMotion(
                      key: ValueKey(i),
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(height: 60, child: Text('item $i')),
                    ),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => order = order.reversed.toList()),
                    child: const Text('reverse'),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump(); // establish initial bounds

    // At rest, no translation.
    expect(_translateOf(tester, 'item 1').distance, lessThan(0.01));

    await tester.tap(find.text('reverse'));
    await tester.pump(); // rebuild new order + post-frame measurement → forward
    await tester.pump(const Duration(milliseconds: 40)); // mid-animation

    // item 1 moved from top to bottom → mid-flight it is offset (inverted).
    expect(_translateOf(tester, 'item 1').distance, greaterThan(1.0),
        reason: 'moved child should be mid-slide, not snapped');

    await tester.pumpAndSettle();
    expect(_translateOf(tester, 'item 1').distance, lessThan(0.01),
        reason: 'settles exactly back to identity');
  });

  testWidgets('scrolling does NOT trigger a spurious slide', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                for (var i = 0; i < 20; i++)
                  LayoutMotion(
                    key: ValueKey('row-$i'),
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(height: 60, child: Text('row $i')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.jumpTo(120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // A visible row must not be animating just because the page scrolled.
    expect(_translateOf(tester, 'row 3').distance, lessThan(0.01),
        reason: 'scrolling is measured in content space → no FLIP');

    controller.dispose();
  });

  testWidgets('AnimatedLayout wraps children with LayoutMotion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedLayout(
            builder: (context, wrap) => Column(
              children: [
                wrap(const Text('a', key: ValueKey('a'))),
                wrap(const Text('b', key: ValueKey('b'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.byType(LayoutMotion), findsNWidgets(2));
  });

  testWidgets('AnimatedLayout asserts children carry a key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedLayout(
            builder: (context, wrap) => Column(
              children: [wrap(const Text('no-key'))],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('onEnd fires once when a slide completes', (tester) async {
    var ended = 0;
    var order = [1, 2];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  for (final i in order)
                    LayoutMotion(
                      key: ValueKey(i),
                      duration: const Duration(milliseconds: 100),
                      onEnd: () => ended++,
                      child: SizedBox(height: 60, child: Text('n$i')),
                    ),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => order = order.reversed.toList()),
                    child: const Text('swap'),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.tap(find.text('swap'));
    await tester.pumpAndSettle();

    expect(ended, greaterThan(0));
  });
}
