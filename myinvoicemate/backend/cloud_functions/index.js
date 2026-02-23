// Cloud Functions for automated BigQuery sync
// Deploy: firebase deploy --only functions

const functions = require('firebase-functions');
const {BigQuery} = require('@google-cloud/bigquery');
const {PredictionServiceClient} = require('@google-cloud/aiplatform');
const admin = require('firebase-admin');

admin.initializeApp();
const bigquery = new BigQuery();

// Vertex AI configuration
const PROJECT_ID = 'myinvoicemate'; // ⚠️ TODO: Replace with your actual GCP project ID
const LOCATION = 'asia-southeast1';
const MODEL_ID = 'gemini-1.5-flash';

const client = new PredictionServiceClient({
  apiEndpoint: `${LOCATION}-aiplatform.googleapis.com`,
});

const DATASET_ID = 'myinvoicemate_analytics';
const INVOICES_TABLE = 'invoices';
const ANALYTICS_TABLE = 'analytics_cache';

/**
 * Sync invoice to BigQuery on create/update
 */
exports.syncInvoiceToBigQuery = functions.firestore
  .document('invoices/{invoiceId}')
  .onWrite(async (change, context) => {
    try {
      const invoiceId = context.params.invoiceId;
      const invoice = change.after.exists ? change.after.data() : null;

      // Skip if invoice is deleted or doesn't exist
      if (!invoice || invoice.isDeleted) {
        console.log(`Invoice ${invoiceId} deleted or doesn't exist, skipping sync`);
        return null;
      }

      const dataset = bigquery.dataset(DATASET_ID);
      const table = dataset.table(INVOICES_TABLE);

      // Prepare row data
      const row = {
        invoice_id: invoiceId,
        user_id: invoice.createdBy || '',
        invoice_number: invoice.invoiceNumber || '',
        issue_date: invoice.issueDate ? invoice.issueDate.toDate().toISOString() : null,
        total_amount: invoice.totalAmount || 0,
        currency: invoice.currency || 'MYR',
        compliance_status: invoice.complianceStatus || 'draft',
        buyer_name: invoice.buyer?.name || '',
        buyer_tin: invoice.buyer?.tin || '',
        supplier_name: invoice.supplier?.name || '',
        supplier_tin: invoice.supplier?.tin || '',
        tax_total: invoice.taxTotal || 0,
        line_items_count: invoice.lineItems?.length || 0,
        created_at: invoice.createdAt ? invoice.createdAt.toDate().toISOString() : null,
        submitted_at: invoice.submittedAt ? invoice.submittedAt.toDate().toISOString() : null,
        export_timestamp: new Date().toISOString(),
      };

      // Insert row into BigQuery
      await table.insert([row], {
        skipInvalidRows: false,
        ignoreUnknownValues: true,
      });

      console.log(`Invoice ${invoiceId} synced to BigQuery successfully`);
      return null;
    } catch (error) {
      console.error('Error syncing invoice to BigQuery:', error);
      // Don't throw - we don't want to fail the Firestore write
      return null;
    }
  });

/**
 * Sync analytics cache to BigQuery on update
 */
exports.syncAnalyticsCacheToBigQuery = functions.firestore
  .document('analytics_cache/{userId}')
  .onWrite(async (change, context) => {
    try {
      const userId = context.params.userId;
      const analytics = change.after.exists ? change.after.data() : null;

      if (!analytics) {
        console.log(`Analytics cache for ${userId} deleted, skipping sync`);
        return null;
      }

      const dataset = bigquery.dataset(DATASET_ID);
      const table = dataset.table(ANALYTICS_TABLE);

      const row = {
        user_id: userId,
        total_revenue: analytics.totalRevenue || 0,
        total_invoices: analytics.totalInvoices || 0,
        average_invoice_value: analytics.averageInvoiceValue || 0,
        sales_trend: JSON.stringify(analytics.salesTrend || []),
        status_breakdown: JSON.stringify(analytics.statusBreakdown || []),
        top_customers: JSON.stringify(analytics.topCustomers || {}),
        last_updated: analytics.lastUpdated ? 
          analytics.lastUpdated.toDate().toISOString() : 
          new Date().toISOString(),
        export_timestamp: new Date().toISOString(),
      };

      await table.insert([row], {
        skipInvalidRows: false,
        ignoreUnknownValues: true,
      });

      console.log(`Analytics cache for ${userId} synced to BigQuery successfully`);
      return null;
    } catch (error) {
      console.error('Error syncing analytics cache to BigQuery:', error);
      return null;
    }
  });

