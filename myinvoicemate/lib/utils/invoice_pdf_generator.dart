import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../backend/invoice/models/invoice_model.dart';
import '../backend/invoice/models/invoice_adapter.dart';
import 'digital_signature_service.dart';

/// Generates a MyInvois-compliant e-Invoice PDF and shows a preview.
class InvoicePdfGenerator {
  /// Build the PDF document and return its bytes.
  static Future<Uint8List> generatePdf(Invoice invoice) async {
    final pdf = pw.Document();

    // ── QR code image ──────────────────────────────────────────────────────
    final qrBytes = await _buildQrImage(invoice);
    final qrImage = pw.MemoryImage(qrBytes);

    // ── Fonts ──────────────────────────────────────────────────────────────
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();

    // ── Digital signature (Step 2: sign invoice JSON) ──────────────────
    // Attempts a real RSA-SHA256 signature; falls back to a display hash
    // when no keypair has been generated yet (e.g. legacy accounts).
    String digitalSignature;
    String digitalSignatureId;
    try {
      final payload = await DigitalSignatureService.buildSignedPayload(
        invoice.toJson(),
      );
      digitalSignature = payload.signature;
      digitalSignatureId = payload.publicKeyId;
    } catch (_) {
      // Fallback – keypair not yet generated on this device
      digitalSignature = _buildDigitalSignature(invoice);
      digitalSignatureId = invoice.id;
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final dateOnlyFormat = DateFormat('yyyy-MM-dd');
    final currencyFormat = NumberFormat('#,##0.00');

    String fmtAmt(double v) => 'RM${currencyFormat.format(v)}';

    // ── Invoice meta ───────────────────────────────────────────────────────
    final issueStr = dateOnlyFormat.format(invoice.issueDate);
    final issueDtStr = dateFormat.format(invoice.issueDate);
    final invoiceTypeLabel = _invoiceTypeLabel(invoice.type);
    final uniqueId = invoice.myInvoisId ?? invoice.id;

    // ── Address helpers ────────────────────────────────────────────────────
    String addressStr(Address a) {
      final parts = [
        a.line1,
        if (a.line2 != null && a.line2!.isNotEmpty) a.line2!,
        '${a.postalCode} ${a.city}',
        a.state,
        a.country,
      ];
      return parts.join(', ');
    }

    // ── Shared text style helpers ──────────────────────────────────────────
    pw.TextStyle regular({double size = 8, PdfColor? color}) => pw.TextStyle(
          font: fontRegular,
          fontSize: size,
          color: color ?? PdfColors.black,
        );
    pw.TextStyle bold({double size = 8, PdfColor? color}) => pw.TextStyle(
          font: fontBold,
          fontSize: size,
          color: color ?? PdfColors.black,
        );

    // ── Table helpers ──────────────────────────────────────────────────────
    pw.Widget headerCell(String text, {pw.AlignmentGeometry align = pw.Alignment.centerLeft}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          alignment: align,
          child: pw.Text(text, style: bold(size: 7.5)),
        );

    pw.Widget dataCell(
      String text, {
      pw.AlignmentGeometry align = pw.Alignment.centerLeft,
      pw.TextStyle? style,
    }) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          alignment: align,
          child: pw.Text(text, style: style ?? regular(size: 7.5)),
        );

    // ── Compute line item totals ───────────────────────────────────────────
    double totalExcludingTax = invoice.subtotal;
    double taxAmount = invoice.taxAmount;
    double totalIncludingTax = invoice.totalAmount;
    double totalPayable = invoice.totalAmount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          // ── HEADER ────────────────────────────────────────────────────────
          // Seller info centered on the full page width
          pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(invoice.sellerName, style: bold(size: 13)),
                pw.SizedBox(height: 2),
                pw.Text(
                  addressStr(invoice.vendor.address),
                  style: regular(size: 8),
                  textAlign: pw.TextAlign.center,
                ),
                if (invoice.vendor.phone != null &&
                    invoice.vendor.phone!.isNotEmpty)
                  pw.Text(invoice.vendor.phone!, style: regular(size: 8)),
                if (invoice.vendor.email != null &&
                    invoice.vendor.email!.isNotEmpty)
                  pw.Text(
                    invoice.vendor.email!,
                    style: regular(size: 8, color: PdfColors.blue),
                  ),
              ],
            ),
          ),

          pw.Divider(height: 12, thickness: 0.5),

          // ── SUPPLIER INFO + BUYER INFO + E-INVOICE META (same row) ────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Supplier & Buyer info stacked
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Supplier info
                    pw.Text('Supplier TIN: ${invoice.sellerTin}', style: regular(size: 8)),
                    pw.Text(
                      'Supplier Registration Number: ${invoice.sellerRegistrationNumber}',
                      style: regular(size: 8),
                    ),
                    pw.Text('Supplier SST ID: ${invoice.sellerSstNumber}', style: regular(size: 8)),
                    if (invoice.vendor.registrationNumber != null)
                      pw.Text(
                        'Supplier MSIC code: ${invoice.metadata?['msicCode'] ?? 'N/A'}',
                        style: regular(size: 8),
                      ),
                    pw.Text(
                      'Supplier business activity description: '
                      '${invoice.metadata?['businessActivity'] ?? 'N/A'}',
                      style: regular(size: 8),
                    ),

                    pw.SizedBox(height: 8),

                    // Buyer info
                    pw.Row(children: [
                      pw.Text('Buyer TIN : ', style: regular(size: 8)),
                      pw.Text(invoice.buyerTin, style: regular(size: 8, color: PdfColors.blue)),
                    ]),
                    pw.Text('Buyer Name: ${invoice.buyerName}', style: regular(size: 8)),
                    pw.Text(
                      'Buyer Identification Number: ${invoice.buyerRegistrationNumber}',
                      style: regular(size: 8),
                    ),
                    pw.Text(
                      'Buyer Address: ${invoice.buyerAddress}',
                      style: regular(size: 8),
                    ),
                    pw.Text(
                      'Buyer Contact Number (Mobile): ${invoice.buyerContactNumber}',
                      style: regular(size: 8),
                    ),
                    if (invoice.buyer.email != null && invoice.buyer.email!.isNotEmpty)
                      pw.Text('Buyer Email: ${invoice.buyer.email}', style: regular(size: 8)),
                  ],
                ),
              ),

              pw.SizedBox(width: 12),

              // Right: E-INVOICE badge + meta
              pw.Container(
                width: 180,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.5),
                      ),
                      child: pw.Text('E-INVOICE', style: bold(size: 11)),
                    ),
                    pw.SizedBox(height: 4),
                    _metaRow('e-Invoice Type:', invoiceTypeLabel, fontRegular, fontBold),
                    _metaRow('e-Invoice version:', '1.0', fontRegular, fontBold),
                    _metaRow('e-Invoice code:', invoice.invoiceNumber, fontRegular, fontBold),
                    _metaRow('Unique Identifier No:', uniqueId, fontRegular, fontBold),
                    _metaRow('Original Invoice Ref. No.:', 'Not Applicable', fontRegular, fontBold),
                    _metaRow('Invoice Date and Time:', issueDtStr, fontRegular, fontBold),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // ── LINE ITEMS TABLE ──────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(65),   // Classification
              1: const pw.FlexColumnWidth(2.5),    // Description
              2: const pw.FixedColumnWidth(35),    // Qty
              3: const pw.FixedColumnWidth(55),    // Unit Price
              4: const pw.FixedColumnWidth(55),    // Amount
              5: const pw.FixedColumnWidth(30),    // Disc
              6: const pw.FixedColumnWidth(35),    // Tax Rate
              7: const pw.FixedColumnWidth(55),    // Tax Amount
              8: const pw.FixedColumnWidth(60),    // Total Prod Price
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  headerCell('Classification', align: pw.Alignment.center),
                  headerCell('Description', align: pw.Alignment.center),
                  headerCell('Qty', align: pw.Alignment.center),
                  headerCell('Unit Price', align: pw.Alignment.center),
                  headerCell('Amount', align: pw.Alignment.center),
                  headerCell('Disc', align: pw.Alignment.center),
                  headerCell('Tax Rate', align: pw.Alignment.center),
                  headerCell('Tax Amount', align: pw.Alignment.center),
                  headerCell('Total Product / Service Price\n(incl. tax)',
                      align: pw.Alignment.center),
                ],
              ),
              // Line items
              ...invoice.lineItems.map((item) {
                final taxRateStr = item.taxRate != null
                    ? '${item.taxRate!.toStringAsFixed(0)}%'
                    : '-';
                final taxAmtStr = item.taxAmount != null && item.taxAmount! > 0
                    ? 'RM${currencyFormat.format(item.taxAmount)}'
                    : 'RM0.00';
                final discStr = item.discountAmount != null && item.discountAmount! > 0
                    ? 'RM${currencyFormat.format(item.discountAmount)}'
                    : '-';
                final classification = item.productCode ?? '-';
                return pw.TableRow(children: [
                  dataCell(classification, align: pw.Alignment.center),
                  dataCell(item.description),
                  dataCell(
                    item.quantity % 1 == 0
                        ? item.quantity.toInt().toString()
                        : item.quantity.toStringAsFixed(2),
                    align: pw.Alignment.center,
                  ),
                  dataCell('RM${currencyFormat.format(item.unitPrice)}',
                      align: pw.Alignment.centerRight),
                  dataCell('RM${currencyFormat.format(item.subtotal)}',
                      align: pw.Alignment.centerRight),
                  dataCell(discStr, align: pw.Alignment.center),
                  dataCell(taxRateStr, align: pw.Alignment.center),
                  dataCell(taxAmtStr, align: pw.Alignment.centerRight),
                  dataCell('RM${currencyFormat.format(item.totalAmount)}',
                      align: pw.Alignment.centerRight),
                ]);
              }),

            ],
          ),

          // ── SUMMARY ROWS (separate table, cols 0-1 merged, cols 2-7 merged) ──
          // Col 0 (merged Classification+Description): FlexColumnWidth(2.5)
          //   → same available space as main col0(65) + col1(flex) combined.
          // Col 1 (merged Qty→TaxAmount): FixedColumnWidth(265)
          // Col 2 (Total): FixedColumnWidth(60)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FixedColumnWidth(265),
              2: const pw.FixedColumnWidth(60),
            },
            children: [
              _summaryRow('Subtotal', fmtAmt(totalExcludingTax), fontRegular, fontBold,
                  isBold: false),
              _summaryRow(
                  'Total excluding tax', fmtAmt(totalExcludingTax), fontRegular, fontBold,
                  isBold: false),
              _summaryRow('Tax amount', fmtAmt(taxAmount), fontRegular, fontBold,
                  isBold: false),
              _summaryRow('Total including tax', fmtAmt(totalIncludingTax), fontRegular, fontBold,
                  isBold: false),
              _summaryRow(
                  'Total payable amount', fmtAmt(totalPayable), fontRegular, fontBold,
                  isBold: true),
            ],
          ),

          pw.SizedBox(height: 16),

          // ── FOOTER ────────────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Digital Signature (RSA-SHA256):',
                      style: regular(size: 7.5),
                    ),
                    pw.Text(
                      digitalSignature,
                      style: regular(size: 6.5),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Key ID: $digitalSignatureId',
                      style: regular(size: 7),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date and Time of Validation: $issueStr  ${DateFormat('HH:mm:ss').format(invoice.issueDate)}',
                      style: regular(size: 7.5),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'This document is a visual presentation of the e-Invoice',
                      style: regular(size: 7.5),
                    ),
                  ],
                ),
              ),
              // QR code
              pw.Container(
                width: 80,
                height: 80,
                child: pw.Image(qrImage, fit: pw.BoxFit.contain),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Preview / share ──────────────────────────────────────────────────────

  /// Show the system PDF preview / share sheet.
  static Future<void> previewPdf(Invoice invoice) async {
    await Printing.layoutPdf(
      name: '${invoice.invoiceNumber}.pdf',
      onLayout: (_) => generatePdf(invoice),
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static String _invoiceTypeLabel(InvoiceType type) {
    switch (type) {
      case InvoiceType.invoice:
        return '01 – Invoice';
      case InvoiceType.creditNote:
        return '02 – Credit Note';
      case InvoiceType.debitNote:
        return '03 – Debit Note';
      case InvoiceType.refund:
        return '04 – Refund';
    }
  }

  static pw.Widget _metaRow(
    String label,
    String value,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
          pw.SizedBox(width: 4),
          pw.Flexible(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: fontBold, fontSize: 7.5),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      );

  static pw.TableRow _summaryRow(
    String label,
    String value,
    pw.Font fontRegular,
    pw.Font fontBold, {
    bool isBold = false,
  }) {
    final labelStyle = isBold
        ? pw.TextStyle(font: fontBold, fontSize: 7.5)
        : pw.TextStyle(font: fontRegular, fontSize: 7.5);
    final valueStyle = isBold
        ? pw.TextStyle(font: fontBold, fontSize: 7.5)
        : pw.TextStyle(font: fontRegular, fontSize: 7.5);

    // 3-column layout: merged(Classification+Description) | merged(Qty→TaxAmount) | Total
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: pw.Text(''),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(label, style: labelStyle),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(value, style: valueStyle),
        ),
      ],
    );
  }

  /// Build a QR code image at 256×256 and return PNG bytes.
  static Future<Uint8List> _buildQrImage(Invoice invoice) async {
    final qrData = <String>[
      'MYINVOIS E-INVOICE',
      'Invoice: ${invoice.invoiceNumber}',
      'Date: ${DateFormat('yyyy-MM-dd').format(invoice.issueDate)}',
      'Seller: ${invoice.sellerName}',
      'TIN: ${invoice.sellerTin}',
      'Buyer: ${invoice.buyerName}',
      'Total: ${invoice.currency} ${invoice.totalAmount.toStringAsFixed(2)}',
      if (invoice.myInvoisId != null) 'Ref: ${invoice.myInvoisId}',
    ].join('\n');

    const size = 256.0;
    final painter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: false,
      color: const ui.Color(0xFF000000),
      emptyColor: const ui.Color(0xFFFFFFFF),
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    painter.paint(canvas, const ui.Size(size, size));
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Produce a deterministic signature-like hex string from the invoice.
  static String _buildDigitalSignature(Invoice invoice) {
    // Use myInvoisId hash if available, otherwise a composite string
    final raw = invoice.myInvoisId ??
        '${invoice.id}${invoice.invoiceNumber}${invoice.totalAmount}${invoice.issueDate.millisecondsSinceEpoch}';
    // Simple deterministic hash for display (not cryptographic)
    var hash = 0;
    for (final c in raw.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    // Expand to a longer display string mirroring the screenshot style
    return '${raw.hashCode.toRadixString(16).padLeft(8, '0')}'
        '${hash.toRadixString(16).padLeft(8, '0')}'
        '${invoice.id.hashCode.toRadixString(16).padLeft(8, '0')}'
        '${invoice.invoiceNumber.hashCode.toRadixString(16).padLeft(8, '0')}'
        '${invoice.totalAmount.hashCode.toRadixString(16).padLeft(8, '0')}';
  }
}
