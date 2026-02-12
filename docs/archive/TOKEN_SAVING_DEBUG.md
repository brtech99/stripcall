# FCM Token Saving Debug Summary

## Issue
FCM tokens are being generated but not saved to the database, causing notifications to fail with "No device tokens found for the specified users".

## Root Cause Analysis

### 1. **Timing Issue Identified**
- Notification service initializes in `main()` before user authentication
- FCM token is generated but user is not authenticated yet
- `_saveTokenToDatabase()` fails because `currentUser` is null

### 2. **Debug Logging Added**
Added comprehensive debug logging to track:
- FCM token generation
- User authentication state
- Database save attempts
- Auth state changes

### 3. **Auth State Listener Added**
- Added listener for `SIGNED_IN` events
- Token is now saved when user logs in
- Prevents timing issues

## Changes Made

### 1. **Enhanced NotificationService**
```dart
// Added auth state listener
_supabase.auth.onAuthStateChange.listen((event) {
  if (event.event == 'SIGNED_IN' && _fcmToken != null) {
    print('DEBUG: User signed in, saving FCM token...');
    _saveTokenToDatabase(_fcmToken!);
  }
});
```

### 2. **Debug Logging**
- Added debug prints to `_saveTokenToDatabase()`
- Added debug prints to `sendNotification()`
- Added user ID logging during initialization

### 3. **Database Test Method**
```dart
Future<void> testDatabaseConnection() async {
  // Tests if device_tokens table exists
  // Checks current user authentication
  // Lists user's existing tokens
}
```

### 4. **Settings Menu Enhancement**
- Added "Test Database" option
- Allows manual testing of database connection
- Shows table structure and user tokens

## Testing Steps

### 1. **Run the App**
```bash
./run_app.sh
```

### 2. **Check Initialization Logs**
Look for:
```
DEBUG: FCM Token: eqz8wKYuyECujbgOUPU4Ie:APA91bH0vgozygM1hhFSwmNPO97fwX43BeSMJs70AeBS2eFI5YWc1wHJaQUT7dsNgdnjjRFIMumzGWWwZMoxJQEtYKL2wXI5tEZA5V-IavbOrL0pq5la824
DEBUG: Current user: null
DEBUG: No initial FCM token to save
```

### 3. **Login and Check Auth State**
Look for:
```
DEBUG: Auth state changed: AuthChangeEvent.signedIn
DEBUG: User signed in, saving FCM token...
DEBUG: Attempting to save FCM token for user: d66a8db3-3432-4953-abf1-c9c968a8b878, platform: ios
DEBUG: Token does not exist, inserting new token...
DEBUG: FCM token saved to database successfully: [result]
```

### 4. **Test Database Connection**
- Go to Settings menu (gear icon)
- Select "Test Database"
- Check logs for table structure and user tokens

### 5. **Test Notification**
- Go to Settings menu
- Select "Test Notification"
- Check logs for Edge Function response

## Expected Results

### Success Case:
1. User logs in → token saved to database
2. Test notification → Edge Function finds tokens
3. FCM notification sent successfully

### Failure Cases:
1. **Table doesn't exist**: Database connection test fails
2. **Wrong column names**: Edge Function gets 500 error
3. **User not authenticated**: Token save fails with "No user ID found"
4. **Database permissions**: Insert fails with permission error

## Next Steps

1. **Run the app** and check debug logs
2. **Test database connection** via settings menu
3. **Verify token saving** when user logs in
4. **Test notification sending** to confirm fix

## Files Modified

- `lib/services/notification_service.dart` - Added auth listener and debug logging
- `lib/widgets/settings_menu.dart` - Added database test option
- `TOKEN_SAVING_DEBUG.md` - This documentation

## Potential Issues to Check

1. **Database Table**: Does `device_tokens` table exist?
2. **Table Structure**: Are columns named correctly?
3. **Permissions**: Can the app insert into the table?
4. **User Authentication**: Is the user properly authenticated?
5. **Timing**: Is the token saved after user login?

## Debug Commands

### Check Database Table:
```sql
-- Run in Supabase SQL editor
SELECT * FROM device_tokens LIMIT 5;
```

### Check User Tokens:
```sql
-- Replace with actual user ID
SELECT * FROM device_tokens WHERE user_id = 'd66a8db3-3432-4953-abf1-c9c968a8b878';
```

### Check Table Structure:
```sql
-- Run in Supabase SQL editor
\d device_tokens;
``` 