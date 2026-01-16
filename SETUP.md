# Setup Guide

## Quick Start

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Firebase Setup

#### Option A: Using FlutterFire CLI (Recommended)
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

This will:
- Detect your Firebase projects
- Generate `firebase_options.dart`
- Configure platform-specific files

#### Option B: Manual Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android app:
   - Package name: `com.example.mental_health` (check your `android/app/build.gradle`)
   - Download `google-services.json` → place in `android/app/`
3. Add iOS app:
   - Bundle ID: `com.example.mentalHealth` (check your `ios/Runner/Info.plist`)
   - Download `GoogleService-Info.plist` → place in `ios/Runner/`
4. Enable Authentication:
   - Go to Authentication → Sign-in method
   - Enable Email/Password
5. Create Firestore Database:
   - Go to Firestore Database
   - Create database in test mode (for development)
   - Set up security rules (see below)

### 3. Firestore Security Rules

Add these rules in Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
    }
    
    // Messages collection
    match /messages/{messageId} {
      allow read, write: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
    }
    
    // Journal entries
    match /journal_entries/{entryId} {
      allow read, write: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
    }
    
    // Appointments
    match /appointments/{appointmentId} {
      allow read: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.therapistId == request.auth.uid);
      allow create: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.therapistId == request.auth.uid);
    }
    
    // Therapists
    match /therapists/{therapistId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userType == 'therapist';
    }
    
    // Wellness resources
    match /wellness_resources/{resourceId} {
      allow read: if request.auth != null && resource.data.isApproved == true;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userType == 'admin';
    }
    
    // Emotion analysis
    match /emotion_analysis/{analysisId} {
      allow read, write: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
    }
  }
}
```

### 4. Update main.dart

After running `flutterfire configure`, update `lib/main.dart`:

```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### 5. Run the App

```bash
flutter run
```

## Testing the App

### Create Test Users

1. **Regular User:**
   - Register with email/password
   - User Type: User

2. **Therapist:**
   - Register with email/password
   - User Type: Therapist
   - Manually update user document in Firestore to set `isVerified: true`

3. **Admin:**
   - Register with email/password
   - Manually update user document in Firestore to set `userType: 'admin'`

### Test Features

1. **AI Chatbot:**
   - Send messages to test AI responses
   - Check emotion analysis in Firestore

2. **Journal:**
   - Create journal entries
   - View mood trends

3. **Wellness Resources:**
   - Add resources via Admin panel (after implementing)
   - View approved resources

4. **Therapist Booking:**
   - Create therapist profiles
   - Book appointments
   - View appointment list

## Troubleshooting

### Firebase Not Initialized
- Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in place
- Run `flutterfire configure` if not done already
- Check Firebase project settings

### API Errors
- Verify Gemini API key is correct
- Check internet connection
- Review API quota limits

### Build Errors
- Run `flutter clean`
- Run `flutter pub get`
- Check Flutter version compatibility

## Production Checklist

- [ ] Move API keys to environment variables
- [ ] Update Firestore security rules for production
- [ ] Enable Firebase App Check
- [ ] Set up proper error logging
- [ ] Configure analytics
- [ ] Test on both iOS and Android
- [ ] Set up CI/CD pipeline
- [ ] Review and update privacy policy

