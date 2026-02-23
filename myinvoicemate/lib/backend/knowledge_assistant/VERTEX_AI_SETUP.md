# Vertex AI Search Setup Guide

This guide explains how to configure Vertex AI Search with OAuth2 authentication for the MyInvoisMate app.

## Prerequisites

1. **Google Cloud Project** with Vertex AI Search API enabled
2. **Vertex AI Search Data Store** created with LHDN compliance documents
3. **Service Account** with Vertex AI Search permissions
4. **gcloud CLI** installed on your development machine

## Authentication Overview

Vertex AI Search requires **OAuth2 Bearer tokens**, not API keys. For mobile apps, there are two approaches:

### Option 1: Development/Testing (Short-lived tokens)
- Use `gcloud` to generate temporary access tokens
- Valid for ~1 hour
- Good for testing and development
- **Limitation**: Tokens expire quickly

### Option 2: Production (Backend Proxy) [Recommended]
- Create a backend server that handles OAuth2
- Backend uses service account credentials
- Mobile app calls your backend, which calls Vertex AI
- **Advantage**: Secure, tokens managed server-side
- **Cost**: Requires hosting a backend service

---

## Option 1: Development Setup (Quick Start)

### Step 1: Install Google Cloud SDK

Download and install from: https://cloud.google.com/sdk/docs/install

### Step 2: Authenticate with Google Cloud

```bash
# Login to your Google Cloud account
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### Step 3: Generate Access Token

```bash
# Generate a temporary access token (valid ~1 hour)
gcloud auth print-access-token
```

This will output a long token like:
```
ya29.a0AfH6SMBx...very-long-token...xyz
```

### Step 4: Update .env File

Add to your `.env` file:

```env
# Vertex AI Search Configuration
VERTEX_PROJECT_ID=your-project-id
VERTEX_LOCATION=global
VERTEX_DATASTORE_ID=your-datastore-id
VERTEX_ACCESS_TOKEN=ya29.a0AfH6SMBx...your-token...xyz
```

### Step 5: Test the Application

```bash
flutter run
```

Ask a compliance question in the AI Assistant. If Vertex AI is configured correctly, you should see:
- "Using Vertex AI Search" in the console
- Grounded answers with citations from your documents

### Important Notes:

⚠️ **Token Expiration**: Access tokens expire after ~1 hour. You'll need to regenerate:

```bash
# Regenerate token
gcloud auth print-access-token

# Update .env file with new token
# Restart the app
```

⚠️ **Security**: Never commit `.env` file to version control. Add to `.gitignore`.

---

## Option 2: Production Setup (Backend Proxy)

For production apps, use a backend server to handle OAuth2:

### Architecture

```
Mobile App → Your Backend API → Vertex AI Search
            (OAuth2 handling)
```

### Backend Setup (Node.js Example)

#### 1. Create Backend Service

```javascript
// server.js
const express = require('express');
const { GoogleAuth } = require('google-auth-library');

const app = express();
app.use(express.json());

