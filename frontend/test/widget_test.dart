import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:demandtwin_mobile/main.dart';

void main() {
  testWidgets('DemandTwin app shows its title', (WidgetTester tester) async {
    await tester.pumpWidget(const DemandTwinApp());

    expect(find.text('DemandTwin AI'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
