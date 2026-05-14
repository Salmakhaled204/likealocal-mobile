import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:likealocal_mobile/main.dart';

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('LikeALocal'), findsOneWidget);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
  });
}
