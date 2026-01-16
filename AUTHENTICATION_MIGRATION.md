# Authentication Migration to Realtime Database

## Summary
The application has been migrated from Firebase Authentication to use **only Firebase Realtime Database** for authentication.

## Changes Made

### 1. AuthService (`lib/services/auth_service.dart`)
- ✅ Removed Firebase Auth dependency
- ✅ Implemented custom authentication using Realtime Database
- ✅ Password hashing using SHA256 (via `crypto` package)
- ✅ User session management using SharedPreferences
- ✅ Email-based user lookup

### 2. Database Structure

#### Users Storage
```
users/
  {userId}/
    id: string
    email: string
    name: string
    userType: string (user/therapist/admin)
    createdAt: timestamp
    profileImageUrl: string (optional)
    additionalInfo: object (optional)
```

#### Authentication Storage
```
auth/
  {userId}/
    email: string (lowercase)
    passwordHash: string (SHA256 hash)
    createdAt: timestamp
```

### 3. Updated Files
- ✅ `lib/main.dart` - Initialize AuthService on app start
- ✅ `lib/screens/splash/splash_screen.dart` - Use UserModel instead of Firebase User
- ✅ All module screens - Changed `.uid` to `.id`
- ✅ `pubspec.yaml` - Added `crypto` package, removed `firebase_auth` dependency

### 4. Authentication Flow

#### Registration:
1. Check if email already exists in `users/`
2. Generate unique user ID (timestamp-based)
3. Hash password using SHA256
4. Save user data to `users/{userId}`
5. Save auth data (password hash) to `auth/{userId}`
6. Store user ID in SharedPreferences
7. Set current user in AuthService

#### Login:
1. Load all users from `users/`
2. Find user by email (case-insensitive)
3. Load auth data from `auth/{userId}`
4. Compare password hash
5. If match, set current user and save to SharedPreferences
6. Return UserModel

#### Session Management:
- Current user stored in memory (`_currentUser`)
- User ID persisted in SharedPreferences
- On app start, AuthService loads user from SharedPreferences

## Security Notes

⚠️ **Important**: The current implementation uses SHA256 for password hashing. For production:
- Consider using bcrypt or Argon2 for better security
- Implement password strength requirements
- Add rate limiting for login attempts
- Consider adding email verification

## Database Rules (Firebase Realtime Database)

Set up these security rules in Firebase Console:

```json
{
  "rules": {
    "users": {
      "$userId": {
        ".read": "$userId === auth.uid || root.child('users').child(auth.uid).child('userType').val() === 'admin'",
        ".write": "$userId === auth.uid || root.child('users').child(auth.uid).child('userType').val() === 'admin'"
      }
    },
    "auth": {
      "$userId": {
        ".read": false,
        ".write": false
      }
    }
  }
}
```

**Note**: Since we're not using Firebase Auth, you'll need to adjust these rules or use custom authentication tokens. For now, you may need to set rules to allow read/write for development, but restrict in production.

## Testing

1. **Register a new user:**
   - Select module type
   - Fill registration form
   - User data saved to `users/{userId}`
   - Auth data saved to `auth/{userId}`

2. **Login:**
   - Enter email and password
   - System queries `users/` for matching email
   - Verifies password hash from `auth/{userId}`
   - Sets current user session

3. **Session Persistence:**
   - Close and reopen app
   - User should remain logged in (loaded from SharedPreferences)

## Migration Notes

- All existing Firebase Auth code has been removed
- User IDs are now timestamp-based strings instead of Firebase Auth UIDs
- Password reset functionality updated to use Realtime Database
- All `.uid` references changed to `.id` throughout the codebase

