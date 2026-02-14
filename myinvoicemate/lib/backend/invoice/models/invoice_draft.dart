import 'package:json_annotation/json_annotation.dart';
import 'invoice_model.dart';

part 'invoice_draft.g.dart';

/// Draft invoice model for AI-generated invoices before finalization
@JsonSerializable(explicitToJson: true)
class InvoiceDraft {
  final String? invoiceNumber;
  final InvoiceType type;
  final DateTime? issueDate;
  final DateTime? dueDate;
  
  // Party Information (may be incomplete)
  final PartyInfoDraft? vendor;
  final PartyInfoDraft? buyer;
  final PartyInfoDraft? shippingRecipient; // Optional, for Annexure to e-Invoice
  
  // Line Items
  final List<InvoiceLineItemDraft> lineItems;
  
  // Calculated fields
  final double? subtotal;
  final double? taxAmount;
  final double? totalAmount;
  
  // AI Metadata
  final String? originalInput; // Original voice/text input
  final double? confidenceScore; // AI confidence (0-1)
  final List<String>? extractedEntities;
  final Map<String, dynamic>? rawAIResponse;
  final InvoiceSource source;
  
  // Validation
  final List<String> missingFields;
  final List<String> warnings;
  final bool isReadyForFinalization;

  InvoiceDraft({
    this.invoiceNumber,
    this.type = InvoiceType.invoice,
    this.issueDate,
    this.dueDate,
    this.vendor,
    this.buyer,
    this.shippingRecipient,
    this.lineItems = const [],
    this.subtotal,
    this.taxAmount,
    this.totalAmount,
    this.originalInput,
    this.confidenceScore,
    this.extractedEntities,
    this.rawAIResponse,
    this.source = InvoiceSource.manual,
    this.missingFields = const [],
    this.warnings = const [],
    this.isReadyForFinalization = false,
  });

  factory InvoiceDraft.fromJson(Map<String, dynamic> json) => _$InvoiceDraftFromJson(json);
  Map<String, dynamic> toJson() => _$InvoiceDraftToJson(this);

  /// Convert draft to final invoice (when all required fields are present)
  Invoice toInvoice({
    required String id,
    required String createdBy,
  }) {
    if (!isReadyForFinalization) {
      throw Exception('Invoice draft is not ready for finalization. Missing fields: ${missingFields.join(", ")}');
    }

    // Calculate totals
    double calcSubtotal = 0;
    double calcTaxAmount = 0;
    
    final finalLineItems = lineItems.map((item) {
      final lineSubtotal = item.quantity * item.unitPrice;
      final lineTaxAmount = (item.taxRate != null ? lineSubtotal * (item.taxRate! / 100) : 0) as double;
      final lineTotal = lineSubtotal + lineTaxAmount - (item.discountAmount ?? 0);
      
      calcSubtotal += lineSubtotal;
      calcTaxAmount += lineTaxAmount;
      
      return InvoiceLineItem(
        id: item.id,
        description: item.description,
        quantity: item.quantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        subtotal: lineSubtotal,
        discountAmount: item.discountAmount,
        taxRate: item.taxRate,
        taxAmount: lineTaxAmount,
        totalAmount: lineTotal,
        productCode: item.productCode,
        taxType: item.taxType,
      );
    }).toList();

    final calcTotal = calcSubtotal + calcTaxAmount;

    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber!,
      type: type,
      issueDate: issueDate ?? DateTime.now(),
      dueDate: dueDate,
      vendor: vendor!.toPartyInfo(),
      buyer: buyer!.toPartyInfo(),
      lineItems: finalLineItems,
      subtotal: calcSubtotal,
      taxAmount: calcTaxAmount,
      totalAmount: calcTotal,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      source: source,
      requiresSubmission: calcTotal >= 10000, // RM10k threshold
      metadata: {
        'ai_confidence': confidenceScore,
        'original_input': originalInput,
      },
    );
  }
}

@JsonSerializable()
class PartyInfoDraft {
  final String? name;
  final String? tin;
  final String? registrationNumber;
  
  // e-Invoice Compliance Fields (LHDN 4.6)
  final String? identificationNumber; // MyKad/MyTentera/Passport/MyPR/MyKAS
  final String? contactNumber; // Required for buyers
  final String? sstNumber; // SST Registration Number
  
  final String? email;
  final String? phone;
  final AddressDraft? address;
  final String? contactPerson;

  PartyInfoDraft({
    this.name,
    this.tin,
    this.registrationNumber,
    this.identificationNumber,
    this.contactNumber,
    this.sstNumber,
    this.email,
    this.phone,
    this.address,
    this.contactPerson,
  });

  factory PartyInfoDraft.fromJson(Map<String, dynamic> json) => _$PartyInfoDraftFromJson(json);
  Map<String, dynamic> toJson() => _$PartyInfoDraftToJson(this);

  PartyInfo toPartyInfo() {
    return PartyInfo(
      name: name!,
      tin: tin,
      registrationNumber: registrationNumber,
      identificationNumber: identificationNumber,
      contactNumber: contactNumber,
      sstNumber: sstNumber,
      email: email,
      phone: phone,
      address: address!.toAddress(),
      contactPerson: contactPerson,
    );
  }
}

@JsonSerializable()
class AddressDraft {
  final String? line1;
  final String? line2;
  final String? line3;
  final String? city;
  final String? state;
  final String? postalCode;
  final String country;

  AddressDraft({
    this.line1,
    this.line2,
    this.line3,
    this.city,
    this.state,
    this.postalCode,
    this.country = 'MY',
  });

  factory AddressDraft.fromJson(Map<String, dynamic> json) => _$AddressDraftFromJson(json);
  Map<String, dynamic> toJson() => _$AddressDraftToJson(this);

  Address toAddress() {
    return Address(
      line1: line1!,
      line2: line2,
      line3: line3,
      city: city!,
      state: state!,
      postalCode: postalCode!,
      country: country,
    );
  }
}

@JsonSerializable()
class InvoiceLineItemDraft {
  final String id;
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double? discountAmount;
  final double? taxRate;
  final String? productCode;
  final TaxType taxType;

  InvoiceLineItemDraft({
    required this.id,
    required this.description,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    this.discountAmount,
    this.taxRate,
    this.productCode,
    this.taxType = TaxType.none,
  });

  factory InvoiceLineItemDraft.fromJson(Map<String, dynamic> json) => _$InvoiceLineItemDraftFromJson(json);
  Map<String, dynamic> toJson() => _$InvoiceLineItemDraftToJson(this);
}
