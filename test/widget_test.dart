import 'package:flutter_test/flutter_test.dart';
import 'package:aread/main.dart';

void main() {
  testWidgets('AreadApp shows onboarding on first launch', (WidgetTester tester) async {
    // Real onboarding-flag storage goes through sqflite, which deadlocks
    // inside flutter_test's fake-async zone (the DB tests avoid this by
    // using plain test() instead of testWidgets()) - so inject a fast stub
    // instead of touching the real database here.
    await tester.pumpWidget(AreadApp(checkOnboardingComplete: () async => false));
    await tester.pump();
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('AreadApp skips onboarding once it has been completed', (WidgetTester tester) async {
    await tester.pumpWidget(AreadApp(checkOnboardingComplete: () async => true));
    await tester.pump();
    expect(find.text('Get Started'), findsNothing);
  });
}
