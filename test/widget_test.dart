import 'package:flutter_test/flutter_test.dart';
import 'package:mental_health/services/auth_service.dart';
import 'package:mental_health/services/mental_health_api_service.dart';
import 'package:mental_health/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    final apiService = MentalHealthApiService();
    final authService = AuthService(apiService: apiService);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MyApp(authService: authService, apiService: apiService),
    );

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });
}
