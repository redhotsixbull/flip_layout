import 'package:flutter/material.dart';
import 'package:flip_layout/flip_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LayoutMotion renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LayoutMotion(child: Text('hello')),
        ),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('LayoutMotion survives a reorder', (tester) async {
    var order = [1, 2, 3];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  ...order.map((i) => LayoutMotion(
                        key: ValueKey(i),
                        duration: const Duration(milliseconds: 100),
                        child: SizedBox(height: 40, child: Text('item $i')),
                      )),
                  ElevatedButton(
                    onPressed: () => setState(() => order = order.reversed.toList()),
                    child: const Text('reverse'),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.tap(find.text('reverse'));
    await tester.pumpAndSettle();

    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget);
    expect(find.text('item 3'), findsOneWidget);
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
}
