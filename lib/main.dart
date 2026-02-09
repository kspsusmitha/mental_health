import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/realtime_database_service.dart';
import 'services/ai_service.dart';
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

  // Initialize auth service
  final authService = AuthService();
  await authService.initialize();

  // Initialize predefined admin accounts in database
  await authService.initializePredefinedAdmins();

  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => authService),
        Provider<RealtimeDatabaseService>(
          create: (_) => RealtimeDatabaseService(),
        ),
        Provider<AIService>(create: (_) => AIService()),
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
