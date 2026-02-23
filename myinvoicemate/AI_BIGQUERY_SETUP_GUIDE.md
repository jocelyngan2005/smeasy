# AI & BigQuery Analytics Setup Guide

This guide will help you set up AI-powered recommendations and BigQuery analytics integration for MyInvoisMate.

---

## 🎯 Overview

The new analytics features include:
- **AI-Powered Recommendations**: Personalized business insights using Google Vertex AI
- **BigQuery Integration**: Export data for advanced analytics
- **Looker Studio**: Create interactive business dashboards

---

## 📋 Prerequisites

1. **Google Cloud Project** with billing enabled
2. **Firebase Project** (already configured)
3. **Google Cloud CLI** installed (optional for setup)

---

## ⚠️ Important: Firebase vs Google Cloud Project IDs

### Understanding Project IDs

Firebase projects are built on Google Cloud, but they can have **different project IDs**:

- **Firebase Project ID**: User-friendly name (e.g., `myinvoicemate-app`)
- **Google Cloud Project ID**: Technical identifier (e.g., `myinvoicemate-prod-12345`)

### Project Architecture

```
┌─────────────────────────────────────────────────────┐
│          Firebase Project                           │
│          ID: myinvoicemate-app                      │
│  ┌───────────────────────────────────────────────┐  │
│  │   Authentication, Firestore, Storage          │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │ Built on top of
                      ▼
┌─────────────────────────────────────────────────────┐
│       Google Cloud Project                          │
│       ID: myinvoicemate-prod-12345                  │
│  ┌───────────────────────────────────────────────┐  │
│  │   BigQuery, Vertex AI, Cloud Functions        │  │
│  │   ← Use THIS ID in your code                  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Finding Your Correct Project IDs

#### 1. Firebase Project ID
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click ⚙️ Settings > Project Settings
4. Look for **Project ID** (e.g., `myinvoicemate-app`)

#### 2. Google Cloud Project ID
1. In Firebase Console, go to Project Settings
2. Scroll to **"Your apps"** section
3. Look for **"GCP resource location"** or **"Project number"**
4. OR click **"Manage resources in the Google Cloud Console"** link
5. In GCP Console, the project ID is shown at the top (e.g., `myinvoicemate-prod-12345`)

**Alternatively:**
```bash
# List all your GCP projects
gcloud projects list

# Find the project linked to your Firebase
gcloud projects describe YOUR_FIREBASE_PROJECT_ID
```

### Which Project ID to Use Where?

| Service/File | Use Firebase ID | Use GCP ID |
|--------------|-----------------|------------|
| Firebase Auth | ✅ | ❌ |
| Firestore | ✅ | ❌ |
| BigQuery API | ❌ | ✅ |
| Vertex AI API | ❌ | ✅ |
| `bigquery_service.dart` | ❌ | ✅ |
| `ai_recommendations_service.dart` | ❌ | ✅ |
| `looker_studio_helper.dart` | ❌ | ✅ |

### If Your Project IDs Are Different

**Good news**: This is normal and won't cause issues! Here's what to do:

1. **Keep using Firebase ID** in your Flutter app for Firebase services (already configured in `firebase_options.dart`)

2. **Use Google Cloud ID** for BigQuery and Vertex AI in the three service files:
   ```dart
   // Use your GOOGLE CLOUD project ID here, not Firebase ID
   static const String _projectId = 'myinvoicemate-prod-12345'; // GCP ID
   ```

3. **Verify they're linked**:
   - Both consoles should show the same project when you navigate between them
   - The Firebase Console will have a link to "Manage in Google Cloud Console"

### Example Configuration

If your setup is:
- **Firebase Project ID**: `myinvoicemate-app`
- **Google Cloud Project ID**: `myinvoicemate-prod-12345`

Then update:

```dart
// ✅ CORRECT - lib/backend/analytics/services/bigquery_service.dart
static const String _projectId = 'myinvoicemate-prod-12345'; // Use GCP ID

