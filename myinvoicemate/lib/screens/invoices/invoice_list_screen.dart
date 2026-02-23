import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../backend/auth/services/auth_service.dart';
import '../../backend/invoice/models/invoice_model.dart';
import '../../backend/invoice/models/invoice_adapter.dart';
import '../../backend/invoice/services/firestore_invoice_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'invoice_detail_screen.dart';
import 'invoice_create_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen>
    with SingleTickerProviderStateMixin {
  final _invoiceService = FirestoreInvoiceService();
  final _searchController = TextEditingController();
  late final TabController _tabController;

  List<Invoice> _invoices = [];
  List<Invoice> _filteredSent = [];
  List<Invoice> _filteredReceived = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _searchQuery = '';
  String _userTin = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilter();
    });
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUserId ?? '';

      // After a hot restart the async authStateChanges listener may not have
      // finished populating _currentUser yet, so fall back to the stream if
      // the synchronous cache is empty.
      var cachedUser = authService.currentUser;
      if (cachedUser == null) {
        cachedUser = await authService.userStream.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      }
      _userTin = cachedUser?.tin ?? '';

      final invoices = await _invoiceService.getInvoicesByUser(userId);
      setState(() {
        _invoices = invoices;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Helpers.showErrorSnackbar(context, 'Failed to load invoices');
    }
  }

  void _applyFilter() {
    final sent = _invoices.where((inv) => inv.sellerTin == _userTin).toList();
    final received = _invoices.where((inv) => inv.sellerTin != _userTin).toList();
    _filteredSent = _applyFiltersTo(sent);
    _filteredReceived = _applyFiltersTo(received);
  }

  List<Invoice> _applyFiltersTo(List<Invoice> source) {
    List<Invoice> filtered = source;
    if (_filterStatus != 'all') {
      filtered = filtered
          .where((inv) => inv.status.toLowerCase() == _filterStatus)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((inv) {
        return inv.invoiceNumber.toLowerCase().contains(query) ||
            inv.buyerName.toLowerCase().contains(query) ||
            inv.buyerTin.toLowerCase().contains(query) ||
            inv.sellerName.toLowerCase().contains(query);
      }).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Invoices', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvoiceCreateScreen(),
                ),
              );
              if (result == true) {
                _loadInvoices();
              }
            },
            tooltip: 'Add Invoice',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Sent'),
                    Tab(text: 'Received'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvoiceList(_filteredSent, isSent: true),
                      _buildInvoiceList(_filteredReceived, isSent: false),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices, {required bool isSent}) {
    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: invoices.isEmpty
          ? _buildEmptyState(isSent: isSent)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                return _buildInvoiceCard(invoices[index], isSent: isSent);
              },
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search invoices...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
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
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilterDialog,
              tooltip: 'Filter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool isSent}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            isSent ? 'No sent invoices' : 'No received invoices',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSent
                ? 'Create your first invoice using\nVoice or Receipt Scanner'
                : 'Invoices sent to you will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, {required bool isSent}) {
    // For sent invoices show the buyer; for received show the seller.
    final counterpartyName = isSent ? invoice.buyerName : invoice.sellerName;
    final counterpartyTin = isSent ? invoice.buyerTin : invoice.sellerTin;
    final counterpartyLabel = isSent ? 'Buyer TIN' : 'Seller TIN';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(invoice: invoice),
            ),
          ).then((_) => _loadInvoices());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusChip(invoice.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                counterpartyName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$counterpartyLabel: $counterpartyTin',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        Helpers.formatCurrency(invoice.totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        Helpers.formatDate(invoice.issueDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              if (invoice.requiresSubmission &&
                  invoice.myInvoisId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Requires MyInvois submission',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Helpers.getStatusColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Helpers.getStatusColor(status),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Invoices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All', 'all'),
            _buildFilterOption('Draft', AppConstants.statusDraft),
            _buildFilterOption('Submitted', AppConstants.statusSubmitted),
            _buildFilterOption('Valid', AppConstants.statusValid),
            _buildFilterOption('Invalid', AppConstants.statusInvalid),
            _buildFilterOption('Cancelled', AppConstants.statusCancelled),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _filterStatus,
      onChanged: (val) {
        setState(() {
          _filterStatus = val!;
          _applyFilter();
        });
        Navigator.pop(context);
      },
    );
  }
}
