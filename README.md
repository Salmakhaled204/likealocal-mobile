# LikeALocal Mobile

A Flutter app that helps users discover authentic local places, hidden gems, restaurants, and experiences — especially in Cairo, Egypt.

---

## Running the app

### Prerequisites
- Flutter SDK ≥ 3.11
- Android emulator or physical device
- Firebase project connected (`google-services.json` in `android/app/`)

### Basic run (demo mode — no AI)
```bash
flutter run
```

The AI assistant falls back to built-in demo replies when no API key is provided.

---

## Gemini API key setup (enables live AI chat)

The AI chat screen uses the **Gemini API**. The key is injected at build time via `--dart-define` so it is **never stored in source code**.

### Step 1 — Get a key
1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click **Create API key** and copy it

### Step 2 — Run with the key
```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
```

### Step 3 — Build release APK with the key
```bash
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
```

> **Never** commit the key to git. The `--dart-define` flag keeps it out of source control entirely.

### VS Code launch config (optional)
Add to `.vscode/launch.json` for convenience:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "LikeALocal (with AI)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=GEMINI_API_KEY=YOUR_KEY_HERE"]
    }
  ]
}
```

---

## Features

| Feature | Status |
|---|---|
| Browse & search local places | Done |
| Favorites / saved places | Done |
| Add a place with photos | Done |
| Map view | Done |
| AI chat assistant (Gemini) | Done — requires API key |
| AI personalized by user profile | Done — reads budget, vibe, area, categories from Firebase |
| AI grounded in real app places | Done — fetches up to 20 Firestore places into context |
| User-to-user chat | Done |
| Chat list | Done |
| Push notifications (FCM) | Done |
| Notification history screen | Done |
| Proximity notifications (near saved places) | Done — foreground/active app |
| Chat privacy enforcement | Done — respects `chatEnabled` setting |

---

## Background proximity notifications — important note

The proximity service checks every 5 minutes **while the app is open or in the foreground**. True killed-state background location requires native platform work (`WorkManager` on Android / `BGTaskScheduler` on iOS) beyond the Flutter layer. For the demo, open the app and the service runs automatically.

---

## Project structure

```
lib/
├── main.dart                  # Entry, auth, splash, navigator key
├── screens/
│   ├── home_screen.dart       # Main navigation + notification bell
│   ├── ai_chat_screen.dart    # Gemini AI assistant
│   ├── chat_screen.dart       # 1-to-1 messaging
│   ├── chat_list_screen.dart  # All conversations
│   ├── notifications_screen.dart  # Notification history
│   ├── place_details_screen.dart
│   ├── profile_screen.dart
│   └── ...
├── services/
│   ├── notification_service.dart  # FCM + local notifications
│   └── proximity_service.dart     # Nearby place alerts
├── models/place.dart
├── providers/
└── theme/app_theme.dart
```
