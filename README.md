# LikeALocal Mobile

A Flutter app that helps users discover authentic local places, hidden gems, restaurants, and experiences, especially in Cairo, Egypt.

## Running the App

### Prerequisites

- Flutter SDK 3.11 or newer
- Android emulator or physical Android device
- Firebase CLI for rule deployment and demo seeding
- Firebase project connected through:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
  - `lib/firebase_options.dart`

### Basic Run

```bash
flutter pub get
flutter run
```

The AI assistant falls back to built-in demo replies when no Gemini API key is provided.

## Firebase Setup

The configured Firebase project is `likealocal-new-bb959`.

Deploy rules before the final demo:

```bash
firebase deploy --only firestore:rules,storage
```

Included rule files:

- `firestore.rules`
- `storage.rules`
- `firebase.json`

## Gemini API Key Setup

The AI chat screen uses Gemini. The key is injected at build time through `--dart-define`, so it is not stored in source code.

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
```

Never commit the Gemini key to git.

## Demo Data

Seed demo places and reviews after logging into Firebase CLI:

```bash
firebase login
node scripts/seed_dummy_data.js
```

Then verify the app from a clean account:

```text
signup -> profile/preferences -> search/filter -> details -> review
-> favorite -> map/save -> add place with photo/video -> chat
-> AI -> reminder/proximity notification -> notification history
```

## Feature Status

| Feature | Status |
|---|---|
| Browse and search local places | Done |
| Favorites / saved places | Done |
| Add a place with photos | Done |
| Add a place with video | Done |
| Video playback in details | Done |
| Map view and save from map | Done |
| AI chat assistant | Done, requires Gemini key for live AI |
| AI personalized by user profile | Done |
| AI grounded in Firestore places | Done |
| User-to-user chat | Done |
| Chat list | Done |
| Chat privacy and schedule enforcement | Done |
| Push notifications | Done |
| Notification history screen | Done |
| Notification tap navigation | Done |
| Proximity notifications near saved places | Done, verify on real Android device |
| Settings screen | Done |
| Admin moderation reports | Done |
| Firestore security rules | Done |
| Storage security rules | Done |
| Offline cache | Done for home, search, and favorites |

## Background Proximity Notes

The proximity service checks every 5 minutes while the app is open and registers an Android WorkManager periodic task for background checks. Android can throttle periodic background work, so validate this on a physical Android device before relying on it in the final live demo.

## Submission Checklist

- Run `flutter clean`
- Run `flutter pub get`
- Run `flutter analyze`
- Run `flutter test`
- Run `flutter build apk --debug`
- Deploy Firestore and Storage rules
- Seed or manually create demo data
- Record the full demo flow from a new account
- Capture final screenshots for the report
- Zip the final source code after removing local-only files

## Project Structure

```text
lib/
  main.dart
  models/
  providers/
  screens/
  services/
  theme/
  widgets/
```