// ❌ WRONG
static const String _projectId = 'myinvoicemate-app'; // Don't use Firebase ID
```

---

## 🚀 Setup Instructions

### Step 1: Identify Your Project IDs

**Before proceeding, determine:**
1. Your Firebase Project ID (for reference)
2. Your Google Cloud Project ID (for BigQuery/Vertex AI)

Use the steps above to find both IDs. Write them down!

### Step 2: Google Cloud Project Setup

1. **Go to Google Cloud Console**: https://console.cloud.google.com
2. **Enable required APIs**:
   ```bash
   gcloud services enable aiplatform.googleapis.com
   gcloud services enable bigquery.googleapis.com
   gcloud services enable bigquerydatatransfer.googleapis.com
   ```

   Or enable via Console:
   - Navigate to "APIs & Services" > "Library"
   - Search and enable:
     - Vertex AI API
     - BigQuery API
     - BigQuery Data Transfer API

### Step 3: Configure Service Files

Update the following constants in your codebase with your **Google Cloud Project ID** (NOT Firebase Project ID):

#### 1. BigQuery Service
File: `lib/backend/analytics/services/bigquery_service.dart`

```dart
static const String _projectId = 'YOUR_GCP_PROJECT_ID'; // ⚠️ Use Google Cloud ID
static const String _datasetId = 'myinvoicemate_analytics';
```

**Example:**
```dart
// If your GCP project ID is "myinvoicemate-prod-12345"
static const String _projectId = 'myinvoicemate-prod-12345';
static const String _datasetId = 'myinvoicemate_analytics';
```

#### 2. AI Recommendations Service
File: `lib/backend/analytics/services/ai_recommendations_service.dart`

```dart
static const String _projectId = 'YOUR_GCP_PROJECT_ID'; // ⚠️ Use Google Cloud ID (same as above)
static const String _location = 'us-central1'; // Or your preferred region
static const String _modelId = 'gemini-1.5-flash'; // Or gemini-1.5-pro for better insights
```

**Recommended locations:**
- `us-central1` - Best for general use, most features
- `asia-southeast1` - Closer to Malaysia, lower latency
- `us-east1` - Alternative US location

#### 3. Looker Studio Helper
File: `lib/backend/analytics/services/looker_studio_helper.dart`

```dart
static const String projectId = 'YOUR_GCP_PROJECT_ID'; // ⚠️ Use Google Cloud ID (same as above)
static const String datasetId = 'myinvoicemate_analytics';
```

**✅ Verification Checklist:**
- [ ] All three files use the same Google Cloud Project ID
- [ ] Project ID matches what you see in GCP Console (not Firebase Console)
- [ ] Project has billing enabled in GCP Console

### Step 3: Create BigQuery Dataset

#### Option A: Using Cloud Console
1. Go to BigQuery: https://console.cloud.google.com/bigquery
2. Click on your project
3. Click "CREATE DATASET"
4. Set Dataset ID: `myinvoicemate_analytics`
5. Choose location: `US` or `asia-southeast1` (for Malaysia)
6. Click "Create dataset"

#### Option B: Using gcloud CLI
```bash
bq mk --dataset \
  --location=US \
  YOUR_PROJECT_ID:myinvoicemate_analytics
