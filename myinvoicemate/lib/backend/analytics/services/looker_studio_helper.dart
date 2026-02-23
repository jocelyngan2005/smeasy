/// Looker Studio Integration Helper
///
/// Provides utilities for connecting MyInvoisMate data to Looker Studio
/// for advanced visualization and reporting.
class LookerStudioHelper {
  // Your Google Cloud Project ID
  static const String projectId = 'myinvoicemate';
  static const String datasetId = 'myinvoicemate_analytics';

  /// SQL queries for Looker Studio data sources
  static const String invoicesDashboardQuery = '''
    SELECT
      DATE(issue_date) as date,
      invoice_number,
      total_amount,
      currency,
      compliance_status,
      buyer_name,
      buyer_tin,
      supplier_name,
      tax_total,
      line_items_count,
      DATE_DIFF(CURRENT_DATE(), DATE(issue_date), DAY) as days_outstanding,
      CASE
        WHEN compliance_status IN ('submitted', 'accepted') THEN 'Compliant'
        WHEN total_amount >= 10000 AND compliance_status NOT IN ('submitted', 'accepted') 
             AND DATE_DIFF(CURRENT_DATE(), DATE(issue_date), DAY) > 3 THEN 'Overdue'
        WHEN total_amount >= 10000 THEN 'Pending'
        ELSE 'N/A'
      END as compliance_risk
    FROM `$projectId.$datasetId.invoices`
    WHERE user_id = @USER_ID
    ORDER BY issue_date DESC
  ''';

  static const String revenueTrendQuery = '''
    SELECT
      FORMAT_DATE('%Y-%m', DATE(issue_date)) as month,
      COUNT(*) as invoice_count,
      SUM(total_amount) as total_revenue,
      AVG(total_amount) as avg_invoice_value,
      SUM(tax_total) as total_tax_collected,
      COUNTIF(compliance_status IN ('submitted', 'accepted')) as compliant_count,
      COUNTIF(compliance_status NOT IN ('submitted', 'accepted') 
              AND total_amount >= 10000) as pending_compliance
    FROM `$projectId.$datasetId.invoices`
    WHERE user_id = @USER_ID
      AND DATE(issue_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
    GROUP BY month
    ORDER BY month DESC
  ''';

  static const String customerAnalysisQuery = '''
    SELECT
      buyer_name,
      buyer_tin,
      COUNT(*) as total_invoices,
      SUM(total_amount) as lifetime_value,
      AVG(total_amount) as avg_transaction,
      MAX(issue_date) as last_invoice_date,
      DATE_DIFF(CURRENT_DATE(), DATE(MAX(issue_date)), DAY) as days_since_last_invoice,
      CASE
        WHEN DATE_DIFF(CURRENT_DATE(), DATE(MAX(issue_date)), DAY) > 90 THEN 'At Risk'
        WHEN DATE_DIFF(CURRENT_DATE(), DATE(MAX(issue_date)), DAY) > 60 THEN 'Warning'
        ELSE 'Active'
      END as customer_status
    FROM `$projectId.$datasetId.invoices`
    WHERE user_id = @USER_ID
    GROUP BY buyer_name, buyer_tin
    ORDER BY lifetime_value DESC
  ''';

  static const String complianceReportQuery = '''
    SELECT
      DATE(issue_date) as date,
      compliance_status,
      COUNT(*) as count,
      SUM(total_amount) as total_value,
      COUNTIF(total_amount >= 10000) as requires_submission,
      COUNTIF(total_amount >= 10000 
              AND compliance_status NOT IN ('submitted', 'accepted')
              AND DATE_DIFF(CURRENT_DATE(), DATE(issue_date), DAY) > 3) as overdue_count,
      COUNTIF(buyer_tin IS NULL OR buyer_tin = '') as missing_tin_count
    FROM `$projectId.$datasetId.invoices`
    WHERE user_id = @USER_ID
      AND DATE(issue_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)
    GROUP BY date, compliance_status
    ORDER BY date DESC
  ''';

  /// Dashboard configuration for different business views
  static final Map<String, DashboardConfig> dashboardTemplates = {
    'executive': DashboardConfig(
      name: 'Executive Dashboard',
      description: 'High-level KPIs and trends',
      queries: [revenueTrendQuery, customerAnalysisQuery],
      refreshRate: 'Daily',
    ),
    'compliance': DashboardConfig(
      name: 'MyInvois Compliance Monitor',
      description: 'Track e-invoice submission compliance',
      queries: [complianceReportQuery, invoicesDashboardQuery],
      refreshRate: 'Hourly',
    ),
    'sales': DashboardConfig(
      name: 'Sales Analytics',
      description: 'Revenue and customer insights',
      queries: [revenueTrendQuery, customerAnalysisQuery],
      refreshRate: 'Daily',
    ),
  };

  /// Generate Looker Studio connection URL
  static String getConnectionUrl() {
    return 'https://lookerstudio.google.com/datasources/create?'
        'connectorId=BigQuery&'
        'projectId=$projectId&'
        'datasetId=$datasetId';
  }

  /// Get dashboard template URL with pre-configured settings
  static String getDashboardTemplateUrl(String templateType) {
    final template = dashboardTemplates[templateType];
    if (template == null) return getConnectionUrl();

    // This would be a shared Looker Studio template
    return 'https://lookerstudio.google.com/reporting/create?'
        'c.reportId=TEMPLATE_ID&'
        'r.reportName=${Uri.encodeComponent(template.name)}';
  }

  /// Export instructions for users
  static const String setupInstructions = '''
# Looker Studio Setup Guide

## Step 1: Enable BigQuery Export
1. In MyInvoisMate, go to Settings > Integrations
2. Enable "BigQuery Export"
3. Your data will sync automatically every hour

## Step 2: Connect to Looker Studio
1. Visit: https://lookerstudio.google.com
2. Create a new data source
3. Select "BigQuery" as the connector
4. Choose project: $projectId
5. Select dataset: $datasetId
6. Choose the "invoices" table

## Step 3: Create Your Dashboard
1. Click "Create" > "Report"
2. Add your connected data source
3. Use our pre-built templates or create custom visualizations

## Recommended Visualizations:
- Time series: Revenue trend over time
- Pie chart: Invoice status breakdown
- Table: Top customers by revenue
- Scorecard: Compliance rate, total revenue
- Geo map: Revenue by buyer location (if available)

## Need Help?
Visit our documentation: https://myinvoicemate.com/docs/looker-studio
''';
}

/// Configuration for a Looker Studio dashboard template
class DashboardConfig {
  final String name;
  final String description;
  final List<String> queries;
  final String refreshRate;

  const DashboardConfig({
    required this.name,
    required this.description,
    required this.queries,
    required this.refreshRate,
  });
}
