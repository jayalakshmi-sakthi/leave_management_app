import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leave_management_app/main.dart';

void main() {
  testWidgets('Splash screen shows branding', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const LeaveXApp());

    // Verify app name
    expect(find.text('LeaveX'), findsOneWidget);

    // Verify updated tagline (matches splash screen UI)
    expect(find.text('Work • Balance • Progress'), findsOneWidget);

    // Verify loader is visible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