```

### Step 4: Create BigQuery Tables

Run these SQL queries in BigQuery Console:

#### Invoices Table
```sql
CREATE TABLE `YOUR_PROJECT_ID.myinvoicemate_analytics.invoices` (
  invoice_id STRING NOT NULL,
  user_id STRING NOT NULL,
  invoice_number STRING,
  issue_date TIMESTAMP,
  total_amount FLOAT64,
  currency STRING,
  compliance_status STRING,
  buyer_name STRING,
  buyer_tin STRING,
  supplier_name STRING,
  supplier_tin STRING,
  tax_total FLOAT64,
  line_items_count INT64,
  created_at TIMESTAMP,
  submitted_at TIMESTAMP,
  export_timestamp TIMESTAMP
)
PARTITION BY DATE(issue_date)
CLUSTER BY user_id, compliance_status;
```

#### Analytics Cache Table
```sql
CREATE TABLE `YOUR_PROJECT_ID.myinvoicemate_analytics.analytics_cache` (
  user_id STRING NOT NULL,
  total_revenue FLOAT64,
  total_invoices INT64,
  average_invoice_value FLOAT64,
  sales_trend STRING,
  status_breakdown STRING,
  top_customers STRING,
  last_updated TIMESTAMP,
  export_timestamp TIMESTAMP
)
PARTITION BY DATE(export_timestamp)
CLUSTER BY user_id;
```

### Step 5: Configure Firebase Authentication

The services use Firebase Auth tokens to authenticate with Google Cloud. Ensure your Firebase project is linked to your Google Cloud project:

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Project Settings > Service Accounts
4. Verify the **Google Cloud project** shown matches your GCP project ID
5. Click "Manage in Google Cloud Console" to verify access

**Verify Firebase-GCP Link:**
```bash
# Get Firebase project details
firebase projects:list

# Check which GCP project is linked
gcloud projects describe YOUR_GCP_PROJECT_ID --format="value(name,projectId)"
```

**If Firebase and GCP are not linked:**
This should not happen with properly configured Firebase projects, but if you encounter issues:
1. Ensure you're using the same Google account for both consoles
2. Check that APIs are enabled on the correct GCP project
3. Verify IAM permissions allow Firebase to access GCP resources

### Step 6: Set Up Service Account (Optional for Backend)

If running exports via Cloud Functions:

1. Create a service account:
   ```bash
   gcloud iam service-accounts create myinvoicemate-bigquery \
     --display-name="MyInvoisMate BigQuery Service Account"
   ```

2. Grant permissions:
   ```bash
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:myinvoicemate-bigquery@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/bigquery.dataEditor"
   
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:myinvoicemate-bigquery@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/aiplatform.user"
   ```

3. Download the key (for Cloud Functions):
   ```bash
   gcloud iam service-accounts keys create service-account-key.json \
     --iam-account=myinvoicemate-bigquery@YOUR_PROJECT_ID.iam.gserviceaccount.com
   ```

---

## 🧪 Testing the Integration

### Test AI Recommendations

1. Run your app: `flutter run`
2. Navigate to the Home Screen
3. Look for the "AI-Powered Insights" banner
4. Click the refresh icon to generate new recommendations
5. Check the AI Recommendations card below

**Note**: First-time generation may take 10-15 seconds as it calls Vertex AI.

### Test BigQuery Export

1. On the Home Screen, scroll to "Advanced Analytics"
2. Tap "Export to BigQuery"
3. Wait for the success message
4. Verify data in BigQuery Console:
   ```sql
   SELECT * FROM `YOUR_PROJECT_ID.myinvoicemate_analytics.invoices`
   ORDER BY export_timestamp DESC
   LIMIT 10;
   ```

### Test Looker Studio Connection

1. Tap "Open Looker Studio" on the Home Screen
2. It will open Looker Studio in your browser
3. Connect to your BigQuery dataset
4. Create visualizations using the tables

---

## 📊 Looker Studio Dashboard Templates

### Executive Dashboard

**Key Metrics**:
- Total Revenue (Scorecard)
- Invoice Count (Scorecard)
- Average Invoice Value (Scorecard)
- Compliance Rate (Gauge)

**Charts**:
- Revenue Trend (Time Series)
- Status Breakdown (Pie Chart)
- Top 10 Customers (Table)
- Monthly Comparison (Bar Chart)

### Compliance Monitor

**Key Metrics**:
- Pending Submissions (Scorecard with alert)
- Overdue Invoices (Scorecard)
- Missing TIN Count (Scorecard)

**Charts**:
- Compliance Status Over Time (Time Series)
- Invoices Requiring Submission (Table)
- Risk Breakdown (Donut Chart)

### Sales Analytics

**Key Metrics**:
- Month-to-Date Revenue (Scorecard)
- Customer Count (Scorecard)
- Revenue Growth % (Scorecard)

**Charts**:
- Customer Lifetime Value (Bar Chart)
- Customer Churn Risk (Table with conditional formatting)
- Revenue by Customer Segment (Pie Chart)

---

## 🔄 Automated Data Sync (Optional)

Set up automatic BigQuery exports using Cloud Functions:

### Create Cloud Function

```javascript
// index.js
const {BigQuery} = require('@google-cloud/bigquery');
const admin = require('firebase-admin');

