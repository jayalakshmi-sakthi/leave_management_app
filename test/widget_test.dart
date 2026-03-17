import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leave_management_app/main.dart';
import 'package:leave_management_app/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows branding', (WidgetTester tester) async {
    // Build the splash screen directly to avoid Firebase dependency in LeaveXApp
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(),
    ));

    // Wait for everything to settle
    await tester.pump();

    // Verify app name
    expect(find.text('LeaveX'), findsOneWidget);

    // Verify updated tagline (matches splash screen UI)
    expect(find.text('Work • Balance • Progress'), findsOneWidget);

    // Verify loader is visible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
