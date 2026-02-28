# SME-EASY — AI E-Invoice & Compliance Platform

SME-EASY (package name: `myinvoicemate`) is a Flutter mobile application built for Malaysian Small and Medium Enterprises (SMEs). It automates invoice creation, enforces LHDN MyInvois e-invoicing compliance, and provides AI-powered business insights — all from a single cross-platform app.

---

## Table of Contents

1. [Technical Architecture](#1-technical-architecture)
2. [Implementation Details](#2-implementation-details)
3. [Challenges Faced](#3-challenges-faced)
4. [Future Roadmap](#4-future-roadmap)

---

## 1. Technical Architecture

### High-Level Stack

```
┌─────────────────────────────────────────────────┐
│                Flutter (Dart)                   │
│   Mobile UI — Android / iOS / Web               │
├─────────────|───────────────────────────────────┤
│    State: Provider   │   Routing: Navigator 2.0 │
├──────────────────────┴──────────────────────────┤
│                 Backend Services                │
│  Firebase Auth │ Cloud Firestore │ Cloud Funcs  │
├─────────────────────────────────────────────────┤
│               AI / ML Layer                     │
│  Google Gemini 1.5 Flash (text + vision)        │
├─────────────────────────────────────────────────┤
│            Analytics / Data                     │
│  Google BigQuery  │  Vertex AI (planned)        │
└─────────────────────────────────────────────────┘
```

### Flutter App Layer

The app is structured around a bottom navigation shell (`MainNavigationScreen`) with an `IndexedStack` for zero-rebuild tab switching. A central floating action button always surfaces the AI Assistant regardless of the active tab.

| Screen | Purpose |
|---|---|
| Home | Dashboard with analytics summary cards |
| Invoices | Invoice list, detail, and status management |
| Customers | Customer directory with location / map view |
| Profile | Business profile and compliance settings |
| AI Assistant | Conversational invoice creation and Q&A |

### Firebase Backend

- **Firebase Authentication** — Email/password auth with persistent session via `authStateChanges()` stream. The app listens to the stream at startup and routes to `LoginScreen` or `MainNavigationScreen` accordingly.
- **Cloud Firestore** — Primary data store for users, invoices, customers, and analytics cache. Collections are defined in a central `FirestoreCollections` constants file to prevent string drift.
- **Cloud Functions (Node.js)** — Triggered on Firestore document writes to sync invoice and analytics data into BigQuery for reporting.

### AI Layer

Google Gemini 2.5 Flash is the backbone of all AI features, accessed via the `google_generative_ai` Dart package. Two dedicated service classes isolate AI concerns:

- `GeminiInvoiceService` — Natural language / voice-to-structured-invoice conversion.
- `GeminiVisionReceiptService` — Multimodal image analysis that extracts line items, totals, and vendor details from receipt photos.

### Analytics Layer

Cloud Functions sync every Firestore invoice write into a BigQuery dataset (`myinvoicemate_analytics`). An in-app analytics cache (`/analytics_cache/{userId}`) stores pre-computed aggregates with a 1-hour TTL, falling back to live Firestore queries when stale. Vertex AI is scaffolded for future predictive analytics.

---

## 2. Implementation Details

### Invoice Generation Orchestrator

All invoice creation flows through `InvoiceGenerationOrchestrator`, which coordinates the AI service calls and Firestore persistence:

```
User Input (voice / text / image)
         │
         ▼
InvoiceGenerationOrchestrator
    ├─ GeminiInvoiceService.generateFromText()    ← voice / text path
    └─ GeminiVisionReceiptService.analyzeReceipt() ← image path
         │
         ▼
    InvoiceDraft (in-memory)
         │
     [User reviews & confirms]
         │
         ▼
    FirestoreInvoiceService.save()  → Firestore /invoices/{id}
         │
         ▼
    Cloud Function trigger → BigQuery sync
```

Drafts are held in memory and never persisted until the user explicitly finalises them. This keeps Firestore write counts low and avoids orphaned draft documents.

### MyInvois Compliance

The app implements the five LHDN compliance statuses aligned with the MyInvois SDK:

| Status | Meaning |
|---|---|
| `draft` | Local only, not yet submitted to LHDN |
| `submitted` | Passed initial structural validation |
| `valid` | Successfully validated by LHDN |
| `invalid` | Validation failed — errors returned |
| `cancelled` | Cancelled by the issuer |

Transactions above RM 10,000 (`rm10kThreshold`) are flagged for mandatory e-invoice compliance. The API base URL (`lhdnApiUrl`) is configured as a constant to make the production switch straightforward.

### PDF Generation & Digital Signatures

`InvoicePdfGenerator` builds fully-formatted PDFs using the `pdf` / `printing` packages with:

- **QR code** embedded per invoice (generated via `qr_flutter`, rendered to PNG bytes before PDF composition).
- **RSA-SHA256 digital signature** via `DigitalSignatureService.buildSignedPayload()`, which signs the full invoice JSON. A graceful fallback to a display hash is used for accounts that have not yet generated a keypair.
- **Google Fonts (Noto Sans)** fetched via `PdfGoogleFonts` for consistent cross-platform rendering.
- Structured table layout with seller / buyer blocks, line-item breakdown, tax totals, and compliance metadata.

### Voice Input Pipeline

Speech recognition uses the `speech_to_text` package. The transcript is passed directly as the `input` parameter to `GeminiInvoiceService`, which interprets free-form language into a structured `InvoiceDraft`. Text-to-speech feedback (`flutter_tts`) is provided by the AI assistant for accessibility.

### Analytics & Tax Reporting

`AnalyticsService` computes:

- Total revenue, invoice count, paid/outstanding breakdowns.
- Sales trend data aggregated by month (configurable window, default 6 months).
- SST/tax summary: taxable sales, tax collected, estimated payable, and a per-month breakdown — ready to hand to an auditor.

Charts are rendered with both `fl_chart` (lightweight line/bar charts) and `syncfusion_flutter_charts` (advanced analytics visuals).

### State Management

The app uses the `provider` package with two top-level providers:
- `AuthServiceProvider` — `ChangeNotifier` that surfaces auth state to the widget tree.
- `AuthService` (singleton) — The raw service instance exposed for direct method calls without rebuilding listeners.

---

## 3. Challenges Faced

### LHDN MyInvois API Integration

Malaysia's MyInvois mandate is still in a phased rollout (relaxation period 2026–2027, full compliance from 2028+). The official LHDN API spec changed several times during development. To avoid tight coupling, the API base URL and all status codes are isolated in `AppConstants`, and the submission layer is designed to be swapped out independently of the invoice data model.

### Cloud Functions + Vertex AI Integration Complexity

Integrating Firebase Cloud Functions with Vertex AI to power the AI recommendations and business insights feature introduced significant infrastructure complexity — managing deployment configurations, service account permissions, and cold-start latency all had to be handled together.

**Solution:** A chain of fallbacks was implemented so the feature degrades gracefully rather than failing outright:

```
Request for AI insight
        │
        ▼
Cloud Function (Vertex AI)  ──[fails/unavailable]──▶  Direct Gemini API call
                                                               │
                                                       [fails/unavailable]
                                                               │
                                                               ▼
                                                       Static fallback response
```

This means users always receive a response — whether it comes from the full Vertex AI pipeline, a direct Gemini call, or a pre-written static insight — without any visible error.

### Speech-to-Text Recognition Accuracy

The `speech_to_text` package cannot guarantee 100% transcription accuracy, especially with domain-specific terms like business names, TIN numbers, and Malaysian product descriptions. A misheard word in the voice input could silently produce a wrong invoice total or customer name.

**Solution:** Rather than attempting to correct recognition errors automatically, the app routes all voice-generated invoices through a mandatory review step. The AI presents the fully parsed `InvoiceDraft` for the user to inspect and edit before any save or submission action is permitted. This shifts error correction to the user at the one moment they are best placed to catch it — right before committing the data.

### Ambiguous User Intent in the AI Chat Interface

The AI Assistant screen serves a dual purpose: answering MyInvois compliance questions and creating invoices. A message like *"I sold 5 items to Ali yesterday"* is clearly a creation request, but *"Can I invoice for services?"* sits somewhere between a question and a creation trigger. Simple keyword or rule-based intent classification broke down on these ambiguous inputs.

**Solution:** Intent classification was delegated to Gemini itself. Before any action is taken, the user's message is sent to Gemini with a structured classification prompt that returns one of two labels — `compliance_question` or `invoice_creation`. The app then routes accordingly: compliance questions are answered inline in the chat, while invoice creation triggers the `InvoiceGenerationOrchestrator` pipeline. Using Gemini for classification rather than rules means it handles context, phrasing variations, and mixed-language inputs far more robustly.

---

## 4. Future Roadmap

### Near-Term (2026)

- **Live LHDN API Submission** — Replace the mock submission layer with real calls to `api.myinvois.hasil.gov.my`, including OAuth token management, document signing per the LHDN UBL schema, and polling for validation responses.
- **Real-Time Compliance Checker** — A background task that monitors invoice statuses after submission and notifies the user when LHDN updates the record (valid / invalid / cancelled).
- **Offline Draft Support** — Cache in-progress invoices locally using `sqflite` so users can create drafts without a network connection and sync on reconnect.

### Mid-Term (2026–2027)

- **Vertex AI Predictive Analytics** — Leverage the already-scaffolded Vertex AI client to surface revenue forecasts, churn risk on outstanding invoices, and seasonal trend alerts on the home dashboard.
- **Multi-Currency & Multi-Language** — Add support for USD/SGD billing and a Bahasa Malaysia UI localisation to serve a broader SME base.
- **Recurring Invoice Automation** — Allow users to schedule periodic invoices (weekly, monthly) via Cloud Functions, with automatic status tracking.
- **Customer Portal** — A lightweight web view (or separate web app) where buyers can view, download, and acknowledge their invoices without needing the mobile app.

### Long-Term (2028+)

- **Full MyInvois Phase 2 Compliance** — Adapt to the full mandatory e-invoicing scope covering all transaction types: debit notes, credit notes, self-billed invoices, and import/export invoices.
- **Accounting Integrations** — Webhooks or direct API connectors to popular Malaysian accounting software (SQL Accounting, AutoCount, Xero) to eliminate double-entry.
- **AI Audit Assistant** — A conversational agent that can walk SME owners through their tax obligations, flag anomalies in their invoice history, and generate audit-ready summaries for LHDN inspection.
- **White-Label / Multi-Tenant Mode** — Allow accountancy firms and business associations to deploy the platform under their own branding for their SME clients.
