import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../backend/auth/services/auth_service.dart';
import '../../backend/invoice/models/invoice_model.dart';
import '../../backend/invoice/models/invoice_adapter.dart';
import '../../backend/invoice/services/firestore_invoice_service.dart';
import '../../backend/invoice/services/gemini_service.dart';
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

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final _geminiService = GeminiService();

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

  // ── Selection helpers ──────────────────────────────────────────────────────

  void _enterSelectionMode(Invoice invoice) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(invoice.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final current = _tabController.index == 0 ? _filteredSent : _filteredReceived;
    setState(() {
      if (_selectedIds.length == current.length &&
          current.every((inv) => _selectedIds.contains(inv.id))) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(current.map((inv) => inv.id));
      }
    });
  }

  // ── Batch actions ──────────────────────────────────────────────────────────

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await Helpers.showConfirmDialog(
      context,
      title: 'Delete $count Invoice${count == 1 ? '' : 's'}',
      message: 'Are you sure you want to delete $count selected invoice${count == 1 ? '' : 's'}? This cannot be undone.',
      confirmText: 'Delete',
    );
    if (!confirmed) return;

    setState(() => _isLoading = true);
    int deleted = 0;
    int failed = 0;
    for (final id in List<String>.from(_selectedIds)) {
      try {
        await _invoiceService.deleteInvoice(id);
        deleted++;
      } catch (_) {
        failed++;
      }
    }
    _exitSelectionMode();
    await _loadInvoices();
    if (mounted) {
      if (failed == 0) {
        Helpers.showSuccessSnackbar(context, 'Deleted $deleted invoice${deleted == 1 ? '' : 's'}');
      } else {
        Helpers.showErrorSnackbar(
            context, 'Deleted $deleted, failed $failed invoice${failed == 1 ? '' : 's'}');
      }
    }
  }

  Future<void> _batchVerify() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await Helpers.showConfirmDialog(
      context,
      title: 'Verify $count Invoice${count == 1 ? '' : 's'}',
      message: 'Run compliance validation on $count selected invoice${count == 1 ? '' : 's'}?',
      confirmText: 'Verify',
    );
    if (!confirmed) return;

    setState(() => _isLoading = true);

    final selected = _invoices.where((inv) => _selectedIds.contains(inv.id)).toList();
    int passed = 0;
    int failedCount = 0;
    int errors = 0;
    final List<Map<String, dynamic>> results = [];

    for (final invoice in selected) {
      try {
        final validation = await _geminiService.validateInvoice(invoice);
        final isValid = validation['isValid'] as bool? ?? false;
        results.add({
          'invoiceNumber': invoice.invoiceNumber,
          'isValid': isValid,
          'score': validation['complianceScore'],
          'errors': validation['errors'],
        });
        // Update status in Firestore based on result
        await _invoiceService.updateComplianceStatus(
          invoice.id,
          isValid ? ComplianceStatus.valid : ComplianceStatus.invalid,
        );
        if (isValid) {
          passed++;
        } else {
          failedCount++;
        }
      } catch (_) {
        errors++;
        results.add({
          'invoiceNumber': invoice.invoiceNumber,
          'isValid': false,
          'score': 0,
          'errors': ['Validation error'],
        });
      }
    }

    _exitSelectionMode();
    await _loadInvoices();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                failedCount == 0 && errors == 0
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: failedCount == 0 && errors == 0
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 8),
              const Text('Batch Verification'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _batchResultRow(Icons.check_circle, AppColors.success,
                  'Passed', passed),
              _batchResultRow(Icons.cancel, AppColors.error,
                  'Failed', failedCount),
              if (errors > 0)
                _batchResultRow(Icons.warning_amber, AppColors.warning,
                    'Errors', errors),
              if (results.any((r) => !(r['isValid'] as bool))) ...
                [
                  const Divider(height: 24),
                  const Text('Failed invoices:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...results
                      .where((r) => !(r['isValid'] as bool))
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• ${r['invoiceNumber']} (score: ${r['score']}%)',
                              style:
                                  const TextStyle(color: AppColors.error),
                            ),
                          ))
                      .toList(),
                ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _batchResultRow(
      IconData icon, Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text('$label: $count',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
    final currentList =
        _tabController.index == 0 ? _filteredSent : _filteredReceived;
    final allSelected = _selectedIds.length == currentList.length &&
        currentList.isNotEmpty &&
        currentList.every((inv) => _selectedIds.contains(inv.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel',
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: Icon(allSelected
                      ? Icons.deselect
                      : Icons.select_all),
                  onPressed: _selectAll,
                  tooltip: allSelected ? 'Deselect All' : 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.verified_user),
                  onPressed:
                      _selectedIds.isEmpty ? null : _batchVerify,
                  tooltip: 'Verify Selected',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed:
                      _selectedIds.isEmpty ? null : _batchDelete,
                  tooltip: 'Delete Selected',
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black,
              title: const Text('Invoices',
                  style: TextStyle(color: Colors.black)),
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
      onRefresh: _isSelectionMode
          ? () async {}
          : _loadInvoices,
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
    final isSelected = _selectedIds.contains(invoice.id);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppColors.primary.withOpacity(0.08) : null,
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(invoice.id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(invoice: invoice),
              ),
            ).then((_) => _loadInvoices());
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _enterSelectionMode(invoice);
          }
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
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
