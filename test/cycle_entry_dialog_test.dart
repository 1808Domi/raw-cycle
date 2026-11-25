import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raw_cycle/widgets/cycle_entry_dialog.dart';

void main() {
  testWidgets('only shows bleeding intensity for period days', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CycleEntryDialog())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blutungsstärke'), findsNothing);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Blutungsstärke'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Blutungsstärke'), findsNothing);
  });

  testWidgets('shows optional cycle observation fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CycleEntryDialog())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zervixschleim (optional)'), findsOneWidget);
    expect(find.text('Stimmung (optional)'), findsOneWidget);
    expect(find.text('Energielevel (optional)'), findsOneWidget);
    expect(find.text('Schlafdauer (optional)'), findsOneWidget);
  });
}
