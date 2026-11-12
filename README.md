# Шүдхэн — хүүхдийн шүд угаах апп

Flutter app for Android, iOS, and web. The Mongolian child-friendly app guides brushing across four sections, displays elapsed and remaining time, includes a camera motion guide and filters, supports flossing, reminders, and local star rewards.

## Requirements

- Flutter SDK compatible with the Dart constraint in `pubspec.yaml`
- Android Studio with Android SDK for Android builds
- Xcode for iOS builds

## Run locally

```sh
flutter pub get
flutter run
```

The app creates a local demo client with ID `123456`. No password is needed. Use Remember me to keep the ID signed in. Brushing events, rewards, and settings are saved locally on the device.

## Build Android APK

```sh
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

The demo uses on-device storage. It does not sync brushing data with the separate doctor dashboard or a server. Android release builds use the Flutter debug signing key and are intended for testing, not Play Store publishing.
