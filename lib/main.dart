import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/realtime_database_service.dart';
import 'services/ai_service.dart';
import 'services/mental_health_api_service.dart';
import 'services/mood_prediction_service.dart';
import 'services/recommendation_service.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize WebView platform implementations
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android WebView initialization is handled automatically by the plugin
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    // iOS WebView initialization is handled automatically by the plugin
  }

  // Initialize API service
  final apiService = MentalHealthApiService();

  // Initialize auth service
  final authService = AuthService(apiService: apiService);
  await authService.initialize();

  // Initialize predefined admin accounts in database
  await authService.initializePredefinedAdmins();

  runApp(MyApp(authService: authService, apiService: apiService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final MentalHealthApiService apiService;

  const MyApp({super.key, required this.authService, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RealtimeDatabaseService>(
          create: (_) => RealtimeDatabaseService(),
        ),
        Provider<MentalHealthApiService>.value(value: apiService),
        Provider<AuthService>.value(value: authService),
        ProxyProvider<MentalHealthApiService, AIService>(
          update: (_, api, __) => AIService(apiService: api),
        ),
        ProxyProvider2<AuthService, AIService, MoodPredictionService>(
          update: (_, auth, ai, __) =>
              MoodPredictionService(authService: auth, aiService: ai),
        ),
        ProxyProvider2<AuthService, AIService, RecommendationService>(
          update: (_, auth, ai, __) =>
              RecommendationService(authService: auth, aiService: ai),
        ),
      ],
      child: MaterialApp(
        title: 'MindCare - Mental Health & Wellness',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
