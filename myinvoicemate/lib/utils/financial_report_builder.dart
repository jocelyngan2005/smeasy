import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../backend/analytics/models/analytics_model.dart';
import 'helpers.dart';

/// Builds an executive-level 5-page monthly financial report [pw.Document].
///
/// Pages:
///   1. Cover Page
///   2. Executive Summary  (Key Metrics Snapshot + Summary Insight)
///   3. Revenue & Cash Flow
///   4. Tax & Compliance
///   5. Risk Alerts & Action Plan
///
/// Usage:
/// ```dart
/// final doc = FinancialReportBuilder.build(
///   businessName: 'Acme Sdn Bhd',
///   period: 'Last 6 months',
///   complianceScore: 92.0,
///   analytics: analyticsData,
///   tax: taxSummaryData,
///   recommendations: aiRecommendations,
/// );
/// await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'report.pdf');
/// ```
class FinancialReportBuilder {
  FinancialReportBuilder._();

  // ── Colour palette (max 3 principal colours + semantic accents) ───────────
  static const _navy = PdfColor(0.18, 0.19, 0.58);  // #2E3193 – brand
  static const _tint = PdfColor(0.93, 0.94, 0.98);  // light navy wash
  static const _risk = PdfColor(0.72, 0.18, 0.13);  // #B72D21 – alert red
  static const _good = PdfColor(0.04, 0.50, 0.26);  // #0A8042 – positive

  // ── Public API ───────────────────────────────────────────────────────────

