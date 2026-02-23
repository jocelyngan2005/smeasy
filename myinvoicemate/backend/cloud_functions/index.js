// Cloud Functions for automated BigQuery sync
// Deploy: firebase deploy --only functions

const functions = require('firebase-functions');
const {BigQuery} = require('@google-cloud/bigquery');
const admin = require('firebase-admin');

admin.initializeApp();
const bigquery = new BigQuery();

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
