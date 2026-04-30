# EmotionAI – Flutter Emotion Detection App

A professional Flutter app for multi-modal emotion detection with timeline analytics.

## Features
- 🔐 Login & Sign Up with auth API integration
- 📝 Text emotion analysis
- 🎵 Audio emotion analysis  
- 📷 Photo/facial emotion analysis
- 🎬 Video emotion analysis
- 📊 Timeline with history + analytics dashboard
- 👤 Profile page with API configuration guide

---

## Project Structure

```
lib/
├── main.dart                         ← App entry point
├── theme.dart                        ← Colors & theme
│
├── models/
│   └── emotion_result.dart           ← Data models
│
├── services/                         ← ⚙️ API Services (edit these)
│   ├── auth_service.dart             ← Auth API
│   ├── text_emotion_service.dart     ← Text API
│   ├── audio_emotion_service.dart    ← Audio API
│   ├── photo_emotion_service.dart    ← Photo API
│   ├── video_emotion_service.dart    ← Video API
│   └── timeline_service.dart        ← Local storage
│
├── pages/                            ← UI Pages (one per file)
│   ├── splash_screen.dart
│   ├── login_page.dart
│   ├── signup_page.dart
│   ├── home_page.dart                ← Dashboard
│   ├── text_emotion_page.dart
│   ├── audio_emotion_page.dart
│   ├── photo_emotion_page.dart
│   ├── video_emotion_page.dart
│   ├── timeline_page.dart
│   └── profile_page.dart
│
└── widgets/
    └── shared_widgets.dart           ← Reusable components
```

---

## 🔑 Adding Your API URLs

### 1. Auth API
Open `lib/services/auth_service.dart`:
```dart
static const String _baseUrl = 'https://YOUR_AUTH_API_URL';
```
Replace with your auth server URL. Expected endpoints:
- `POST /login`  → `{ email, password }` → `{ token, user }`
- `POST /register` → `{ name, email, password }` → `{ token, user }`

### 2. Text Emotion API
Open `lib/services/text_emotion_service.dart`:
```dart
static const String _apiUrl = 'https://YOUR_TEXT_EMOTION_API_URL/analyze';
```
Expected request: `POST { text: "..." }`  
Expected response: `{ emotion: "happy", confidence: 0.85, all_emotions: { happy: 0.85, ... } }`

### 3. Audio Emotion API
Open `lib/services/audio_emotion_service.dart`:
```dart
static const String _apiUrl = 'https://YOUR_AUDIO_EMOTION_API_URL/analyze';
```
Sends multipart form with field `audio`.

### 4. Photo Emotion API
Open `lib/services/photo_emotion_service.dart`:
```dart
static const String _apiUrl = 'https://YOUR_PHOTO_EMOTION_API_URL/analyze';
```
Sends multipart form with field `image`.

### 5. Video Emotion API
Open `lib/services/video_emotion_service.dart`:
```dart
static const String _apiUrl = 'https://YOUR_VIDEO_EMOTION_API_URL/analyze';
```
Sends multipart form with field `video`.

---

## Expected API Response Format

All emotion APIs should return:
```json
{
  "emotion": "happy",
  "confidence": 0.85,
  "all_emotions": {
    "happy": 0.85,
    "sad": 0.05,
    "angry": 0.02,
    "fearful": 0.03,
    "surprised": 0.03,
    "disgusted": 0.01,
    "neutral": 0.01
  }
}
```

---

## Setup & Run

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

## Dependencies
- `http` – API calls
- `shared_preferences` – Local auth + history storage
- `image_picker` – Camera & gallery
- `file_picker` – Audio & video files
- `fl_chart` – Pie chart analytics
- `intl` – Date formatting

---

## Demo Mode
If no API URLs are configured, the app runs in **demo mode**:
- Login accepts any email/password
- Emotion analyses return simulated results
- Full UI flow works end-to-end for testing