// Initialize Google Auth with service account
const auth = new GoogleAuth({
  keyFile: './service-account-key.json',
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

app.post('/api/vertex-search', async (req, res) => {
  try {
    const { query } = req.body;
    
    // Get access token
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    
    // Call Vertex AI Search
    const response = await fetch(
      `https://global-discoveryengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/collections/default_collection/dataStores/${DATASTORE_ID}/servingConfigs/default_search:search`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          query,
          pageSize: 5,
          // ... other parameters
        }),
      }
    );
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

#### 2. Deploy Backend

Deploy to Cloud Run, App Engine, or any hosting service:

```bash
# Deploy to Cloud Run (example)
gcloud run deploy vertex-proxy \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

#### 3. Update Flutter App

Modify `vertex_ai_search_service.dart` to call your backend:

```dart
// Instead of calling Vertex AI directly, call your backend
final response = await http.post(
  Uri.parse('https://your-backend.run.app/api/vertex-search'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'query': query}),
);
```

---

## Troubleshooting

### Error: 401 Unauthorized

**Cause**: Access token is invalid or expired

**Solution**:
```bash
# Regenerate token
gcloud auth print-access-token

# Update .env file
# Restart app
```

### Error: 403 Forbidden

**Cause**: Service account lacks permissions

**Solution**: Grant permissions in Google Cloud Console:
1. Go to IAM & Admin → Service Accounts
2. Find your service account
3. Add role: "Vertex AI User" or "Discovery Engine Admin"

### Error: VERTEX_ACCESS_TOKEN not found

**Cause**: `.env` file not loaded or missing variable

**Solution**:
1. Verify `.env` file exists in project root
2. Ensure it contains `VERTEX_ACCESS_TOKEN=...`
3. Run `flutter clean` and `flutter pub get`
4. Restart the app

### Error: 404 Not Found

**Cause**: Project ID or Data Store ID is incorrect

**Solution**:
1. Verify IDs in Google Cloud Console
2. Update `.env` file
3. Check `VERTEX_LOCATION` (usually "global")

---

## Environment Variables Reference

Required variables in `.env`:

```env
# Vertex AI Search (OAuth2)
VERTEX_PROJECT_ID=my-project-123456      # Your GCP Project ID
VERTEX_LOCATION=global                   # Usually "global"
VERTEX_DATASTORE_ID=my-datastore_1234    # Your Data Store ID
VERTEX_ACCESS_TOKEN=ya29.a0AfH6SMB...   # OAuth2 access token

# Gemini API (for RAG fallback)
GEMINI_API_KEY=AIzaSy...                # Gemini API key
```

---

## Token Refresh Script

For development, create a script to auto-refresh tokens:

### Bash Script (Linux/Mac)

```bash
#!/bin/bash
# refresh-token.sh

# Generate new token
TOKEN=$(gcloud auth print-access-token)

# Update .env file
sed -i "s/VERTEX_ACCESS_TOKEN=.*/VERTEX_ACCESS_TOKEN=$TOKEN/" .env

echo "Token refreshed! Valid for ~1 hour"
echo "Restart the Flutter app to use new token"
```

Make executable:
```bash
chmod +x refresh-token.sh
./refresh-token.sh
```

### PowerShell Script (Windows)

```powershell
# refresh-token.ps1

# Generate new token
$token = gcloud auth print-access-token

# Update .env file
$envPath = ".env"
$content = Get-Content $envPath
$content = $content -replace "VERTEX_ACCESS_TOKEN=.*", "VERTEX_ACCESS_TOKEN=$token"
$content | Set-Content $envPath

Write-Host "Token refreshed! Valid for ~1 hour"
Write-Host "Restart the Flutter app to use new token"
```

Run:
```powershell
.\refresh-token.ps1
```

---

## Cost Considerations

**Vertex AI Search Pricing** (as of 2026):
- **Basic**: $0.002 per query
- **Advanced**: $0.01 per query (with summaries)
- **Data storage**: ~$300/month for 1M documents

**Comparison with RAG**:
- **Gemini RAG**: $0.00125 per request (Pro model)
- **Simpler setup**: No OAuth2 complexity
- **Good for**: Small to medium businesses

**When to use Vertex AI**:
- ✅ Large document corpus (>10,000 docs)
- ✅ Need advanced search features (filters, facets)
- ✅ Enterprise requirements
- ✅ Multi-language support

**When to use RAG**:
- ✅ Focused domain (LHDN compliance)
- ✅ Smaller document set (<1,000 docs)
- ✅ Budget-conscious
- ✅ Simpler development

---

## Security Best Practices

### DO:
- ✅ Use service accounts, not user credentials
- ✅ Rotate access tokens regularly
- ✅ Use backend proxy for production
- ✅ Add `.env` to `.gitignore`
- ✅ Use environment variables for secrets
- ✅ Limit service account permissions (principle of least privilege)

### DON'T:
- ❌ Commit access tokens to Git
- ❌ Share tokens publicly
- ❌ Use long-lived tokens in mobile apps
- ❌ Grant excessive permissions to service accounts
- ❌ Hardcode credentials in source code

---

## Testing Checklist

Before deploying to production:

- [ ] Access token is valid (not expired)
- [ ] Project ID and Data Store ID are correct
- [ ] Service account has necessary permissions
- [ ] `.env` file is in `.gitignore`
- [ ] Error handling works (401, 403, 404)
- [ ] RAG fallback activates when Vertex AI fails
- [ ] Backend proxy is set up (for production)
- [ ] Token refresh mechanism is in place
- [ ] Cost monitoring is configured in GCP
- [ ] API rate limits are understood

---

## Additional Resources

- [Vertex AI Search Documentation](https://cloud.google.com/generative-ai-app-builder/docs/overview)
- [OAuth2 Authentication Guide](https://cloud.google.com/docs/authentication)
- [Service Account Setup](https://cloud.google.com/iam/docs/creating-managing-service-accounts)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference)

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify all environment variables are set correctly
3. Check Google Cloud Console for API status
4. Review logs: `flutter run --verbose`
5. Test with `gcloud` CLI to isolate issues

**Current Status**: The app will automatically fall back to Gemini RAG if Vertex AI is not configured or fails. This provides a seamless user experience while you set up Vertex AI.
