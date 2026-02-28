# SME-EASY – AI E-Invoice & Compliance Platform for Malaysian SMEs

A comprehensive Flutter application designed to help Malaysian small and medium enterprises (SMEs) comply with LHDN's mandatory e-invoicing (MyInvois) requirements starting in 2026.

## 🎬 Demo Materials
Link: https://youtu.be/Vl4aHalP-_g
Pitch Deck: https://www.canva.com/design/DAHCDFjA388/mIDBZX-gmbcLxRIetBgCIA/view?utm_content=DAHCDFjA388&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h0fb170719b

---

## 🎯 Problem Statement

Starting in 2026, LHDN's mandatory e-invoicing (MyInvois) rollout reaches **all businesses** in Malaysia, including micro and small enterprises. The scale of the challenge is significant:

- **Over 1.1 million SMEs** in Malaysia account for 97.4% of all business establishments (DOSM 2023).
- **RM 20,000 – RM 300,000** in penalties can be imposed on businesses that fail to comply with the Income Tax Act.
- Many microbusinesses still manage invoices via WhatsApp, paper receipts, or basic spreadsheets.

Many microbusinesses struggle with:
- Complex compliance rules (e.g., the RM 10,000 threshold for real-time submission)
- Messy receipt management with no digital trail
- Real-time submission requirements with strict deadlines
- Audit readiness and 7-year record retention obligations

These increase the risk of errors and penalties during the transition period, disproportionately affecting small businesses that lack dedicated accounting staff.

## 🚀 Solution

SME-EASY is a Gemini-powered invoicing and compliance platform that automates invoice creation, validation, submission, and record management, helping SMEs stay compliant effortlessly.

---

## 🌍 SDG Alignment

SME-EASY directly supports two United Nations Sustainable Development Goals:

### SDG 8 — Decent Work & Economic Growth
> *"Promote sustained, inclusive and sustainable economic growth, full and productive employment and decent work for all."*

- Lowers the barrier to formal business compliance for micro and small enterprises, enabling them to participate in the digital economy without needing dedicated accounting staff.
- Reduces the administrative burden on SME owners, freeing time to focus on productive business activities.
- Supports economic formalisation by easing the transition to mandatory e-invoicing, helping SMEs avoid penalties that could threaten jobs and livelihoods.
- Promotes financial inclusion by making tax compliance accessible to businesses that lack the resources for enterprise ERP systems.

### SDG 9 — Industry, Innovation & Infrastructure
> *"Build resilient infrastructure, promote inclusive and sustainable industrialisation and foster innovation."*

- Leverages cutting-edge AI (Google Gemini multimodal, Vertex AI Search) to innovate the invoicing and compliance workflow for an underserved segment.
- Contributes to Malaysia's digital infrastructure by integrating directly with the national LHDN MyInvois API, helping to build a robust e-invoicing ecosystem.
- Demonstrates practical, real-world application of AI and cloud technologies (Firebase, Google Maps Platform) to solve public-sector compliance challenges.
- Encourages technology adoption among SMEs, accelerating their digitisation and resilience.

---

## 👥 User Feedback & Iteration

We conducted qualitative interviews and usability testing with a diverse group of stakeholders to validate the problem and refine the solution.

### Key Insights from User Research

| # | Insight | How We Iterated |
|---|---|---|
| 1 | **"I don't know what counts as taxable."** — SME owners lacked basic MyInvois literacy and feared making mistakes. | Added the **Knowledge Assistant** feature backed by Vertex AI Search + Gemini RAG so users can ask plain-language compliance questions at any time. |
| 2 | **"Typing in invoices takes forever."** — Manual data entry was the biggest pain point, especially for sole traders handling 10–30 transactions a week. | Prioritised **Voice-to-Invoice** (speak naturally, Gemini extracts structured data) and **Receipt Scanner** (photo → invoice in one tap) as core flows, not optional add-ons. |
| 3 | **"I don't know until it's too late."** — Users only realised they had missed a submission deadline after receiving a warning letter. | Built a **Compliance Dashboard** with a real-time score, deadline alerts stored in Firestore, and proactive AI-generated recommendations surfaced on the home screen. |
| 4 | **"Where do I go for help?"** — Users wanted to speak to someone but didn't know where the nearest LHDN office or SME digital hub was. | Integrated **Google Maps** with geolocated pins for LHDN offices, SME centres, and tax consultation services, with tap-to-call and tap-to-navigate. |