  /// Builds the PDF document, serialises it and returns the raw bytes.
  ///
  /// Loads Noto Sans (Unicode-capable) as the document theme so that all
  /// glyphs – including special characters – render correctly.
  static Future<List<int>> buildAndSave({
    required String businessName,
    required String period,
    required double complianceScore,
    required AnalyticsData? analytics,
    required TaxSummaryData tax,
    required List<AIRecommendation> recommendations,
  }) async {
    // Load Unicode-capable fonts so glyphs like >= render without warnings.
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();

    final generatedAt = _fmtDateTime(DateTime.now());
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    // ── Page 1: Cover (no running header) ────────────────────────────────
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      build: (_) => _coverPage(businessName, period, generatedAt),
    ));

    // ── Page 2: Executive Summary ─────────────────────────────────────────
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      header: (ctx) => _runningHeader('Executive Summary', ctx.pageNumber),
      build: (_) => _executiveSummaryPage(analytics, tax, complianceScore),
    ));

    // ── Page 3: Revenue & Cash Flow ───────────────────────────────────────
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      header: (ctx) => _runningHeader('Revenue & Cash Flow', ctx.pageNumber),
      build: (_) => _revenuePage(analytics),
    ));

    // ── Page 4: Tax & Compliance ──────────────────────────────────────────
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      header: (ctx) => _runningHeader('Tax & Compliance', ctx.pageNumber),
      build: (_) => _taxCompliancePage(analytics, tax),
    ));

    // ── Page 5: Risk Alerts & Action Plan ────────────────────────────────
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      header: (ctx) => _runningHeader('Risk Alerts & Action Plan', ctx.pageNumber),
      build: (_) => [
        ..._riskPage(analytics, tax, recommendations, complianceScore),
        pw.SizedBox(height: 20),
        _disclaimer(),
      ],
    ));

    return doc.save();
  }

  // ── Running page header ───────────────────────────────────────────────────

  static pw.Widget _runningHeader(String sectionTitle, int pageNumber) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MyInvoisMate - $sectionTitle',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page $pageNumber',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 1 – COVER
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _coverPage(
    String businessName,
    String period,
    String generatedAt,
  ) {
    return [
      // Navy hero banner
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        decoration: pw.BoxDecoration(
          color: _navy,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // App brand mark
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.white, width: 1),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'MyInvoisMate',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 28),

            // Report title
            pw.Text(
              'Monthly Financial Summary',
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              period,
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey200),
            ),
            pw.SizedBox(height: 36),

            // Business name block
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor(0.24, 0.26, 0.68),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Prepared for',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey300),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),


      pw.SizedBox(height: 24),

      // Metadata strip
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: _tint,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          children: [
            _metaItem('Reporting Period', period),
            _verticalDivider(),
            _metaItem('Generated', generatedAt),
            _verticalDivider(),
            _metaItem('System', 'MyInvoisMate AI Platform'),
            _verticalDivider(),
            _metaItem('Compliance', 'LHDN Malaysia - SST / MyInvois'),
          ],
        ),
      ),

      pw.SizedBox(height: 20),

      pw.Text(
        'This is an automatically generated financial summary. '
        'Review with your accountant before making financial or tax decisions.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        textAlign: pw.TextAlign.center,
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 2 – EXECUTIVE SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _executiveSummaryPage(
    AnalyticsData? analytics,
    TaxSummaryData tax,
    double complianceScore,
  ) {
    final totalInvoices =
        analytics?.statusBreakdown.fold(0, (s, e) => s + e.count) ?? 0;
    final validCount = _countByStatus(analytics, 'valid');
    final validationRate = totalInvoices > 0
        ? '${(validCount / totalInvoices * 100).toStringAsFixed(0)}%'
        : '-';
    final revenueGrowth = _revenueGrowthLabel(analytics);
    final outstanding = _estimateOutstanding(analytics);

    final metrics = [
      ['Total Revenue',           Helpers.formatCurrency(analytics?.totalRevenue ?? 0)],
      ['Revenue Growth (MoM)',    revenueGrowth],
      ['SST Collected',           Helpers.formatCurrency(tax.totalTaxCollected)],
      ['Estimated Tax Payable',   Helpers.formatCurrency(tax.estimatedTaxPayable)],
      ['Outstanding Receivables', Helpers.formatCurrency(outstanding)],
      ['Validation Success Rate', validationRate],
      ['Total Invoices',          '$totalInvoices'],
      ['Compliance Score',        '${complianceScore.toStringAsFixed(0)}%'],
    ];

    return [
      _pageTitle('Executive Summary'),
      pw.SizedBox(height: 14),
      _subsectionLabel('Key Metrics Snapshot'),
      pw.SizedBox(height: 8),

      // 2-column metrics grid
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _navy),
            children: [
              _tblCell('Metric', isHeader: true, align: pw.Alignment.centerLeft),
              _tblCell('Value',  isHeader: true),
              _tblCell('Metric', isHeader: true, align: pw.Alignment.centerLeft),
              _tblCell('Value',  isHeader: true),
            ],
          ),
          for (int i = 0; i < metrics.length; i += 2)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: (i ~/ 2).isEven ? PdfColors.white : _tint,
              ),
              children: [
                _tblCell(metrics[i][0], align: pw.Alignment.centerLeft),
                _tblCell(metrics[i][1], isBold: true, color: _navy),
                _tblCell(i + 1 < metrics.length ? metrics[i + 1][0] : '',
                    align: pw.Alignment.centerLeft),
                _tblCell(i + 1 < metrics.length ? metrics[i + 1][1] : '',
                    isBold: true, color: _navy),
              ],
            ),
        ],
      ),

      pw.SizedBox(height: 22),
      _subsectionLabel('Summary Insight'),
      pw.SizedBox(height: 8),
      _insightBox(_buildSummaryInsight(analytics, tax, complianceScore)),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 3 – REVENUE & CASH FLOW
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _revenuePage(AnalyticsData? analytics) {
    final hasTrend    = analytics != null && analytics.salesTrend.isNotEmpty;
    final hasCustomers = analytics != null && analytics.topCustomers.isNotEmpty;

    final paidRevenue  = analytics != null
        ? _countByStatus(analytics, 'valid') * analytics.averageInvoiceValue
        : 0.0;
    final outstanding  = _estimateOutstanding(analytics);
    final totalInvoices =
        analytics?.statusBreakdown.fold(0, (s, e) => s + e.count) ?? 0;
    final avgInvoice   = analytics?.averageInvoiceValue ?? 0.0;

    return [
      _pageTitle('Revenue & Cash Flow'),
      pw.SizedBox(height: 14),

      // ── Revenue Analysis ───────────────────────────────────────────────
      _subsectionLabel('Revenue Analysis'),
      pw.SizedBox(height: 8),

      if (hasTrend) ...[
        pw.TableHelper.fromTextArray(
          headers: ['Month', 'Revenue (RM)', 'MoM Change', 'Share %'],
          data: _salesTrendRows(analytics!),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: _navy),
          oddRowDecoration: pw.BoxDecoration(color: _tint),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerRight,
          cellAlignments: {0: pw.Alignment.centerLeft},
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
        pw.SizedBox(height: 10),
        ..._revenueBullets(analytics),
        pw.SizedBox(height: 16),
      ] else ...[
        _emptyNote('No monthly sales data available for this period.'),
        pw.SizedBox(height: 16),
      ],

      // ── Top Customers ──────────────────────────────────────────────────
      if (hasCustomers) ...[
        _subsectionLabel('Top Customers by Revenue'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Rank', 'Customer', 'Revenue (RM)', 'Share %'],
          data: _topCustomerRows(analytics!),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: _navy),
          oddRowDecoration: pw.BoxDecoration(color: _tint),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerRight,
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
        pw.SizedBox(height: 16),
      ],

      // ── Cash Flow Overview ─────────────────────────────────────────────
      _subsectionLabel('Cash Flow Overview'),
      pw.SizedBox(height: 8),
      pw.SizedBox(
        height: 70,
        child: pw.Row(children: [
          _cashBlock('Total Paid\nInvoices',  Helpers.formatCurrency(paidRevenue), _good),
          pw.SizedBox(width: 8),
          _cashBlock('Outstanding',           Helpers.formatCurrency(outstanding),
              PdfColor(0.80, 0.45, 0.0)),
          pw.SizedBox(width: 8),
          _cashBlock('Total Invoices',        '$totalInvoices', _navy),
          pw.SizedBox(width: 8),
          _cashBlock('Avg Invoice Value',     Helpers.formatCurrency(avgInvoice),
              PdfColors.grey700),
        ]),
      ),
      pw.SizedBox(height: 10),
      _bulletPoint(
          'Paid invoices represent approved (valid) invoices x average invoice value.'),
      _bulletPoint(
          'Outstanding includes draft and pending invoices awaiting approval.'),
      _bulletPoint(
          'Review overdue accounts monthly to maintain a healthy cash cycle.'),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 4 – TAX & COMPLIANCE
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _taxCompliancePage(
    AnalyticsData? analytics,
    TaxSummaryData tax,
  ) {
    final totalInvoices =
        analytics?.statusBreakdown.fold(0, (s, e) => s + e.count) ?? 0;
    final approved =
        _countByStatus(analytics, 'valid') + _countByStatus(analytics, 'submitted');
    final rejected = _countByStatus(analytics, 'invalid');
    final pending  = (totalInvoices - approved - rejected).clamp(0, totalInvoices);

    return [
      _pageTitle('Tax & Compliance'),
      pw.SizedBox(height: 14),

      // ── Tax Summary ────────────────────────────────────────────────────
      _subsectionLabel('Tax Summary - SST (LHDN Malaysia)'),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _navy),
            children: [
              _tblCell('Item',   isHeader: true, align: pw.Alignment.centerLeft),
              _tblCell('Amount', isHeader: true),
            ],
          ),
          _taxRow('Total Taxable Sales',
              Helpers.formatCurrency(tax.totalTaxableSales), false),
          _taxRow('SST Collected',
              Helpers.formatCurrency(tax.totalTaxCollected), true),
          _taxRow('Estimated Tax Payable',
              Helpers.formatCurrency(tax.estimatedTaxPayable), false),
          _taxRow('Audit-Ready Invoices', '${tax.auditReadyCount}', true),
        ],
      ),

      if (tax.monthlyBreakdown.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        _subsectionLabel('Monthly Tax Breakdown'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: [
            'Month', 'Taxable Sales (RM)', 'Tax Collected (RM)',
            'Invoices', 'Effective Rate',
          ],
          data: _taxMonthlyRows(tax),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: _navy),
          oddRowDecoration: pw.BoxDecoration(color: _tint),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerRight,
          cellAlignments: {0: pw.Alignment.centerLeft},
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],

      pw.SizedBox(height: 18),

      // ── MyInvois Validation Status ─────────────────────────────────────
      _subsectionLabel('MyInvois Validation Status'),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _navy),
            children: [
              _tblCell('Status', isHeader: true, align: pw.Alignment.centerLeft),
              _tblCell('Count',  isHeader: true),
              _tblCell('Share',  isHeader: true),
            ],
          ),
          _validationRow('Total Invoices Submitted', totalInvoices, totalInvoices, false),
          _validationRow('Approved (Valid / Submitted)', approved, totalInvoices, true),
          _validationRow('Rejected', rejected, totalInvoices, false),
          _validationRow('Pending',  pending,  totalInvoices, true),
        ],
      ),
      pw.SizedBox(height: 10),
      _bulletPoint(
          'Approved = invoices with "valid" or "submitted" status in MyInvois.'),
      _bulletPoint(
          'Estimated tax payable equals SST collected; input tax credits are not deducted.'),
      _bulletPoint(
          'Consult your tax adviser for final SST filing amounts.'),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 5 – RISK ALERTS & ACTION PLAN
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _riskPage(
    AnalyticsData? analytics,
    TaxSummaryData tax,
    List<AIRecommendation> recommendations,
    double complianceScore,
  ) {
    final risks   = _buildRiskIndicators(analytics, tax, complianceScore);
    final actions = recommendations
        .where((r) => r.priority == 'High' || r.priority == 'Medium')
        .take(6)
        .toList();

    return [
      _pageTitle('Risk Alerts & Action Plan'),
      pw.SizedBox(height: 14),

      // ── Risk Indicators ────────────────────────────────────────────────
      _subsectionLabel('Risk Indicators'),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _risk, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: risks.isEmpty
            ? pw.Text(
                'No significant risk indicators detected for this period.',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey700),
              )
            : pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: risks
                    .map(
                      (r) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          '>> $r',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey800),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),

      pw.SizedBox(height: 18),

      // ── Recommended Actions ────────────────────────────────────────────
      _subsectionLabel('Recommended Actions'),
      pw.SizedBox(height: 8),

      if (actions.isEmpty)
        _emptyNote('No high or medium priority actions at this time.')
      else
        ...actions.map(_actionCard).toList(),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static List<List<String>> _salesTrendRows(AnalyticsData a) {
    final total = a.salesTrend.fold(0.0, (s, e) => s + e.amount);
    return a.salesTrend.asMap().entries.map((entry) {
      final idx  = entry.key;
      final item = entry.value;
      String change = '-';
      if (idx > 0) {
        final prev = a.salesTrend[idx - 1].amount;
        if (prev > 0) {
          final pct = (item.amount - prev) / prev * 100;
          change = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
        }
      }
      final share = total > 0
          ? '${(item.amount / total * 100).toStringAsFixed(1)}%'
          : '-';
      return [item.period, item.amount.toStringAsFixed(2), change, share];
    }).toList();
  }

  static List<List<String>> _topCustomerRows(AnalyticsData a) {
    final total = a.topCustomers.values.fold(0.0, (s, v) => s + v);
    return a.topCustomers.entries
        .toList()
        .asMap()
        .entries
        .map((e) => [
              '#${e.key + 1}',
              e.value.key,
              e.value.value.toStringAsFixed(2),
              total > 0
                  ? '${(e.value.value / total * 100).toStringAsFixed(1)}%'
                  : '0.0%',
            ])
        .toList();
  }

  static List<List<String>> _taxMonthlyRows(TaxSummaryData tax) {
    return tax.monthlyBreakdown.map((e) {
      final rate = e.taxableSales > 0
          ? '${(e.taxCollected / e.taxableSales * 100).toStringAsFixed(1)}%'
          : '-';
      return [
        e.month,
        e.taxableSales.toStringAsFixed(2),
        e.taxCollected.toStringAsFixed(2),
        '${e.invoiceCount}',
        rate,
      ];
    }).toList();
  }

  static int _countByStatus(AnalyticsData? a, String status) {
    if (a == null) return 0;
    for (final s in a.statusBreakdown) {
      if (s.status.toLowerCase() == status.toLowerCase()) return s.count;
    }
    return 0;
  }

  static double _estimateOutstanding(AnalyticsData? a) {
    if (a == null) return 0;
    final pending =
        _countByStatus(a, 'draft') + _countByStatus(a, 'pending');
    return pending * a.averageInvoiceValue;
  }

  static String _revenueGrowthLabel(AnalyticsData? a) {
    if (a == null || a.salesTrend.length < 2) return '-';
    final last = a.salesTrend.last.amount;
    final prev = a.salesTrend[a.salesTrend.length - 2].amount;
    if (prev == 0) return '-';
    final pct = (last - prev) / prev * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
  }

  static String _buildSummaryInsight(
    AnalyticsData? analytics,
    TaxSummaryData tax,
    double complianceScore,
  ) {
    final parts = <String>[];

    // Revenue trend sentence
    if (analytics != null && analytics.salesTrend.length >= 2) {
      final last = analytics.salesTrend.last.amount;
      final prev = analytics.salesTrend[analytics.salesTrend.length - 2].amount;
      if (prev > 0) {
        final pct = (last - prev) / prev * 100;
        if (pct >= 0) {
          parts.add(
              'Revenue grew ${pct.toStringAsFixed(1)}% compared to the prior period, '
              'reflecting positive sales momentum.');
        } else {
          parts.add(
              'Revenue declined ${pct.abs().toStringAsFixed(1)}% versus the prior period. '
              'Review customer activity and invoice collection to identify the cause.');
        }
      }
    }

    // Compliance sentence
    if (complianceScore >= 90) {
      parts.add(
          'Compliance score is strong at ${complianceScore.toStringAsFixed(0)}%. '
          'Continue timely MyInvois submissions to maintain this rating.');
    } else {
      parts.add(
          'Compliance score of ${complianceScore.toStringAsFixed(0)}% is below target. '
          'Ensure all invoices >= RM 10,000 are submitted to MyInvois within 72 hours.');
    }

    // Tax sentence
    if (tax.estimatedTaxPayable > 0) {
      parts.add(
          'Estimated SST payable is ${Helpers.formatCurrency(tax.estimatedTaxPayable)}. '
          'Allocate this amount ahead of the filing deadline to avoid penalties.');
    }

    // Outstanding sentence
    final outstanding = _estimateOutstanding(analytics);
    if (outstanding > 0) {
      parts.add(
          'Outstanding receivables stand at approximately ${Helpers.formatCurrency(outstanding)}. '
          'Follow up with pending accounts to improve cash collection efficiency.');
    }

    return parts.isEmpty
        ? 'Insufficient data to generate an automated summary. '
            'Ensure invoices are recorded in the system and try again.'
        : parts.join('  ');
  }

  static List<pw.Widget> _revenueBullets(AnalyticsData analytics) {
    if (analytics.salesTrend.isEmpty) return [];
    final best   = analytics.salesTrend.reduce((a, b) => a.amount > b.amount ? a : b);
    final growth = _revenueGrowthLabel(analytics);
    final total  = analytics.statusBreakdown.fold(0, (s, e) => s + e.count);

    return [
      _bulletPoint(
          'Best month: ${best.period} with ${Helpers.formatCurrency(best.amount)} in revenue.'),
      _bulletPoint(
          'Month-on-month change (latest vs prior): $growth.'),
      _bulletPoint(
          'Total invoices: $total  |  Average value: ${Helpers.formatCurrency(analytics.averageInvoiceValue)}.'),
    ];
  }

  static List<String> _buildRiskIndicators(
    AnalyticsData? analytics,
    TaxSummaryData tax,
    double complianceScore,
  ) {
    final risks = <String>[];

    if (complianceScore < 80) {
      risks.add(
          'Compliance score (${complianceScore.toStringAsFixed(0)}%) is below the 80% threshold. '
          'Immediate review of pending MyInvois submissions required.');
    }

    final rejected = _countByStatus(analytics, 'invalid');
    if (rejected > 0) {
      risks.add(
          '$rejected invoice(s) rejected by MyInvois. '
          'Correct validation errors and resubmit as soon as possible.');
    }

    final outstanding = _estimateOutstanding(analytics);
    if (outstanding > 0) {
      risks.add(
          'Estimated outstanding receivables of ${Helpers.formatCurrency(outstanding)} '
          'may impact short-term cash flow.');
    }

    if (analytics != null && analytics.salesTrend.length >= 2) {
      final last = analytics.salesTrend.last.amount;
      final prev = analytics.salesTrend[analytics.salesTrend.length - 2].amount;
      if (prev > 0 && (last - prev) / prev < -0.10) {
        risks.add(
            'Revenue declined more than 10% compared to the prior month. '
            'Investigate root cause and review the sales pipeline.');
      }
    }

    if (tax.estimatedTaxPayable > 0) {
      risks.add(
          'SST payable of ${Helpers.formatCurrency(tax.estimatedTaxPayable)} '
          'must be set aside for the upcoming filing period.');
    }

    return risks;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _pageTitle(String title) {
    return pw.Row(children: [
      pw.Container(width: 4, height: 28, color: _navy),
      pw.SizedBox(width: 10),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
    ]);
  }

  static pw.Widget _subsectionLabel(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy),
      ),
    );
  }

  static pw.Widget _insightBox(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _tint,
        border: pw.Border(left: pw.BorderSide(color: _navy, width: 3)),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
        maxLines: 7,
      ),
    );
  }

  static pw.Widget _cashBlock(String label, String value, PdfColor accent) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: pw.BoxDecoration(
          // Non-uniform borders (top-only) cannot be combined with borderRadius
          // in the pdf package – the border and the background are kept separate.
          border: pw.Border(top: pw.BorderSide(color: accent, width: 3)),
          color: _tint,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: accent),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              label,
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _bulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, left: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('-  ',
              style: pw.TextStyle(fontSize: 10, color: _navy)),
          pw.Expanded(
            child: pw.Text(
              text,
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _actionCard(AIRecommendation rec) {
    final isHigh      = rec.priority == 'High';
    final priorityClr = isHigh ? _risk : PdfColor(0.80, 0.45, 0.0);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Priority badge
          pw.Container(
            width: 42,
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            decoration: pw.BoxDecoration(
              color: priorityClr,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              rec.priority.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  rec.title,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  rec.description,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700),
                ),
                if (rec.impact.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(
                      'Impact: ${rec.impact}',
                      style: pw.TextStyle(fontSize: 8, color: _good),
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            rec.category,
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _emptyNote(String note) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Text(
        note,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  // ── Table cell / row builders ─────────────────────────────────────────────

  static pw.Widget _tblCell(
    String text, {
    bool isHeader = false,
    bool isBold   = false,
    PdfColor? color,
    pw.Alignment align = pw.Alignment.centerRight,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: (isHeader || isBold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: isHeader ? PdfColors.white : (color ?? PdfColors.grey800),
          ),
        ),
      ),
    );
  }

  static pw.TableRow _taxRow(String label, String value, bool shaded) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: shaded ? _tint : PdfColors.white),
      children: [
        _tblCell(label, align: pw.Alignment.centerLeft),
        _tblCell(value, isBold: true, color: _navy),
      ],
    );
  }

  static pw.TableRow _validationRow(
      String label, int count, int total, bool shaded) {
    final share =
        total > 0 ? '${(count / total * 100).toStringAsFixed(0)}%' : '-';
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: shaded ? _tint : PdfColors.white),
      children: [
        _tblCell(label, align: pw.Alignment.centerLeft),
        _tblCell('$count', isBold: true),
        _tblCell(share),
      ],
    );
  }

  // ── Generic layout helpers ────────────────────────────────────────────────

  static pw.Widget _metaItem(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _verticalDivider() {
    return pw.Container(
      width: 0.5,
      height: 28,
      color: PdfColors.grey300,
      margin: const pw.EdgeInsets.symmetric(horizontal: 4),
    );
  }

  static pw.Widget _disclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        'DISCLAIMER: This report is generated automatically by MyInvoisMate. '
        'Revenue figures are based on invoices recorded in the system for the selected period. '
        'Estimated tax payable equals SST collected and does not account for input tax credits. '
        'AI-powered recommendations are algorithmically generated. '
        'Consult a qualified accountant or tax adviser before making any financial decisions.',
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
      ),
    );
  }

  // ── Date / time formatting ────────────────────────────────────────────────

  static String _fmtDateTime(DateTime dt) {
    final d   = dt.day.toString().padLeft(2, '0');
    final m   = dt.month.toString().padLeft(2, '0');
    final h   = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $h:$min';
  }
}
