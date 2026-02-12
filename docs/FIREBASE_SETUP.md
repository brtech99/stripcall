# Firebase Push Notifications Setup

This guide will help you set up Firebase Cloud Messaging (FCM) for push notifications in your StripCall app.

## Prerequisites

1. A Firebase project
2. iOS and Android apps configured in Firebase
3. Firebase configuration files

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Add iOS and Android apps to your project

## Step 2: Configure iOS App

1. **Download `GoogleService-Info.plist`** from Firebase Console
2. **Add to iOS project:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Drag `GoogleService-Info.plist` into the Runner folder
   - Make sure "Copy items if needed" is checked
   - Add to Runner target

3. **Configure iOS capabilities:**
   - In Xcode, select Runner target
   - Go to "Signing & Capabilities"
   - Add "Push Notifications" capability
   - Add "Background Modes" capability
   - Check "Remote notifications"

4. **Update `ios/Runner/Info.plist`:**
   ```xml
   <key>UIBackgroundModes</key>
   <array>
       <string>fetch</string>
       <string>remote-notification</string>
   </array>
   ```

## Step 3: Configure Android App

1. **Download `google-services.json`** from Firebase Console
2. **Add to Android project:**
   - Place `google-services.json` in `android/app/`
   - Make sure it's included in your `.gitignore` if it contains sensitive data

3. **Update `android/app/build.gradle`:**
   ```gradle
   // Add at the bottom of the file
   apply plugin: 'com.google.gms.google-services'
   ```

4. **Update `android/build.gradle`:**
   ```gradle
   buildscript {
       dependencies {
           // Add this line
           classpath 'com.google.gms:google-services:4.3.15'
       }
   }
   ```

## Step 4: Get Firebase Server Key

1. In Firebase Console, go to **Project Settings**
2. Go to **Cloud Messaging** tab
3. Copy the **Server key** (starts with `AAAA...`)

## Step 5: Update Configuration

1. **Update `lib/config/firebase_config.dart`:**
   ```dart
   static const String serverKey = 'YOUR_ACTUAL_SERVER_KEY_HERE';
   static const String projectId = 'YOUR_FIREBASE_PROJECT_ID';
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

## Step 6: Test Notifications

1. **Run the app** on a physical device (not simulator)
2. **Check logs** for FCM token:
   ```
   FCM Token: fMEP0...
   ```
3. **Create a problem** and verify notifications are sent
4. **Test "On my way"** and resolution notifications

## Troubleshooting

### Common Issues:

1. **"No device tokens found"**
   - Check that users have granted notification permissions
   - Verify device tokens are being saved to database

2. **"FCM request failed"**
   - Verify server key is correct
   - Check Firebase project configuration

3. **iOS notifications not working**
   - Verify APNs certificates are configured
   - Check that app has notification permissions

4. **Android notifications not working**
   - Verify `google-services.json` is in correct location
   - Check that Google Play Services are up to date

### Debug Steps:

1. **Check FCM token generation:**
   ```dart
   debugPrint('FCM Token: ${NotificationService().fcmToken}');
   ```

2. **Verify database tokens:**
   ```sql
   SELECT * FROM device_tokens WHERE user_id = 'your_user_id';
   ```

3. **Test FCM manually:**
   Use Firebase Console to send a test message to your device token

## Security Notes

- **Never commit** `google-services.json` or `GoogleService-Info.plist` to public repositories
- **Keep server key secure** - it should only be used server-side (we're using it client-side for simplicity)
- **Consider moving** to Edge Functions for production use

## Next Steps

1. **Add notification preferences** UI for users
2. **Implement notification tap handling** to navigate to specific problems
3. **Add Edge Functions** for background notifications
4. **Add notification badges** and sound customization 