### Iteration Timeline

Our development followed a 3-stage feedback loop to ensure the app remained relevant as the LHDN 2026 mandate evolved.

#### Phase 1
- **Focus:** Core manual invoicing flow.
- **The Problem:** Internal testing showed that manual data entry for a standard 10-item invoice took over 4 minutes — completely unfeasible for busy Malaysian micro-retailers.
- **The Iteration:** We pivoted from manual forms to an **AI-First entry system**, implementing Gemini 2.5 Flash to handle natural language voice commands and messy handwritten receipt scans via `GeminiInvoiceService` and `GeminiVisionReceiptService`. Voice-to-Invoice and Receipt Scanner were elevated from optional features to the primary creation flows in the AI Assistant screen.

---

#### Phase 2
- **Focus:** Compliance validation.
- **The Problem:** News broke regarding the RM 10,000 "Consolidation Trap" (LHDN Specific Guideline v4.6). Users were confused about when they could consolidate sales and when they needed individual e-invoices.
- **The Iteration:** We built the **"Compliance Guard" logic**. The `ComplianceSettings.requiresSubmission()` check in `invoice_config.dart` flags any transaction ≥ RM 10,000 for mandatory individual submission. The `InvoiceOrchestrator` enforces this before allowing MyInvois submission, and the invoice detail screen surfaces a contextual warning — preventing accidental consolidation of above-threshold invoices. Relaxation period tracking (2026–2027) is also built in.

---

#### Phase 3 
- **Focus:** UX and transparency.
- **The Problem:** During usability tests, users felt "compliance anxiety" even with the AI. They needed to see exactly how close they were to the RM 1 million mandatory threshold and whether their current month's submissions were on track.
- **The Iteration:** We added the **Home Dashboard compliance score and progress bar**, and integrated **Vertex AI Search** into the Knowledge Assistant. Users can now ask "Do I need to submit this month?" and receive a grounded response based on the latest February 2026 LHDN guidelines — not a generic AI guess.

---

## 📊 Success Metrics & Scalability

### Measurable Impact Goals

| Metric | Target (6 months post-launch) |
|---|---|
| Invoice creation time | Reduce from ~15 min (manual) to < 2 min via voice/scan |
| MyInvois submission errors | < 5% rejection rate vs. industry average of ~20% for first-time filers |
| Compliance score | ≥ 80% of active users maintain a compliance score above 70 |
| SME onboarding | 500 SME users in the first 3 months |
| Knowledge Assistant deflection | 60% of compliance queries resolved without contacting LHDN directly |

### Scaling Roadmap

#### Phase 1 *(Months 1–3)*
- **Target:** 50 micro-businesses — vendors, small cafes.
- **Focus:** Refine Voice-to-Invoice accuracy for local accents and slang (Manglish / Bahasa Melayu) using Gemini's multimodal capabilities.
- **Milestone:** Android release; Firebase backend live; Gemini + Vertex AI Search connected.

#### Phase 2 *(Months 4–9)*
- **Target:** Specific sectors — retail, logistics, professional services.
- **Scaling tech:** Migrate to **Google Cloud Run** with auto-scaling to handle traffic surges during peak tax seasons and month-end closing, without manual server management.
- **Integration:** Move from mocked LHDN API to a formal **MyInvois sandbox integration**, then production.
- **Milestone:** Multi-language support (BM, EN, ZH); push notifications for deadline alerts.

#### Phase 3 *(Year 1+)*
- **Feature growth:** Multi-user support for larger SMEs with accounting teams; Cloud Functions for automated compliance checks.
- **Marketplace:** Integrate with **Malaysian banking APIs** for one-click invoice payment once an invoice is validated.
- **Regional potential:** Adapt the compliance engine for other Southeast Asian countries implementing similar digital tax regimes (Indonesia PPN, Thailand VAT e-filing).
- **Milestone:** Accountant / tax agent portal; open API for POS system integrations.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile Framework | Flutter (Dart SDK `^3.10.8`) |
| AI — Text/Voice to Invoice | Google Gemini 2.5 Flash (`google_generative_ai`) |
| AI — Receipt Scanning | Google Gemini 2.5 Flash Vision (multimodal) |
| AI — Knowledge Assistant | Google Gemini 2.5 Flash + Vertex AI Search |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Maps | Google Maps Flutter SDK |
| Geolocation | Geolocator + Geocoding |
| Charts | FL Chart + Syncfusion Flutter Charts |
| PDF Generation | `pdf` + `printing` packages |
| State Management | Provider |
| Fonts | Google Fonts |

