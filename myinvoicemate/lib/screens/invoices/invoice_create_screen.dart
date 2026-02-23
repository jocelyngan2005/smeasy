import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../backend/invoice/models/invoice_model.dart';
import '../../backend/invoice/models/invoice_adapter.dart';
import '../../backend/invoice/services/invoice_service.dart';
import '../../backend/customer/models/customer_model.dart';
import '../../backend/customer/services/customer_service.dart';
import '../../backend/auth/services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../assistant/ai_assistant_screen.dart';

class InvoiceCreateScreen extends StatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceService = InvoiceService();
  final _customerService = CustomerService();
  final _uuid = const Uuid();

  // Invoice Basic Info
  final _invoiceNumberController = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  final _notesController = TextEditingController();

  // Buyer Information
  final _buyerNameController = TextEditingController();
  final _buyerTinController = TextEditingController();
  final _buyerIdNumberController = TextEditingController();
  final _buyerContactController = TextEditingController();
  final _buyerSstController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _buyerAddress1Controller = TextEditingController();
  final _buyerAddress2Controller = TextEditingController();
  final _buyerCityController = TextEditingController();
  final _buyerStateController = TextEditingController();
  final _buyerPostalCodeController = TextEditingController();

  // Seller/Vendor Information (Pre-filled with business info)
  final _sellerNameController = TextEditingController(text: 'My Business');
  final _sellerTinController = TextEditingController(text: 'C00000000000');
  final _sellerIdNumberController = TextEditingController(text: '000000000000');
  final _sellerContactController = TextEditingController(text: '+60123456789');
  final _sellerSstController = TextEditingController(text: 'NA');
  final _sellerEmailController = TextEditingController(text: 'business@example.com');
  final _sellerAddress1Controller = TextEditingController(text: '123 Business Street');
  final _sellerAddress2Controller = TextEditingController();
  final _sellerCityController = TextEditingController(text: 'Kuala Lumpur');
  final _sellerStateController = TextEditingController(text: 'Wilayah Persekutuan');
  final _sellerPostalCodeController = TextEditingController(text: '50000');

  // Line Items
  List<LineItemData> _lineItems = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _generateInvoiceNumber();
    _addLineItem(); // Start with one empty line item
  }

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    _invoiceNumberController.text = 'INV${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.millisecondsSinceEpoch.toString().substring(10)}';
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(LineItemData());
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
      if (_lineItems.isEmpty) {
        _addLineItem(); // Always keep at least one line item
      }
    });
  }

  double _calculateSubtotal() {
    return _lineItems.fold(0.0, (sum, item) => sum + item.getSubtotal());
  }

  double _calculateTaxAmount() {
    return _lineItems.fold(0.0, (sum, item) => sum + item.getTaxAmount());
  }

  double _calculateTotal() {
    return _lineItems.fold(0.0, (sum, item) => sum + item.getTotal());
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      Helpers.showErrorSnackbar(context, 'Please fill in all required fields');
      return;
    }

    // Validate line items
    for (var item in _lineItems) {
      if (!item.isValid()) {
        Helpers.showErrorSnackbar(context, 'Please complete all line item details');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final lineItems = _lineItems.map((item) {
        return InvoiceLineItemHelper.createSimple(
          description: item.descriptionController.text,
          quantity: double.parse(item.quantityController.text),
          unitPrice: double.parse(item.unitPriceController.text),
          taxRate: item.taxRate,
          unit: item.unit,
        );
      }).toList();

      final invoice = InvoiceBuilder.fromSimpleData(
        id: _uuid.v4(),
        invoiceNumber: _invoiceNumberController.text,
        sellerId: 'user123',
        sellerName: _sellerNameController.text,
        sellerTin: _sellerTinController.text,
        sellerIdentificationNumber: _sellerIdNumberController.text,
        sellerContactNumber: _sellerContactController.text,
        sellerSstNumber: _sellerSstController.text,
        sellerEmail: _sellerEmailController.text,
        sellerAddress1: _sellerAddress1Controller.text,
        sellerAddress2: _sellerAddress2Controller.text.isNotEmpty ? _sellerAddress2Controller.text : null,
        sellerCity: _sellerCityController.text,
        sellerState: _sellerStateController.text,
        sellerPostalCode: _sellerPostalCodeController.text,
        buyerId: '',
        buyerName: _buyerNameController.text,
        buyerTin: _buyerTinController.text,
        buyerIdentificationNumber: _buyerIdNumberController.text.isNotEmpty ? _buyerIdNumberController.text : null,
        buyerContactNumber: _buyerContactController.text,
        buyerSstNumber: _buyerSstController.text.isNotEmpty ? _buyerSstController.text : null,
        buyerEmail: _buyerEmailController.text.isNotEmpty ? _buyerEmailController.text : null,
        buyerAddress1: _buyerAddress1Controller.text,
        buyerAddress2: _buyerAddress2Controller.text.isNotEmpty ? _buyerAddress2Controller.text : null,
        buyerCity: _buyerCityController.text,
        buyerState: _buyerStateController.text,
        buyerPostalCode: _buyerPostalCodeController.text,
        issueDate: _issueDate,
        dueDate: _dueDate,
        lineItems: lineItems,
        subtotal: _calculateSubtotal(),
        taxAmount: _calculateTaxAmount(),
        totalAmount: _calculateTotal(),
        status: AppConstants.statusDraft,
        createdBy: 'user123',
        source: InvoiceSource.manual,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await _invoiceService.createInvoice(invoice);

      if (mounted) {
        Helpers.showSuccessSnackbar(context, 'Invoice created successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackbar(context, 'Failed to create invoice: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _notesController.dispose();
    _buyerNameController.dispose();
    _buyerTinController.dispose();
    _buyerIdNumberController.dispose();
    _buyerContactController.dispose();
    _buyerSstController.dispose();
    _buyerEmailController.dispose();
    _buyerAddress1Controller.dispose();
    _buyerAddress2Controller.dispose();
    _buyerCityController.dispose();
    _buyerStateController.dispose();
    _buyerPostalCodeController.dispose();
    _sellerNameController.dispose();
    _sellerTinController.dispose();
    _sellerIdNumberController.dispose();
    _sellerContactController.dispose();
    _sellerSstController.dispose();
    _sellerEmailController.dispose();
    _sellerAddress1Controller.dispose();
    _sellerAddress2Controller.dispose();
    _sellerCityController.dispose();
    _sellerStateController.dispose();
    _sellerPostalCodeController.dispose();
    for (var item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Create Invoice', style: TextStyle(color: Colors.black)),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AIAssistantScreen(),
                  ),
                );
              },
              tooltip: 'AI Assistant',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInvoiceInfoSection(),
            const SizedBox(height: 16),
            _buildBuyerInfoSection(),
            const SizedBox(height: 16),
            _buildSellerInfoSection(),
            const SizedBox(height: 16),
            _buildLineItemsSection(),
            const SizedBox(height: 16),
            _buildTotalsSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceInfoSection() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _invoiceNumberController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Invoice Number (Auto-generated)',
                prefixIcon: const Icon(Icons.numbers),
                suffixIcon: const Icon(Icons.lock, size: 16, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Issue Date *'),
              subtitle: Text(Helpers.formatDate(_issueDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _issueDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _issueDate = date);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Due Date (Optional)'),
              subtitle: Text(_dueDate != null ? Helpers.formatDate(_dueDate!) : 'Not set'),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? _issueDate.add(const Duration(days: 30)),
                  firstDate: _issueDate,
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: const Icon(Icons.note),
                hintStyle: TextStyle(color: Colors.grey[100]),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerInfoSection() {
    return Card(
      elevation: 0,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Buyer Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _importCustomer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.person_search, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Import',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _buyerNameController,
                    decoration: InputDecoration(
                      labelText: 'Buyer Name *',
                      prefixIcon: const Icon(Icons.person),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Buyer name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerTinController,
                    decoration: InputDecoration(
                      labelText: 'TIN (Tax Identification Number) *',
                      prefixIcon: const Icon(Icons.badge),
                      hintText: 'e.g., C00000000000',
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'TIN is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerIdNumberController,
                    decoration: InputDecoration(
                      labelText: 'ID Number (MyKad/Passport)',
                      prefixIcon: const Icon(Icons.credit_card),
                      hintText: 'Leave blank to use default',
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerContactController,
                    decoration: InputDecoration(
                      labelText: 'Contact Number *',
                      prefixIcon: const Icon(Icons.phone),
                      hintText: '+60123456789',
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Contact number is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerSstController,
                    decoration: InputDecoration(
                      labelText: 'SST Number',
                      prefixIcon: const Icon(Icons.assignment),
                      hintText: 'Enter NA if not registered',
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerEmailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Buyer Address',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerAddress1Controller,
                    decoration: InputDecoration(
                      labelText: 'Address Line 1 *',
                      prefixIcon: const Icon(Icons.location_on),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerAddress2Controller,
                    decoration: InputDecoration(
                      labelText: 'Address Line 2',
                      prefixIcon: const Icon(Icons.location_on),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _buyerCityController,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            prefixIcon: const Icon(Icons.location_city),
                            hintStyle: TextStyle(color: Colors.grey[100]),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'City is required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _buyerPostalCodeController,
                          decoration: InputDecoration(
                            labelText: 'Postal Code *',
                            prefixIcon: const Icon(Icons.markunread_mailbox),
                            hintStyle: TextStyle(color: Colors.grey[100]),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Postal code is required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buyerStateController,
                    decoration: InputDecoration(
                      labelText: 'State *',
                      prefixIcon: const Icon(Icons.map),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'State is required' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerInfoSection() {
    return Card(
      elevation: 0,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text(
            'Seller Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _sellerNameController,
                    decoration: InputDecoration(
                      labelText: 'Business Name *',
                      prefixIcon: const Icon(Icons.business),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Business name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellerTinController,
                    decoration: InputDecoration(
                      labelText: 'TIN *',
                      prefixIcon: const Icon(Icons.badge),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'TIN is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellerContactController,
                    decoration: InputDecoration(
                      labelText: 'Contact Number *',
                      prefixIcon: const Icon(Icons.phone),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Contact number is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellerEmailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Business Address',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellerAddress1Controller,
                    decoration: InputDecoration(
                      labelText: 'Address Line 1 *',
                      prefixIcon: const Icon(Icons.location_on),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellerAddress2Controller,
                    decoration: InputDecoration(
                      labelText: 'Address Line 2',
                      prefixIcon: const Icon(Icons.location_on),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sellerCityController,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            prefixIcon: const Icon(Icons.location_city),
                            hintStyle: TextStyle(color: Colors.grey[100]),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'City is required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _sellerPostalCodeController,
                          decoration: InputDecoration(
                            labelText: 'Postal Code *',
                            prefixIcon: const Icon(Icons.markunread_mailbox),
                            hintStyle: TextStyle(color: Colors.grey[100]),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Postal code is required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellerStateController,
                    decoration: InputDecoration(
                      labelText: 'State *',
                      prefixIcon: const Icon(Icons.map),
                      hintStyle: TextStyle(color: Colors.grey[100]),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'State is required' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Line Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _addLineItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lineItems.length,
              separatorBuilder: (_, __) => const Divider(height: 32),
              itemBuilder: (context, index) {
                return _buildLineItemCard(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemCard(int index) {
    final item = _lineItems[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Item ${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (_lineItems.length > 1)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeLineItem(index),
                tooltip: 'Remove Item',
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: item.descriptionController,
          decoration: InputDecoration(
            labelText: 'Description *',
            prefixIcon: const Icon(Icons.description),
            hintStyle: TextStyle(color: Colors.grey[100]),
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Description is required' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: item.quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  prefixIcon: const Icon(Icons.production_quantity_limits),
                  hintStyle: TextStyle(color: Colors.grey[100]),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(value!) == null) return 'Invalid';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                value: item.unit,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  hintStyle: TextStyle(color: Colors.grey[100]),
                ),
                items: ['pcs', 'kg', 'hour', 'day', 'box', 'set']
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => item.unit = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: item.unitPriceController,
                decoration: InputDecoration(
                  labelText: 'Unit Price (RM) *',
                  prefixIcon: const Icon(Icons.attach_money),
                  hintStyle: TextStyle(color: Colors.grey[100]),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(value!) == null) return 'Invalid';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<double?>(
                value: item.taxRate,
                decoration: InputDecoration(
                  labelText: 'Tax Rate',
                  hintStyle: TextStyle(color: Colors.grey[100]),
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('None', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 0.0, child: Text('0%', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 6.0, child: Text('6%', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 10.0, child: Text('10%', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) {
                  setState(() => item.taxRate = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:'),
                  Text(
                    Helpers.formatCurrency(item.getSubtotal()),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (item.taxRate != null && item.taxRate! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tax (${item.taxRate}%):'),
                    Text(
                      Helpers.formatCurrency(item.getTaxAmount()),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    Helpers.formatCurrency(item.getTotal()),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsSection() {
    final subtotal = _calculateSubtotal();
    final taxAmount = _calculateTaxAmount();
    final total = _calculateTotal();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal:',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  Helpers.formatCurrency(subtotal),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tax:',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  Helpers.formatCurrency(taxAmount),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  Helpers.formatCurrency(total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (total >= AppConstants.rm10kThreshold)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This invoice exceeds RM10,000 and requires MyInvois submission',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: _isSaving ? null : const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaving ? null : Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Invoice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleCancel() async {
    // Check if any data has been entered
    final hasData = _buyerNameController.text.isNotEmpty ||
        _buyerTinController.text.isNotEmpty ||
        _lineItems.any((item) => item.descriptionController.text.isNotEmpty);

    if (!hasData) {
      Navigator.pop(context);
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Draft?'),
        content: const Text(
          'You have unsaved changes. Would you like to save this invoice as a draft before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Continue Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'draft'),
            child: const Text('Save as Draft'),
          ),
        ],
      ),
    );

    if (result == 'discard') {
      if (mounted) Navigator.pop(context);
    } else if (result == 'draft') {
      await _saveInvoice();
    }
    // If 'cancel', do nothing (continue editing)
  }

  void _importCustomer() async {
    final userId = AuthService.instance.currentUserId;
    final customers = await _customerService.getCustomers(userId: userId);

    if (!mounted) return;

    if (customers.isEmpty) {
      Helpers.showErrorSnackbar(
        context,
        'No customers found. Add customers first from the Customers screen.',
      );
      return;
    }

    final selectedCustomer = await showDialog<Customer>(
      context: context,
      builder: (context) => _CustomerSelectionDialog(customers: customers),
    );

    if (selectedCustomer != null) {
      setState(() {
        _buyerNameController.text = selectedCustomer.name;
        _buyerTinController.text = selectedCustomer.tin ?? '';
        _buyerIdNumberController.text = selectedCustomer.identificationNumber ?? '';
        _buyerContactController.text = selectedCustomer.contactNumber ?? '';
        _buyerSstController.text = selectedCustomer.sstNumber ?? '';
        _buyerEmailController.text = selectedCustomer.email ?? '';

        if (selectedCustomer.addresses.isNotEmpty) {
          final address = selectedCustomer.addresses.first;
          _buyerAddress1Controller.text = address.line1;
          _buyerAddress2Controller.text = address.line2 ?? '';
          _buyerCityController.text = address.city;
          _buyerStateController.text = address.state;
          _buyerPostalCodeController.text = address.postalCode;
        }
      });

      Helpers.showSuccessSnackbar(context, 'Customer info imported successfully');
    }
  }
}

class LineItemData {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();
  String unit = 'pcs';
  double? taxRate;

  double getQuantity() => double.tryParse(quantityController.text) ?? 0.0;
  double getUnitPrice() => double.tryParse(unitPriceController.text) ?? 0.0;
  double getSubtotal() => getQuantity() * getUnitPrice();
  double getTaxAmount() => taxRate != null ? getSubtotal() * (taxRate! / 100) : 0.0;
  double getTotal() => getSubtotal() + getTaxAmount();

  bool isValid() {
    return descriptionController.text.isNotEmpty &&
        quantityController.text.isNotEmpty &&
        unitPriceController.text.isNotEmpty &&
        getQuantity() > 0 &&
        getUnitPrice() > 0;
  }

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }
}

class _CustomerSelectionDialog extends StatefulWidget {
  final List<Customer> customers;

  const _CustomerSelectionDialog({required this.customers});

  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = widget.customers;
      } else {
        _filteredCustomers = widget.customers.where((customer) {
          return customer.name.toLowerCase().contains(query) ||
              (customer.tin?.toLowerCase().contains(query) ?? false) ||
              (customer.email?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Customer',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? Center(
                      child: Text(
                        'No customers found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, customer),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (customer.tin != null)
                                    Text(
                                      'TIN: ${customer.tin}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (customer.email != null)
                                    Text(
                                      customer.email!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (customer.addresses.isNotEmpty)
                                    Text(
                                      '${customer.addresses.first.city}, ${customer.addresses.first.state}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
