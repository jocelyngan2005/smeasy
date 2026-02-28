# SME-EASY — Setup Guide

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | ≥ 3.10.8 |
| Dart SDK | ≥ 3.10.8 (bundled with Flutter) |
| Node.js | 18.x |
| Firebase CLI | latest (`npm i -g firebase-tools`) |
| Android SDK | API 21+ (for Android targets) |

---

## 1. Clone the Repository

```bash
git clone https://github.com/your-org/MyInvoisMate.git
cd MyInvoisMate/myinvoicemate
```

---

## 2. Install Flutter Dependencies

```bash
flutter pub get
```

Run the code generator for JSON serialisation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Configure Environment Variables

Copy the example file and fill in all values:

```bash
cp .env.example .env
```

Open `.env` and set the following keys:

| Key | Where to obtain |
|---|---|
| `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/app/apikey) |
| `VERTEX_PROJECT_ID` | GCP project ID |
| `VERTEX_LOCATION` | e.g. `global` |
| `VERTEX_DATASTORE_ID` | Vertex AI Search console |
| `VERTEX_ACCESS_TOKEN` | `gcloud auth print-access-token` |
| `FIREBASE_PROJECT_ID` | Firebase console → Project settings |
| `FIREBASE_*_API_KEY` | Firebase console → Project settings → Your apps |
| `FIREBASE_*_APP_ID` | Firebase console → Project settings → Your apps |

---

## 4. Firebase Setup

### 4a. Sign in and select project

```bash
firebase login
firebase use myinvoicemate
```

### 4b. Generate native config files

```bash
flutterfire configure
```

This writes `lib/firebase_options.dart` and `android/app/google-services.json` for the `myinvoicemate` Firebase project. Accept the defaults when prompted.

### 4c. Enable Firebase services

In the [Firebase console](https://console.firebase.google.com/project/myinvoicemate):

- **Authentication** → Sign-in method → enable **Email/Password**.
- **Firestore** → Create database (production mode, region `asia-southeast1`).
- **Cloud Functions** → Ensure billing is enabled (Functions require the Blaze plan).

---

## 5. Android — Google Maps API Key

Open `android/local.properties` and add your Maps API key:

```properties
MAPS_API_KEY=your_google_maps_api_key_here
```

Obtain a key from the [Google Cloud Console](https://console.cloud.google.com/apis/credentials) with the **Maps SDK for Android** API enabled.

---

## 6. Cloud Functions

```bash
cd backend/cloud_functions
npm install
cd ../..
```

Deploy to Firebase:

```bash
firebase deploy --only functions
```

To run functions locally against the emulator instead:

```bash
firebase emulators:start --only functions,firestore
```

---

## 7. (Optional) Seed Firestore

A seed script is provided for development data:

```bash
cd scripts
npm install
node seed_firestore.js
cd ..
```

Ensure `scripts/service-account-key.json.json` contains a valid service account key downloaded from the Firebase console (Project settings → Service accounts → Generate new private key).

---

## 8. Run the App

```bash
flutter run
```

To target a specific platform:

```bash
flutter run -d android
flutter run -d chrome          # web
flutter run -d windows
```

For a release build:

```bash
flutter build apk --release    # Android
flutter build web --release    # Web
```