---

## 📐 System Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Flutter App                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │  Screens │  │ Provider │  │   Backend Layer   │  │
│  │ (UI/UX)  │◄─│  State   │◄─│  Services/Models  │  │
│  └──────────┘  └──────────┘  └────────┬──────────┘  │
└───────────────────────────────────────│─────────────┘
                                        │
                ┌───────────────────────┼───────────────────────┐
                │                       │                       │
                ▼                       ▼                       ▼
        ┌───────────────┐    ┌─────────────────────┐   ┌──────────────────┐
        │  Google AI    │    │     Firebase        │   │  Google Maps     │
        │               │    │                     │   │  Platform        │
        │ Gemini 2.5    │    │ Firebase Auth       │   │                  │
        │ Flash (text)  │    │ Cloud Firestore     │   │ Maps SDK         │
        │               │    │                     │   │ Geocoding API    │
        │ Gemini 2.5    │    │  /users             │   │                  │
        │ Flash Vision  │    │  /invoices          │   └──────────────────┘
        │               │    │  /invoice_drafts    │
        │ Vertex AI     │    │  /customers         │   ┌──────────────────┐
        │ Search        │    │  /compliance_alerts │   │  LHDN MyInvois   │
        └───────────────┘    │  /compliance_       │   │  API             │
                             │    questions        │   │                  │
                             │  /support_locations │   │  (Submission &   │
                             │  /analytics_cache   │   │   Validation)    │
                             └─────────────────────┘   └──────────────────┘
