# AI-Powered Mental Health & Wellness Support System

A comprehensive Flutter application that provides 24/7 mental health assistance through AI-powered chatbot, emotional analysis, wellness resources, therapist connectivity, and administrative supervision.

## Features

### 🤖 AI Chatbot
- Natural Language Processing (NLP) powered by Google Gemini Flash Lite
- Real-time emotional analysis of conversations
- Personalized coping strategies and wellness suggestions
- Risk level detection and early intervention alerts

### 📔 Well-Being Journal
- Daily emotion and thought recording
- Mood tracking with AI-powered analysis
- Stress trigger identification
- Emotional trend visualization

### 🧘 Wellness Resources
- Guided meditation sessions
- Wellness videos and audio content
- Admin-approved content library
- Personalized recommendations based on emotional state

### 👨‍⚕️ Therapist Module
- Therapist matching based on age group and concerns
- Appointment booking (text, audio, video sessions)
- Session management and progress tracking
- Verified therapist profiles

### 📊 Mood Analytics
- AI-based mood prediction
- Emotion trend charts
- Risk factor analysis
- Historical data visualization

### 👤 Admin Module
- User management
- Therapist verification
- Content approval and moderation
- Platform analytics

## Tech Stack

- **Frontend**: Flutter (Cross-platform)
- **Backend**: Firebase (Firestore, Authentication, Storage)
- **AI**: Google Gemini Flash Lite API
- **State Management**: Provider
- **Charts**: FL Chart

## Setup Instructions

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Firebase project configured
- Google Gemini API key

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mental_health
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add your app to the Firebase project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate directories:
     - Android: `android/app/google-services.json`
     - iOS: `ios/Runner/GoogleService-Info.plist`
   - Install Firebase CLI and run:
     ```bash
     flutterfire configure
     ```

4. **Configure Gemini API**
   - The API key is already configured in `lib/services/ai_service.dart`
   - API Key: `AIzaSyChcxUCymMoKzf9ckJNJMRgw_oAlTPnYCs`
   - Model: `gemini-flash-lite-latest`

5. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── models/              # Data models
│   ├── user_model.dart
│   ├── message_model.dart
│   ├── journal_entry_model.dart
│   ├── therapist_model.dart
│   ├── appointment_model.dart
│   ├── wellness_resource_model.dart
│   └── emotion_analysis_model.dart
├── services/            # Business logic
│   ├── ai_service.dart
│   ├── auth_service.dart
│   └── firestore_service.dart
├── screens/             # UI screens
│   ├── auth/
│   ├── home/
│   ├── chat/
│   ├── journal/
│   ├── wellness/
│   ├── therapist/
│   ├── admin/
│   └── analytics/
└── main.dart            # App entry point
```

## Firebase Collections

The app uses the following Firestore collections:
- `users` - User profiles
- `messages` - Chat messages
- `journal_entries` - Journal entries
- `appointments` - Therapy appointments
- `therapists` - Therapist profiles
- `wellness_resources` - Wellness content
- `emotion_analysis` - Emotional analysis data

## User Types

1. **User** - Regular users seeking mental health support
2. **Therapist** - Verified mental health professionals
3. **Admin** - Platform administrators

## Key Features Implementation

### AI Service
- Uses Gemini Flash Lite for natural language understanding
- Analyzes emotions from text input
- Provides mood predictions based on historical data
- Generates personalized wellness recommendations

### Authentication
- Email/password authentication via Firebase Auth
- User type-based access control
- Secure session management

### Real-time Updates
- Firestore streams for live data updates
- Real-time chat functionality
- Live appointment status updates

## Security Considerations

- All user data is stored securely in Firebase
- API keys should be moved to environment variables in production
- Therapist verification required before access
- Admin-only content approval workflow

## Future Enhancements

- [ ] Video/audio call integration for therapy sessions
- [ ] Push notifications for appointments
- [ ] Community support groups
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] Offline mode support

## License

This project is for educational purposes.

## Support

For issues and questions, please open an issue in the repository.
