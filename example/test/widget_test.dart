import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('ExampleApp builds', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('flip_layout'), findsOneWidget);
  });
}