```

**Request flows:**
- **Voice/Text → Invoice**: Microphone → `speech_to_text` → `GeminiInvoiceService` → Firestore `/invoices`
- **Receipt → Invoice**: Camera/Gallery → `GeminiVisionReceiptService` (multimodal) → Firestore `/invoices`
- **Compliance Q&A**: User query → `VertexAISearchService` (primary) → `KnowledgeAssistantService` Gemini RAG (fallback) → Firestore `/compliance_questions`
- **Dashboard**: Firestore live queries → `ComplianceService` + `AnalyticsService` → `HomeScreen`

---

## ✨ Implemented Features

### 1. Authentication
**Google Technologies:** Firebase Authentication, Cloud Firestore  
*Firebase Auth provides zero-infrastructure identity management with Auth state streams that integrate directly with Flutter's Provider pattern. Cloud Firestore offers real-time listeners and user-isolated collections, making it ideal for live compliance dashboards and multi-device sync without a custom backend.*

- Email & password sign-in / sign-up
- Business registration with TIN, phone, and address fields
- Firebase Auth state stream with in-memory user cache
- User profiles persisted in `/users/{uid}` on Firestore

---

### 2. Voice-to-Invoice Generation
**Google Technologies:** Gemini 2.5 Flash (`google_generative_ai`)  
*Chosen for best-in-class instruction-following for structured JSON extraction from free-form voice/text input. The multimodal architecture means we use one SDK for both text and vision tasks, reducing complexity.*

- Speak sales details naturally using the device microphone (`speech_to_text`)
- Text typed input as an alternative to voice
- Gemini AI parses free-form speech/text and returns a fully structured invoice draft (line items, buyer details, totals)
- Draft loaded directly into the invoice editor for review, modification or instant save

---

### 3. Receipt & Document Scanning
**Google Technologies:** Gemini 2.5 Flash Vision (multimodal API)  
*Natively handles image and PDF inputs in a single API call, extracting buyer TIN, line items, and tax amounts without a separate OCR pipeline. 

- Capture receipts with the device camera or pick from gallery (`image_picker`)
- Attach PDF documents directly from the device storage
- Files and images are mutually exclusive attachments, selecting one clears the other
- AI extracts buyer name, TIN, address, line items, and tax amounts from both receipt images and PDF invoices/documents
- Confidence scoring and extraction quality indicator displayed for each processed file
- Warnings and missing fields surfaced in the chat response before saving
- One-tap creation of a full invoice from extracted data

---

### 4. Invoice Management
**Google Technologies:** Cloud Firestore  
*User-isolated Firestore collections and real-time sync give every user a private, instantly updated invoice store — eliminating the need for a custom backend or polling logic.*

- Create, view, update, and soft-delete invoices
- All invoices stored in `/invoices/{invoiceId}` on Firestore, isolated per user via `createdBy` field
- Draft invoices stored in `/invoice_drafts/{draftId}`
- Filter by status: All, Draft, Pending, Submitted, Approved, Rejected
- Full-text search by invoice number, buyer name, or TIN
- Detailed invoice view with seller info, buyer info, and line item breakdown
- PDF generation and sharing via the `printing` package

---

### 5. Automated MyInvois Submission
**Google Technologies:** Cloud Firestore  
*Firestore's real-time listeners propagate submission status changes (pending → submitted → accepted/rejected) instantly across devices, giving users live visibility into their compliance standing without manual refreshes.*

- Automatic RM 10,000 threshold detection on each invoice
- One-tap submission to the LHDN MyInvois API
- Submission status tracked in Firestore (`pending`, `submitted`, `accepted`, `rejected`)
- MyInvois UUID and QR code recorded on successful submission
- Compliance status updated in real time after submission

---

### 6. Compliance Dashboard & Deadline Alerts
**Google Technologies:** Cloud Firestore, Gemini 2.5 Flash  
*Firestore's live queries power a compliance score that updates the moment an invoice is submitted or rejected. Gemini 2.5 Flash's instruction-following capability generates contextual, actionable recommendations — not generic tips — based on the user's actual invoice data.*

- Real-time compliance score computed from live Firestore invoice data
- Visual circular progress indicator for compliance health
- Counters for pending submissions and overdue invoices
- Compliance alerts stored in `/compliance_alerts/{alertId}` with severity levels (info, warning, error, deadline)
- Gemini AI-generated actionable compliance recommendations
- Pull-to-refresh for live updates

---

### 7. SME Compliance Knowledge Assistant
**Google Technologies:** Gemini 2.5 Flash, Vertex AI Search, Cloud Firestore  
*Gemini 2.0 Flash Exp's lower temperature configuration (0.3) and large context window make it suitable for factual, grounded compliance Q&A — crucial for a regulated domain like tax law. Vertex AI Search provides enterprise-grade semantic search with built-in document chunking, spell correction, and query expansion, delivering verifiable, cited answers from indexed LHDN documents — required where hallucinations carry legal risk.*

- Conversational chat interface for LHDN compliance questions
- Primary path: **Vertex AI Search** performs enterprise-grade semantic search over indexed LHDN compliance documents (configured via `VERTEX_PROJECT_ID`, `VERTEX_DATASTORE_ID`, `VERTEX_API_KEY` in `.env`)
- Fallback path: **Gemini AI with RAG** uses built-in compliance document context when Vertex AI Search is not configured
- Answered questions and chat history persisted to `/compliance_questions/{questionId}` in Firestore
- Safety settings applied (harassment, hate speech, explicit content, dangerous content filters)

---

### 8. Business Insights Analytics
**Google Technologies:** Cloud Firestore, Google Fonts  
*Firestore's per-user analytics cache enables fast aggregation queries without a dedicated data warehouse. Google Fonts delivers consistent, high-quality typography across Android, iOS, and Web from a single cross-platform source.*

- Revenue trend charts over 6 months (`fl_chart`, `syncfusion_flutter_charts`)
- Invoice status distribution (pie/bar chart)
- Top customers by revenue
- Compliance performance metrics
- Analytics data cached in `/analytics_cache/{userId}` on Firestore

---

### 9. Support Locator
**Google Technologies:** Google Maps Flutter SDK, Geolocator, Geocoding  
*Google Maps Platform is the only mapping SDK with official Malaysia POI data quality and native Flutter embedding via `google_maps_flutter`.*

- Interactive Google Maps view centred on the user's current GPS location
- Pins for nearby LHDN offices, SME digital centres, and tax consultation services
- Support location data stored and served from Firestore (`/support_locations/{locationId}`)
- Tap a pin to view address, hours, and contact details
- Deep-link to device navigation for directions
- Tap-to-call phone number launcher

---

### 10. Customer Management
**Google Technologies:** Cloud Firestore  
*User-scoped Firestore collections keep the customer directory private and in sync across devices, and the same customer records auto-populate buyer fields in new invoices — removing redundant data entry.*

- Dedicated customer list screen with search
- Add, view, and edit customers stored in `/customers/{customerId}` on Firestore
- Auto-populate buyer fields in new invoices from the customer directory

---

### 11. Notifications
**Google Technologies:** Cloud Firestore  
*Real-time listeners on the `/compliance_alerts` collection surface deadline warnings and submission reminders the moment they are written server-side, without requiring push notification infrastructure.*

- In-app notification screen listing compliance alerts and submission reminders
- Alerts pulled from `/compliance_alerts` Firestore collection in real time

---

## 🛠️ Technical Challenges

Building SME-EASY surfaced several non-trivial engineering problems. Below are the key challenges we encountered and the solutions we engineered.

### 1. Integrating Cloud Functions with Vertex AI for AI-Powered Recommendations

**Challenge:** Wiring Google Cloud Functions to Vertex AI for generating compliance recommendations and business insights introduced significant integration complexity — cloud infrastructure setup, IAM permissions, cold start latency, and error propagation all had to be managed carefully while keeping the app responsive.

**Solution:** We designed a layered fallback chain so the feature degrades gracefully rather than failing hard:
1. **Primary:** Cloud Function invokes the Vertex AI API for the richest, most contextually grounded recommendation.
2. **Fallback:** If the Cloud Function is unavailable or returns an error, the app falls back to a direct Gemini API call, preserving most of the AI capability without the cloud infrastructure dependency.
3. **Last resort:** If both AI paths fail (e.g., no network, quota exhausted), a curated set of static compliance tips is displayed so users always receive actionable guidance.

This pattern ensured that AI recommendations remained available under adverse conditions and decoupled the app's reliability from any single backend service.

---

### 2. Handling Speech Recognition Errors in Voice-to-Invoice

**Challenge:** On-device speech-to-text engines (via `speech_to_text`) are imperfect — regional accents, background noise, and domain-specific terminology (TINs, invoice numbers, Malaysian business names) all contribute to transcription errors. Passing a flawed transcript directly to Gemini for invoice generation risks producing incorrect line items, amounts, or buyer details.

**Solution:** Rather than attempting to make the transcription perfect (an unsolvable problem at the device level), we introduced a mandatory human-in-the-loop review step. After Gemini parses the transcript into a structured invoice draft, the draft is presented in a fully editable form before it can be saved or submitted. Every field — buyer name, TIN, line items, and totals — can be corrected by the user in one pass. This keeps the voice flow fast while ensuring no inaccurate data reaches Firestore or the LHDN API without explicit user confirmation.

---

### 3. Disambiguating User Intent in a Shared Chat Interface

**Challenge:** The AI assistant screen handles four distinct workflows — **invoice creation** (Voice-to-Invoice / text-to-invoice), **compliance Q&A** (Knowledge Assistant), **customer creation**, and **invoice modification** — all accepting free-form natural language input on the same interface. A rule-based keyword classifier (e.g., checking for words like "create" or "what is") failed on ambiguous or mixed-intent messages such as *"Can you help me with an invoice for GST-exempt goods?"* or *"Update the amount on my last invoice"*, which could reasonably trigger multiple flows.

**Solution:** We delegated intent classification to Gemini itself via `_detectUserIntent()` in `AIAssistantScreen`. Before executing any action, the app sends the user's message to `gemini-2.5-flash-lite` (temperature 0.1 for deterministic output) with a structured prompt that instructs it to classify the intent. The available categories are context-aware: `invoice_creation`, `compliance_question`, and `customer_creation` are always offered, while `invoice_modification` is only added to the prompt when an invoice draft is already loaded in the preview pane (`_previewInvoice != null`) — preventing spurious modification attempts on a blank state. Only after receiving this classification does the app route the message to the appropriate handler: `_handleCustomerCreation()`, `_handleInvoiceModification()`, `_handleComplianceQuestion()` (backed by `KnowledgeAssistantService` / `VertexAISearchService`), or `_handleInvoiceGeneration()` (backed by `GeminiInvoiceService`). If the AI classification is ambiguous or the API call fails, a lightweight keyword heuristic (checking for phrases like *"add customer"*, field-update verbs, or LHDN-related terms) provides a safe fallback before defaulting to `invoice_creation`. This layered approach handles nuanced and ambiguous messages far more robustly than any hand-crafted rule set alone.

---

## 🗂️ Project Structure

```
myinvoicemate/
├── lib/
│   ├── main.dart                  # App entry point, Firebase init, Provider setup
│   ├── firebase_options.dart      # Generated Firebase config
│   ├── backend/
│   │   ├── auth/                  # Firebase Auth service + user model
│   │   ├── invoice/               # Invoice models, Gemini services, Firestore service
│   │   ├── compliance/            # Compliance model + Firestore service
│   │   ├── customer/              # Customer model + Firestore service
│   │   ├── analytics/             # Analytics model + service
│   │   ├── knowledge_assistant/   # Gemini AI + Vertex AI Search services
│   │   ├── support/               # Support location model + service
│   │   └── firestore_collections.dart
│   ├── screens/
│   │   ├── auth/                  # Login, Signup
│   │   ├── home/                  # Dashboard home
│   │   ├── invoices/              # Invoice list, detail, create
│   │   ├── assistant/             # AI assistant chat (voice + vision + Q&A)
│   │   ├── customers/             # Customer list, detail, add
│   │   ├── notifications/         # Notification list
│   │   ├── profile/               # User profile, manage profile
│   │   ├── support/               # Support locator map
│   │   └── navigation/            # Bottom navigation scaffold
│   └── utils/
│       ├── constants.dart         # App constants, theme, colours
│       └── helpers.dart           # Date formatters, snackbar helpers
├── android/
│   └── app/
│       ├── google-services.json   # Firebase Android config
│       └── src/main/AndroidManifest.xml
├── ios/
│   └── Runner/
│       └── GoogleService-Info.plist
├── .env                           # API keys (not committed)
└── pubspec.yaml
```

---

## ⚙️ Setup Instructions

### Prerequisites

| Tool | Minimum Version |
|---|---|
| Flutter SDK | 3.10.x or later |
| Dart SDK | 3.10.8 or later |
| Android Studio / Xcode | Latest stable |
| Git | Any recent version |
| Firebase CLI | Latest (`npm i -g firebase-tools`) |

---

### Step 1 — Clone the Repository

```bash
git clone https://github.com/jocelyngan2005/MyInvoisMate.git
cd MyInvoisMate/myinvoicemate
```

---

### Step 2 — Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com) and create a new project (or use an existing one).
2. Enable the following Firebase services:
   - **Authentication** → Sign-in method → Email/Password
   - **Cloud Firestore** → Create database (production or test mode)
3. Register your app platforms:
   - **Android**: Package name `com.example.myinvoicemate`
   - **iOS**: Bundle ID `com.example.myinvoicemate`
4. Download the config files and place them as follows:

   | File | Destination |
   |---|---|
   | `google-services.json` | `android/app/google-services.json` |
   | `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` |

5. Re-generate `lib/firebase_options.dart` using the FlutterFire CLI:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

---

### Step 3 — Get API Keys

#### Google Gemini API Key
1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Click **Create API key** and copy the value.

#### Google Maps API Key
1. Open [Google Cloud Console](https://console.cloud.google.com).
2. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Geocoding API
3. Go to **Credentials → Create Credentials → API Key** and copy the value.
4. Add the key to `android/app/src/main/AndroidManifest.xml` inside the `<application>` tag:

   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
   ```

