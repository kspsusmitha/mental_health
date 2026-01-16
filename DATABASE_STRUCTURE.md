# Database Structure - Separate Nodes for Users, Therapists, and Admins

## Overview
The application now stores users, therapists, and admins in **separate nodes** in Firebase Realtime Database for better organization and data separation.

## Database Structure

```
Realtime Database:
├── users/
│   └── {userId}/
│       ├── id: string
│       ├── email: string
│       ├── name: string
│       ├── userType: "user"
│       ├── createdAt: timestamp
│       ├── profileImageUrl: string (optional)
│       └── additionalInfo: object (optional)
│
├── therapists/
│   └── {therapistId}/
│       ├── id: string
│       ├── email: string
│       ├── name: string
│       ├── userType: "therapist"
│       ├── createdAt: timestamp
│       ├── profileImageUrl: string (optional)
│       ├── specializations: array (optional)
│       ├── isVerified: boolean (optional)
│       └── additionalInfo: object (optional)
│
├── admins/
│   └── {adminId}/
│       ├── id: string
│       ├── email: string
│       ├── name: string
│       ├── userType: "admin"
│       ├── createdAt: timestamp
│       ├── profileImageUrl: string (optional)
│       └── additionalInfo: object (optional)
│
└── auth/
    └── {userId}/
        ├── email: string (lowercase)
        ├── passwordHash: string (SHA256)
        ├── userType: string (user/therapist/admin)
        └── createdAt: timestamp
```

## How It Works

### Registration
- **User Registration**: Saves to `users/{userId}`
- **Therapist Registration**: Saves to `therapists/{therapistId}`
- **Admin Registration**: Saves to `admins/{adminId}`
- All authentication data (password hash) is stored in `auth/{userId}`

### Login
- When a user selects a module (User/Therapist/Admin), the system checks **only** the corresponding node:
  - User module → checks `users/` node
  - Therapist module → checks `therapists/` node
  - Admin module → checks `admins/` node
- If no module is selected, it checks all nodes

### Data Retrieval
- `getUserData(userId, userType)` - Checks the specific node based on userType
- `getUserByEmail(email, userType)` - Searches in the specific node if userType is provided
- If userType is not provided, searches all nodes

## Benefits

1. **Better Organization**: Clear separation of different user types
2. **Performance**: Faster queries when searching specific user types
3. **Security**: Easier to set different security rules for each node
4. **Scalability**: Easier to manage and scale each user type separately
5. **Data Integrity**: Prevents mixing different user types in the same collection

## Code Changes

### AuthService Updates
- `registerWithEmailPassword()` - Saves to appropriate node based on `userType`
- `signInWithEmailPassword()` - Checks specific node if `selectedUserType` is provided
- `getUserData()` - Accepts optional `userType` parameter to check specific node
- `getUserByEmail()` - Accepts optional `userType` parameter
- `updateUserData()` - Updates in the correct node based on `user.userType`

### Login Screen
- Passes `selectedUserType` to `signInWithEmailPassword()` to check the correct node

### Profile Screens
- Updated to pass `userType` when calling `getUserData()`

## Migration Notes

- Existing users in the `users/` node will need to be migrated if they are therapists or admins
- New registrations automatically go to the correct node
- Login checks the correct node based on selected module

## Security Rules Example

```json
{
  "rules": {
    "users": {
      ".read": true,
      ".write": true
    },
    "therapists": {
      ".read": true,
      ".write": "root.child('admins').child(auth.uid).exists() || newData.child('userType').val() === 'therapist'"
    },
    "admins": {
      ".read": "root.child('admins').child(auth.uid).exists()",
      ".write": "root.child('admins').child(auth.uid).exists()"
    },
    "auth": {
      ".read": false,
      ".write": false
    }
  }
}
```

