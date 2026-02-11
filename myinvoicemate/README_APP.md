# SME-EASY – AI E-Invoice & Compliance Platform for Malaysian SMEs

A comprehensive Flutter application designed to help Malaysian small and medium enterprises (SMEs) comply with LHDN's mandatory e-invoicing (MyInvois) requirements starting in 2026.

## 🎯 Problem Statement

Starting in 2026, Malaysian SMEs must comply with LHDN's mandatory e-invoicing (MyInvois). Many microbusinesses struggle with:
- Complex compliance rules
- Messy receipt management
- Real-time submission requirements
- Audit readiness
- Risk of errors and penalties during transition

## 🚀 Solution

SME-EASY is a Gemini-powered invoicing and compliance platform that automates invoice creation, validation, submission, and record management, helping SMEs stay compliant effortlessly.

## ✨ Core Features

### 1. Voice-to-Invoice Generation
- **Voice Input**: Speak sales details naturally
- **AI Processing**: Gemini AI converts speech to structured invoice data
- **Quick Creation**: Generate invoice drafts instantly
- **Edit & Review**: Review and modify AI-generated invoices

### 2. Receipt & Document Extraction
- **Camera Scanning**: Capture receipts and documents
- **AI Vision**: Gemini Vision extracts data from images
- **Smart Recognition**: Identifies TIN, buyer info, line items
- **Confidence Scoring**: Shows AI extraction confidence levels

### 3. Automated MyInvois Submission
- **Real-time Submission**: Automatic submission for RM10k+ transactions
- **API Integration**: Direct connection to LHDN MyInvois API
- **Status Tracking**: Track submission status and responses
- **QR Code Generation**: Automatic QR code for verified invoices

### 4. Compliance Dashboard & Deadline Alerts
- **Compliance Score**: Real-time compliance health monitoring
- **Transaction Tracking**: Monitors RM10k threshold rules
- **Deadline Alerts**: Notifications for pending submissions
- **Recommendations**: AI-powered compliance suggestions

### 5. Invoice History & Audit Vault
- **Digital Storage**: Secure cloud storage of all invoices
- **Search & Filter**: Easy retrieval by status, date, customer
- **Export Options**: PDF generation for sharing
- **7-Year Retention**: Compliance with tax audit requirements

### 6. SME Compliance Knowledge Assistant
- **AI Chat**: Ask questions about LHDN rules and compliance
- **Grounded Answers**: Responses based on official documentation
- **FAQ Library**: Common questions with detailed answers
- **Source Citations**: Links to official LHDN sources

### 7. Business Insights Analytics
- **Sales Trends**: Visual charts of revenue over time
- **Status Breakdown**: Invoice status distribution
- **Top Customers**: Revenue analysis by customer
- **Compliance Metrics**: Track compliance performance

### 8. Support Locator (Maps Integration)
- **Find Offices**: Locate nearby LHDN offices
- **SME Centers**: Digital support centers on map
- **Tax Support**: Find tax consultation services
- **Directions**: Get navigation to support locations

## 🛠️ Technology Stack

### Frontend (This Implementation)
- **Flutter**: Cross-platform mobile-first application
- **Provider**: State management
- **Google Fonts**: Typography
- **FL Chart**: Analytics visualization

### Planned Backend Integration
- **Gemini 1.5 Flash (Vertex AI)**: Invoice understanding and compliance reasoning
- **Document AI + Gemini Vision**: Receipt and invoice data extraction
- **Firebase Auth + Firestore**: Secure profiles and invoice storage
- **Cloud Functions + MyInvois API**: Automated submission workflow
- **Vertex AI Search**: Compliance rule assistant
- **BigQuery + Looker Studio**: Analytics dashboards
- **Google Maps API**: Support location services

## 📁 Project Structure

```
lib/
├── main.dart                      # App entry point
├── models/                        # Data models
│   ├── analytics_model.dart
│   ├── compliance_model.dart
│   ├── invoice_model.dart
│   ├── support_location_model.dart
│   └── user_model.dart
├── screens/                       # UI screens
│   ├── analytics/
│   │   └── analytics_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── compliance/
│   │   └── compliance_dashboard_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── invoices/
│   │   ├── invoice_detail_screen.dart
│   │   └── invoice_list_screen.dart
│   ├── knowledge/
│   │   └── knowledge_assistant_screen.dart
│   ├── receipt_scanner/
│   │   └── receipt_scanner_screen.dart
│   ├── support/
│   │   └── support_locator_screen.dart
│   └── voice_invoice/
│       └── voice_invoice_screen.dart
├── services/                      # Business logic & API services
│   ├── analytics_service.dart
│   ├── auth_service.dart
│   ├── compliance_service.dart
│   ├── gemini_service.dart
│   ├── invoice_service.dart
│   ├── knowledge_assistant_service.dart
│   └── support_service.dart
└── utils/                         # Utilities and constants
    ├── constants.dart
    └── helpers.dart
```