admin.initializeApp();
const bigquery = new BigQuery();

exports.syncInvoicesToBigQuery = functions.firestore
  .document('invoices/{invoiceId}')
  .onWrite(async (change, context) => {
    const invoice = change.after.exists ? change.after.data() : null;
    
    if (!invoice || invoice.isDeleted) return;
    
    const dataset = bigquery.dataset('myinvoicemate_analytics');
    const table = dataset.table('invoices');
    
    const row = {
      invoice_id: context.params.invoiceId,
      user_id: invoice.createdBy,
      invoice_number: invoice.invoiceNumber,
      issue_date: invoice.issueDate,
      total_amount: invoice.totalAmount,
      // ... other fields
      export_timestamp: new Date().toISOString(),
    };
    
    await table.insert([row]);
    console.log('Invoice synced to BigQuery:', context.params.invoiceId);
  });
```

Deploy:
```bash
cd backend/cloud-functions
firebase deploy --only functions:syncInvoicesToBigQuery
```

---

## 💡 AI Recommendations Categories

The AI service analyzes your data and provides recommendations in these categories:

1. **Compliance**: MyInvois submission alerts, TIN updates, deadline warnings
2. **Revenue**: Pricing optimization, upsell opportunities, revenue forecasting
3. **Customers**: Churn risk, engagement strategies, relationship management
4. **Operations**: Process efficiency, automation opportunities, error reduction
5. **Tax**: Tax optimization, deduction opportunities, filing reminders

---

## 🔧 Troubleshooting

### Issue: "Project not found" or "403 Forbidden"

**Cause**: Using Firebase Project ID instead of Google Cloud Project ID

**Solution**:
1. Find your Google Cloud Project ID (see "Firebase vs Google Cloud Project IDs" section above)
2. Update all three service files with the **GCP project ID**
3. Verify billing is enabled on the GCP project:
   ```bash
   gcloud beta billing projects describe YOUR_GCP_PROJECT_ID
   ```

### Issue: "Unable to get access token"

**Solution**: Ensure user is logged in with Firebase Auth. Check:
```dart
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // Redirect to login
}
```

### Issue: "Vertex AI API error: 403"

**Solution**: 
1. Verify Vertex AI API is enabled
2. Check service account has `aiplatform.user` role
3. Confirm Firebase project is linked to GCP project

### Issue: "BigQuery table not found"

**Solution**:
1. Verify dataset and table names match configuration
2. Check table creation SQL was executed successfully
3. Ensure correct project ID

### Issue: AI recommendations show fallback data only

**Solution**:
1. Check Vertex AI API quota in GCP Console
2. Verify network connectivity
3. Review error logs: `flutter logs | grep "AI"`

---

## 📈 Best Practices

1. **Sync Frequency**: Export to BigQuery daily or weekly to minimize costs
2. **Cache AI Recommendations**: Regenerate every 1-4 hours to balance freshness and API costs
3. **Monitor Quotas**: Check Vertex AI and BigQuery quotas in GCP Console
4. **Optimize Queries**: Use partitioned tables and clustering for better performance
5. **Data Retention**: Set up table expiration for cost management

---

## 💰 Cost Estimates (Monthly)

**Vertex AI (Gemini 1.5 Flash)**:
- 1,000 recommendations/month: ~$2-5
- 10,000 recommendations/month: ~$20-50

**BigQuery**:
- Storage (10 GB): ~$0.20/month
- Queries (100 GB processed): ~$5/month
- Streaming inserts (1M rows): ~$0.05/month

**Looker Studio**: Free for basic usage

**Total Estimated Cost**: $10-60/month for typical small business usage

---

## 🎓 Training Resources

- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)
- [Looker Studio Training](https://lookerstudio.google.com/training)
- [Firebase & GCP Integration](https://firebase.google.com/docs/projects/gcp-integration)

---

## 📌 Quick Reference: Project IDs

### How to Find Your Google Cloud Project ID

**Method 1: Via Firebase Console**
1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project → ⚙️ Settings → Project Settings
3. Click "Manage in Google Cloud Console" link
4. GCP Project ID is shown at the top of GCP Console

**Method 2: Via GCP Console**
1. Open [Google Cloud Console](https://console.cloud.google.com)
2. Click the project dropdown at the top
3. Your project ID is listed next to the project name

**Method 3: Via Command Line**
```bash
# List all projects
gcloud projects list

