import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Helper class for Firebase initialization
/// 
/// To use this, you need to:
/// 1. Run `flutterfire configure` in your terminal
/// 2. This will generate `firebase_options.dart` file
/// 3. Import and use it in main.dart
class FirebaseHelper {
  static Future<void> initialize() async {
    try {
      // Uncomment and use after running flutterfire configure
      // await Firebase.initializeApp(
      //   options: DefaultFirebaseOptions.currentPlatform,
      // );
      
      // For now, using basic initialization
      await Firebase.initializeApp();
      
      if (kDebugMode) {
        print('Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Firebase initialization error: $e');
        print('Please run: flutterfire configure');
      }
      rethrow;
    }
  }
}