/**
 * Scheduled function to generate AI recommendations nightly
 * Runs at 2 AM UTC daily
 */
exports.generateNightlyAIRecommendations = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('Starting nightly AI recommendations generation');

      // Get all users
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('isActive', '==', true)
        .get();

      const promises = [];

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        
        // Call AI recommendations generation
        // This would trigger a Cloud Task or HTTP call to your recommendation service
        promises.push(generateRecommendationsForUser(userId));
      }

      await Promise.allSettled(promises);
      console.log(`Generated AI recommendations for ${usersSnapshot.docs.length} users`);
      
      return null;
    } catch (error) {
      console.error('Error generating nightly AI recommendations:', error);
      return null;
    }
  });

/**
 * Helper function to generate recommendations for a specific user
 */
async function generateRecommendationsForUser(userId) {
  try {
    // Get user's business context
    const [invoices, analytics] = await Promise.all([
      admin.firestore()
        .collection('invoices')
        .where('createdBy', '==', userId)
        .where('isDeleted', '==', false)
        .orderBy('issueDate', 'desc')
        .limit(50)
        .get(),
      admin.firestore()
        .collection('analytics_cache')
        .doc(userId)
        .get(),
    ]);

    if (invoices.empty) {
      console.log(`No invoices for user ${userId}, skipping`);
      return;
    }

    // Build analytics summary
    const analyticsData = analytics.exists ? analytics.data() : {};
    
    // Calculate compliance metrics
    let pending = 0, overdue = 0, missingTIN = 0;
    const now = new Date();

    invoices.docs.forEach(doc => {
      const invoice = doc.data();
      const status = invoice.complianceStatus || 'draft';
      const amount = invoice.totalAmount || 0;

      if (status === 'pending') pending++;
      
      if (amount >= 10000 && status !== 'submitted' && status !== 'accepted') {
        const issueDate = invoice.issueDate?.toDate();
        if (issueDate && (now - issueDate) / (1000 * 60 * 60) > 72) {
          overdue++;
        }
      }

      if (!invoice.buyer?.tin) missingTIN++;
    });

    // Generate rule-based recommendations
    const recommendations = [];

    if (overdue > 0) {
      recommendations.push({
        category: 'Compliance',
        priority: 'High',
        title: 'Urgent: Overdue MyInvois Submissions',
        description: `You have ${overdue} invoice(s) ≥ RM10,000 that exceeded the 72-hour submission deadline. Submit immediately to avoid penalties.`,
        impact: 'Avoid fines up to RM50,000 per invoice',
        timestamp: new Date().toISOString(),
      });
    }

    if (pending > 3) {
      recommendations.push({
        category: 'Compliance',
        priority: 'Medium',
        title: 'Review Pending Submissions',
        description: `${pending} invoices are pending MyInvois submission. Review and submit to maintain compliance.`,
        impact: 'Stay compliant with LHDN regulations',
        timestamp: new Date().toISOString(),
      });
    }

    if (missingTIN > 5) {
      recommendations.push({
        category: 'Operations',
        priority: 'Medium',
        title: 'Update Customer TIN Information',
        description: `${missingTIN} invoices have missing buyer TIN numbers. Complete this information for smoother e-invoice processing.`,
        impact: 'Reduce submission errors and delays',
        timestamp: new Date().toISOString(),
      });
    }

    // Revenue insights
    const totalRevenue = analyticsData.totalRevenue || 0;
    const avgInvoice = analyticsData.averageInvoiceValue || 0;

    if (totalRevenue > 0 && avgInvoice < 5000) {
      recommendations.push({
        category: 'Revenue',
        priority: 'Low',
        title: 'Consider Value-Based Pricing',
        description: `Your average invoice is RM${avgInvoice.toFixed(2)}. Consider bundling services or premium offerings to increase transaction value.`,
        impact: 'Potential revenue increase of 20-30%',
        timestamp: new Date().toISOString(),
      });
    }

    // Cache recommendations
    if (recommendations.length > 0) {
      await admin.firestore()
        .collection('ai_recommendations_cache')
        .doc(userId)
        .set({
          recommendations,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`Generated ${recommendations.length} recommendations for user ${userId}`);
    }

  } catch (error) {
    console.error(`Error generating recommendations for user ${userId}:`, error);
  }
}

/**
 * HTTP function to manually trigger BigQuery export for a user
 */
exports.exportUserDataToBigQuery = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;

  try {
    // Get all user's invoices
    const invoicesSnapshot = await admin.firestore()
      .collection('invoices')
      .where('createdBy', '==', userId)
      .where('isDeleted', '==', false)
      .get();

    const dataset = bigquery.dataset(DATASET_ID);
    const table = dataset.table(INVOICES_TABLE);

    const rows = invoicesSnapshot.docs.map(doc => {
      const invoice = doc.data();
      return {
        invoice_id: doc.id,
        user_id: userId,
        invoice_number: invoice.invoiceNumber || '',
        issue_date: invoice.issueDate?.toDate().toISOString() || null,
        total_amount: invoice.totalAmount || 0,
        currency: invoice.currency || 'MYR',
        compliance_status: invoice.complianceStatus || 'draft',
        buyer_name: invoice.buyer?.name || '',
        buyer_tin: invoice.buyer?.tin || '',
        supplier_name: invoice.supplier?.name || '',
        supplier_tin: invoice.supplier?.tin || '',
        tax_total: invoice.taxTotal || 0,
        line_items_count: invoice.lineItems?.length || 0,
        created_at: invoice.createdAt?.toDate().toISOString() || null,
        submitted_at: invoice.submittedAt?.toDate().toISOString() || null,
        export_timestamp: new Date().toISOString(),
      };
    });

    if (rows.length > 0) {
      await table.insert(rows, {
        skipInvalidRows: false,
        ignoreUnknownValues: true,
      });
    }

    return {
      success: true,
      exported: rows.length,
      message: `Successfully exported ${rows.length} invoices to BigQuery`,
    };
  } catch (error) {
    console.error('Error exporting user data to BigQuery:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to export data to BigQuery',
      error.message
    );
  }
});

