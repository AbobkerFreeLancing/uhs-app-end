import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uohs_student_app/main.dart';
import 'package:uohs_student_app/providers/auth_provider.dart';
import 'package:uohs_student_app/providers/profile_provider.dart';
import 'package:uohs_student_app/providers/finance_provider.dart';
import 'package:uohs_student_app/providers/support_provider.dart';
import 'package:uohs_student_app/providers/guidance_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('UHS Student App smoke test', (WidgetTester tester) async {
    // Build the app with providers and trigger the first frame
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => FinanceProvider()),
          ChangeNotifierProvider(create: (_) => SupportProvider()),
          ChangeNotifierProvider(create: (_) => GuidanceProvider()),
        ],
        child: const UHSStudentApp(isLoggedIn: false),
      ),
    );

    // Allow async microtasks to finish initialization
    await tester.pumpAndSettle();

    // The login screen should show the university name
    expect(find.text('جامعة العلوم الصحية'), findsOneWidget);
  });
}
