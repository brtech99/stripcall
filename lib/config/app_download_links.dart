/// Where to send web users to get the native StripCall app.
///
/// Beta phase: iOS via TestFlight, Android via Firebase App Distribution.
/// When the app goes public, swap these for the App Store / Play Store URLs
/// (and the buttons can become the official store badges).
class AppDownloadLinks {
  static const String iosTestFlight =
      'https://testflight.apple.com/join/lDVZhLpr';
  static const String androidFirebase =
      'https://appdistribution.firebase.dev/i/0c8e93c60c5204b1';
}