/**
 * Generate AI recommendations using Vertex AI (Gemini)
 * Called from Flutter app with business context
 */
exports.generateAIRecommendations = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;
  const { businessContext } = data;

  if (!businessContext) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Business context is required'
    );
  }

  try {
    console.log(`🤖 Generating AI recommendations for user: ${userId}`);
    
    // Construct the model path
    const modelPath = client.projectLocationPublisherModelPath(
      PROJECT_ID,
      LOCATION,
      'google',
      MODEL_ID
    );

    // Build the request for Vertex AI
    const request = {
      endpoint: modelPath,
      instances: [
        {
          content: {
            role: 'user',
            parts: [
              {
                text: businessContext
              }
            ]
          }
        }
      ],
      parameters: {
        temperature: 0.4,
        topP: 0.8,
        topK: 40,
        maxOutputTokens: 2048,
      }
    };

    console.log(`🔍 Calling Vertex AI Model: ${modelPath}`);
    
    // Call Vertex AI
    const [response] = await client.predict(request);
    
    if (!response.predictions || response.predictions.length === 0) {
      throw new Error('No predictions returned from Vertex AI');
    }

    const prediction = response.predictions[0];
    const aiResponse = prediction.content?.parts?.[0]?.text || 'No recommendations generated';

    console.log(`✅ AI response received (length: ${aiResponse.length})`);

    // Parse the AI response into structured recommendations
    const recommendations = parseRecommendations(aiResponse);

    // Cache recommendations in Firestore
    await admin.firestore()
      .collection('ai_recommendations_cache')
      .doc(userId)
      .set({
        recommendations: recommendations.map(r => ({
          category: r.category,
          priority: r.priority,
          title: r.title,
          description: r.description,
          impact: r.impact,
          timestamp: new Date().toISOString(),
        })),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        rawResponse: aiResponse,
      });

    console.log(`💾 Cached ${recommendations.length} recommendations for user ${userId}`);

    return {
      success: true,
      recommendations,
      message: `Generated ${recommendations.length} AI recommendations`,
    };

  } catch (error) {
    console.error('Error generating AI recommendations:', error);
    
    // Return fallback recommendations if AI fails
    const fallbackRecommendations = getFallbackRecommendations();
    
    return {
      success: false,
      recommendations: fallbackRecommendations,
      message: 'Using fallback recommendations due to AI service error',
      error: error.message,
    };
  }
});