## 🎨 Key Screens

### Authentication
- **Login Screen**: Secure email/password authentication
- **Sign Up Screen**: Business registration with TIN validation

### Dashboard
- **Home Screen**: Quick stats, actions, and feature navigation
- **Quick Stats**: Total invoices, pending items, compliance score

### Invoice Management
- **Invoice List**: Filterable list of all invoices
- **Invoice Detail**: Full invoice view with submission controls
- **Voice Invoice**: Speech-to-invoice creation
- **Receipt Scanner**: Camera-based data extraction

### Compliance & Analytics
- **Compliance Dashboard**: Alerts, recommendations, score tracking
- **Analytics Screen**: Sales trends, charts, customer insights
- **Knowledge Assistant**: AI-powered Q&A chatbot

### Support
- **Support Locator**: Interactive map of LHDN offices and support centers

## 🚦 Getting Started

### Prerequisites
- Flutter SDK (^3.10.8)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- VS Code or Android Studio IDE

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd myinvoicemate
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Run the app**
```bash
flutter run
```

### Development Commands

```bash
# Get dependencies
flutter pub get

# Run on specific device
flutter run -d <device-id>

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Run tests
flutter test

# Check for outdated packages
flutter pub outdated
```

## 🔐 Mock Services

All backend services are currently **mocked** with realistic data for frontend development:

- ✅ **AuthService**: Mock Firebase authentication
- ✅ **InvoiceService**: Mock invoice CRUD operations
- ✅ **GeminiService**: Mock AI processing (voice-to-invoice, receipt extraction)
- ✅ **ComplianceService**: Mock compliance tracking
- ✅ **AnalyticsService**: Mock analytics data
- ✅ **KnowledgeAssistantService**: Mock AI chat responses
- ✅ **SupportService**: Mock location data

## 📱 Features Demo

### Voice-to-Invoice
1. Tap microphone button
2. Speak: "Create invoice for ABC Trading, 10 units of Product A at RM 1200 each"
3. AI generates structured invoice
4. Review and submit

### Receipt Scanner
1. Take photo or select from gallery
2. AI extracts buyer info, items, amounts
3. Review extracted data
4. Create invoice with one tap

### Compliance Dashboard
- View real-time compliance score
- Check pending submissions
- Review alerts and deadlines
- Get AI recommendations

## 🎯 Malaysian E-Invoicing Compliance

### RM10,000 Threshold Rule
- Transactions ≥ RM10,000 require MyInvois submission
- Automatic detection and flagging
- Mandatory real-time submission

### Relaxation Period (2026-2027)
- Consolidated invoicing allowed for smaller transactions
- Grace period for system adaptation
- Full compliance from 2028 onwards

### TIN Requirements
- Valid TIN required for all invoices
- Automated validation
- 12-digit format verification

## 🔮 Future Enhancements

### Backend Integration
- [ ] Connect to actual Gemini API
- [ ] Integrate Firebase Authentication
- [ ] Set up Cloud Firestore
- [ ] Implement MyInvois API connection
- [ ] Configure Vertex AI Search

### Features
- [ ] Offline mode support
- [ ] Multi-language support (Malay, Chinese)
- [ ] Batch invoice processing
- [ ] Advanced reporting
- [ ] Customer management
- [ ] Inventory integration

### Mobile Features
- [ ] Push notifications
- [ ] Biometric authentication
- [ ] Offline data sync
- [ ] Widget for quick invoice creation

## 📄 License

This project is created for demonstration purposes for the Malaysian SME e-invoicing compliance initiative.

## 👥 Support

For questions about Malaysian e-invoicing compliance:
- Visit [LHDN MyInvois Portal](https://www.hasil.gov.my)
- Contact SME Digital Centres
- Use the in-app Knowledge Assistant

## 🙏 Acknowledgments

- LHDN for e-invoicing guidelines
- Google for Gemini AI and cloud services
- Flutter team for the amazing framework
- Malaysian SME community for feedback

---

**Built with ❤️ for Malaysian SMEs**