5. Add the key to `ios/Runner/AppDelegate.swift`:

   ```swift
   import GoogleMaps
   // inside application(_:didFinishLaunchingWithOptions:):
   GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
   ```

#### Vertex AI Search API Key *(Optional — enables enterprise RAG for the Knowledge Assistant)*
1. In Google Cloud Console, enable the **Vertex AI Search** API.
2. Create a data store and index your LHDN compliance documents.
3. Note your **Project ID**, **Data Store ID**, and **API Key**.

---

### Step 4 — Create the `.env` File

Create a file named `.env` in the `myinvoicemate/` directory (the same folder as `pubspec.yaml`):

```env
# Required
GEMINI_API_KEY=your_gemini_api_key_here

# Optional — Vertex AI Search (Knowledge Assistant enterprise mode)
VERTEX_PROJECT_ID=your_gcp_project_id
VERTEX_LOCATION=global
VERTEX_DATASTORE_ID=your_datastore_id
VERTEX_API_KEY=your_vertex_api_key
```

> **Important:** The `.env` file is listed in `.gitignore`. Never commit API keys to version control.

---

### Step 5 — Install Dependencies

```bash
flutter pub get
```

---

### Step 6 — Firestore Security Rules *(Recommended)*

In the Firebase Console → Firestore → Rules, apply user-isolated rules:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /invoices/{invoiceId} {
      allow read, write: if request.auth != null
        && resource.data.createdBy == request.auth.uid;
    }
    match /invoice_drafts/{draftId} {
      allow read, write: if request.auth != null
        && resource.data.createdBy == request.auth.uid;
    }
    match /customers/{customerId} {
      allow read, write: if request.auth != null
        && resource.data.createdBy == request.auth.uid;
    }
    match /compliance_alerts/{alertId} {
      allow read, write: if request.auth != null
        && resource.data.userId == request.auth.uid;
    }
    match /compliance_questions/{questionId} {
      allow read, write: if request.auth != null
        && resource.data.userId == request.auth.uid;
    }
    match /support_locations/{locationId} {
      allow read: if request.auth != null;
    }
    match /analytics_cache/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