# Get specific project info
firebase projects:list
```

### Configuration Summary

Once you have your **Google Cloud Project ID**, update these files:

| File | Location | Constant | Value |
|------|----------|----------|-------|
| BigQuery Service | `lib/backend/analytics/services/bigquery_service.dart` | `_projectId` | Your GCP ID |
| AI Service | `lib/backend/analytics/services/ai_recommendations_service.dart` | `_projectId` | Your GCP ID |
| Looker Helper | `lib/backend/analytics/services/looker_studio_helper.dart` | `projectId` | Your GCP ID |

**Remember:** All three files must use the **same Google Cloud Project ID** (not Firebase Project ID).

---

## 📞 Support

For issues with:
- **Firebase**: Check Firebase Console > Support
- **Google Cloud**: Use Cloud Console > Support
- **MyInvoisMate**: Contact your development team

---

## ✅ Setup Checklist

**Phase 1: Project Setup**
- [ ] Google Cloud Project identified (GCP Project ID noted)
- [ ] Firebase Project identified (Firebase Project ID noted)
- [ ] Verified Firebase and GCP are linked
- [ ] Billing enabled on Google Cloud Project
- [ ] Vertex AI API enabled
- [ ] BigQuery API enabled

**Phase 2: BigQuery Configuration**
- [ ] BigQuery dataset created (`myinvoicemate_analytics`)
- [ ] Invoices table created with correct schema
- [ ] Analytics cache table created with correct schema

**Phase 3: Code Configuration**
- [ ] Updated `bigquery_service.dart` with GCP Project ID
- [ ] Updated `ai_recommendations_service.dart` with GCP Project ID
- [ ] Updated `looker_studio_helper.dart` with GCP Project ID
- [ ] Verified all three files use the **same** GCP Project ID
- [ ] Set preferred Vertex AI location (us-central1, asia-southeast1, etc.)

**Phase 4: Testing**
- [ ] Firebase Auth configured and working
- [ ] App tested with AI recommendations
- [ ] AI recommendations display correctly on home screen
- [ ] BigQuery export tested successfully
- [ ] Data visible in BigQuery Console
- [ ] Looker Studio connection tested

**Phase 5: Optional Enhancements**
- [ ] Cloud Functions deployed for auto-sync
- [ ] Looker Studio dashboard created
- [ ] Budget alerts set up in GCP Console
- [ ] API quotas monitored

---

**Ready to go!** 🚀 Your MyInvoisMate app now has enterprise-grade analytics and AI-powered insights!