/**
 * Get cached AI recommendations
 */
exports.getCachedAIRecommendations = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;

  try {
    const doc = await admin.firestore()
      .collection('ai_recommendations_cache')
      .doc(userId)
      .get();

    if (!doc.exists) {
      console.log(`No cached recommendations for user ${userId}, returning fallback`);
      return {
        success: true,
        recommendations: getFallbackRecommendations(),
        cached: false,
        message: 'No cached recommendations found, using fallback',
      };
    }

    const data = doc.data();
    const lastUpdated = data.lastUpdated?.toDate();
    const isStale = !lastUpdated || 
      (Date.now() - lastUpdated.getTime()) > (60 * 60 * 1000); // 1 hour

    if (isStale) {
      console.log(`Cached recommendations for user ${userId} are stale`);
      return {
        success: true,
        recommendations: data.recommendations || getFallbackRecommendations(),
        cached: true,
        stale: true,
        message: 'Cached recommendations are outdated, consider refreshing',
      };
    }

    return {
      success: true,
      recommendations: data.recommendations || [],
      cached: true,
      stale: false,
      lastUpdated: lastUpdated.toISOString(),
      message: 'Retrieved fresh cached recommendations',
    };

  } catch (error) {
    console.error('Error getting cached recommendations:', error);
    return {
      success: false,
      recommendations: getFallbackRecommendations(),
      message: 'Error retrieving recommendations, using fallback',
      error: error.message,
    };
  }
});

/**
 * Parse AI response into structured recommendations
 */
function parseRecommendations(aiResponse) {
  const recommendations = [];
  const lines = aiResponse.split('\n');
  
  let category, priority, title, description, impact;

  for (const line of lines) {
    const trimmed = line.trim();
    
    if (trimmed.startsWith('CATEGORY:')) {
      category = trimmed.substring(9).trim();
    } else if (trimmed.startsWith('PRIORITY:')) {
      priority = trimmed.substring(9).trim();
    } else if (trimmed.startsWith('TITLE:')) {
      title = trimmed.substring(6).trim();
    } else if (trimmed.startsWith('DESCRIPTION:')) {
      description = trimmed.substring(12).trim();
    } else if (trimmed.startsWith('IMPACT:')) {
      impact = trimmed.substring(7).trim();
      
      // Complete recommendation found
      if (category && priority && title) {
        recommendations.push({
          category: category || 'Operations',
          priority: priority || 'Medium',
          title: title || 'General Recommendation',
          description: description || '',
          impact: impact || '',
        });
        
        // Reset for next recommendation
        category = priority = title = description = impact = null;
      }
    }
  }

  return recommendations.length > 0 ? recommendations : getFallbackRecommendations();
}

/**
 * Fallback recommendations when AI is unavailable
 */
function getFallbackRecommendations() {
  return [
    {
      category: 'Compliance',
      priority: 'High',
      title: 'Review Pending MyInvois Submissions',
      description: 'You have invoices ≥ RM10,000 that require MyInvois submission within 72 hours. Review and submit them to avoid penalties.',
      impact: 'Maintain compliance and avoid fines',
    },
    {
      category: 'Revenue',
      priority: 'Medium',
      title: 'Optimize Invoice Timing',
      description: 'Analysis shows better payment rates when invoices are sent on Monday-Wednesday. Consider adjusting your invoicing schedule.',
      impact: 'Improve cash flow by 15-20%',
    },
    {
      category: 'Operations',
      priority: 'Medium',
      title: 'Update Customer TIN Information',
      description: 'Several invoices are missing buyer TIN numbers. Complete this information to ensure seamless e-invoice submission.',
      impact: 'Reduce submission errors',
    },
  ];
}
