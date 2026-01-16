# Duplicate Screens Report

## Summary
This document lists duplicate screens found in the project and recommends which ones to keep.

## Duplicate Screens Found

### 1. Journal Screen
- **Location 1:** `lib/modules/user/screens/journal_screen.dart` ✅ **KEEP** (Uses Realtime Database)
- **Location 2:** `lib/screens/journal/journal_screen.dart` ❌ **REMOVE** (Uses MockFirestoreService)

**Recommendation:** Keep the module version as it's integrated with Realtime Database and is actively used.

### 2. Wellness Screen
- **Location 1:** `lib/modules/user/screens/wellness_screen.dart` ✅ **KEEP** (Uses Realtime Database)
- **Location 2:** `lib/screens/wellness/wellness_screen.dart` ❌ **REMOVE** (Uses MockFirestoreService)

**Recommendation:** Keep the module version as it's integrated with Realtime Database and is actively used.

### 3. Chat Screen
- **Location 1:** `lib/modules/user/screens/ai_chat_screen.dart` ✅ **KEEP** (Uses Realtime Database)
- **Location 2:** `lib/screens/chat/chat_screen.dart` ❌ **REMOVE** (Uses MockFirestoreService)

**Recommendation:** Keep the module version (`ai_chat_screen.dart`) as it's integrated with Realtime Database.

## Other Screens in `lib/screens` Folder

These screens appear to be legacy/demo screens that use MockAuthService and MockFirestoreService:

- `lib/screens/home/home_screen.dart` - Uses MockAuthService
- `lib/screens/admin/admin_screen.dart` - Legacy admin screen
- `lib/screens/therapist/therapist_screen.dart` - Legacy therapist screen
- `lib/screens/analytics/mood_analytics_screen.dart` - Uses MockFirestoreService

**Recommendation:** These can be kept for reference but are not actively used. The main application uses the module-based structure in `lib/modules`.

## Active Screens (Keep)

✅ `lib/screens/splash/splash_screen.dart` - Entry point
✅ `lib/screens/auth/login_screen.dart` - Authentication
✅ `lib/screens/auth/register_screen.dart` - Registration
✅ `lib/screens/auth/module_selection_screen.dart` - NEW: Module selection

## Action Items

1. ✅ Created `module_selection_screen.dart` - Module selection after splash
2. ✅ Updated splash screen to navigate to module selection
3. ✅ Updated login/register screens to accept `selectedUserType` parameter
4. ⚠️ Consider removing duplicate screens in `lib/screens` folder (optional cleanup)

