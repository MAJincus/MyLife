// Test de fumée basique pour MyLife.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('L\'app se construit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('MyLife'))),
    );
    expect(find.text('MyLife'), findsOneWidget);
  });
}