### Step 7 — Run the App

```bash
# List connected devices
flutter devices

# Run on Android (emulator or physical device)
flutter run -d android

# Run on iOS simulator (macOS only)
flutter run -d ios

# Run on Web (Chrome)
flutter run -d chrome
```

---

### Step 8 — Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
```

---

## 🔑 Required Permissions

The following platform permissions are declared in the app manifests:

| Permission | Used By |
|---|---|
| Camera | Receipt scanning |
| Microphone | Voice-to-invoice |
| Location (foreground) | Support locator |
| Storage / Photo Library | Image picker |
| Internet | Firebase, Gemini API, Maps |

---

## 🐛 Troubleshooting

| Issue | Fix |
|---|---|
| `GEMINI_API_KEY not found` | Ensure `.env` exists in `myinvoicemate/` and `flutter pub get` was run |
| Maps not rendering | Verify the Google Maps API key in `AndroidManifest.xml` / `AppDelegate.swift` |
| Firebase `PlatformException` | Check that `google-services.json` / `GoogleService-Info.plist` match the Firebase project |
| `FlutterFire not initialized` | `Firebase.initializeApp()` is called in `main()` — ensure `google-services.json` is present |
| Vertex AI Search not used | If `VERTEX_PROJECT_ID` or `VERTEX_DATASTORE_ID` is empty, the assistant falls back to Gemini RAG automatically |

---

## 📝 Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | ✅ Yes | Google Gemini API key for all AI features |
| `VERTEX_PROJECT_ID` | Optional | GCP project ID for Vertex AI Search |
| `VERTEX_LOCATION` | Optional | Vertex AI Search region (default: `global`) |
| `VERTEX_DATASTORE_ID` | Optional | Vertex AI Search data store ID |
| `VERTEX_API_KEY` | Optional | API key for Vertex AI Search endpoint |

---

## 🆘 Support

Your feedback is crucial for helping us bridge the digital gap for Malaysian SMEs.

| Channel | Purpose |
|---|---|
| [GitHub Issues](https://github.com/jocelyngan2005/MyInvoisMate/issues) | Bug reports, feature requests and technical glitches |
| [Repository](https://github.com/jocelyngan2005/MyInvoisMate) | Access source code, documentation and project updates |

### Reporting an issue
To help us squash bugs faster, please include the following in your report:
- Environment: `flutter --version` and the device model (e.g. Pixel 7, Iphone 14)
- Steps to Reproduce: A short list of actions that led to the error.
- Expected vs. Actual: What should have happened vs. what actually happened.
- Logs: Any relevant snippets from `flutter logs`


>**Disclaimer:** MyInvoisMate is an educational prototype. While it follows official LHDN technical guidelines, it is not an officially sanctioned LHDN tool. Users should always cross-verify final submissions with the official MyInvois portal.


---

## 🙏 Acknowledgements

- **Google** — Gemini AI (`google_generative_ai`), Vertex AI Search, Firebase (Authentication, Cloud Firestore), Google Maps Platform, and Google Fonts, which form the backbone of this application.
- **LHDN (Lembaga Hasil Dalam Negeri Malaysia)** — for publishing the MyInvois technical specifications and compliance guidelines that ground the knowledge assistant.
- **Flutter & Dart teams** — for the cross-platform framework that powers the app.
- **Open-source community** — `fl_chart`, `syncfusion_flutter_charts`, `speech_to_text`, `flutter_tts`, `image_picker`, `geolocator`, `pdf`, `printing`, and all other packages listed in `pubspec.yaml`.
- **KitaHack 2026** — for the opportunity to build solutions that make a real difference for Malaysian SMEs.

---

## 📄 License

This project is licensed under the **MIT License**. We believe in open innovation to support the Malaysian digital economy.

```
MIT License

Copyright (c) 2026 Team BU ZHI DAO

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
