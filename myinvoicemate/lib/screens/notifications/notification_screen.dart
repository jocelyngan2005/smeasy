import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../backend/auth/services/auth_service.dart';
import '../../backend/compliance/models/compliance_model.dart';
import '../../backend/invoice/services/firestore_invoice_service.dart';
import '../../backend/notifications/notification_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../invoices/invoice_detail_screen.dart';

// ignore_for_file: avoid_catches_without_on_clauses

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _notificationService = NotificationService();
  final _invoiceService = FirestoreInvoiceService();

  String _userId = '';
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_userId.isEmpty) {
      _userId = context.read<AuthService>().currentUserId ?? '';
      if (_userId.isNotEmpty) _syncOnce();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─── sync ──────────────────────────────────────────────────────────────────

  Future<void> _syncOnce() async {
    if (_userId.isEmpty) return;
    setState(() => _isSyncing = true);
    try {
      await _notificationService.syncNotifications(_userId);
    } catch (e) {
      if (mounted) Helpers.showErrorSnackbar(context, 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ─── actions ───────────────────────────────────────────────────────────────

  Future<void> _markRead(ComplianceAlert alert) async {
    if (alert.isRead) return;
    await _notificationService.markAlertRead(alert.id);
  }

  Future<void> _dismiss(ComplianceAlert alert) async {
    await _notificationService.deleteAlert(alert.id);
  }

  Future<void> _openRelatedInvoice(
      BuildContext ctx, ComplianceAlert alert) async {
    if (alert.relatedInvoiceId == null) return;
    try {
      final inv = await _invoiceService.getInvoice(alert.relatedInvoiceId!);
      if (inv == null) {
        if (mounted) Helpers.showErrorSnackbar(ctx, 'Invoice not found.');
        return;
      }
      if (!ctx.mounted) return;
      await Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoice: inv),
        ),
      );
    } catch (_) {
      if (mounted) Helpers.showErrorSnackbar(ctx, 'Could not open invoice.');
    }
  }

  void _showActions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Mark all as read'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _notificationService.markAllRead(_userId);
                if (mounted) {
                  Helpers.showSuccessSnackbar(context, 'All marked as read.');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Clear read notifications'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _notificationService.clearReadAlerts(_userId);
                if (mounted) {
                  Helpers.showInfoSnackbar(
                      context, 'Read notifications cleared.');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Sync now'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _syncOnce();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: StreamBuilder<int>(
          stream: _notificationService.watchUnreadCount(_userId),
          builder: (_, snap) {
            final count = snap.data ?? 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(color: Colors.black),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: _showActions,
          ),
        ],
      ),
      body: StreamBuilder<List<ComplianceAlert>>(
        stream: _notificationService.watchAlerts(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading notifications:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            );
          }

          final all = snapshot.data ?? [];

          return _AlertList(
            alerts: all,
            onSync: _syncOnce,
            onDismiss: _dismiss,
            onMarkRead: _markRead,
            onOpenInvoice: _openRelatedInvoice,
            emptyMessage: 'No notifications',
            emptySubtitle: 'You\'re all caught up!',
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable alert list
// ─────────────────────────────────────────────────────────────────────────────

class _AlertList extends StatelessWidget {
  const _AlertList({
    required this.alerts,
    required this.onSync,
    required this.onDismiss,
    required this.onMarkRead,
    required this.onOpenInvoice,
    required this.emptyMessage,
    required this.emptySubtitle,
    this.emptyIcon = Icons.notifications_off_outlined,
  });

  final List<ComplianceAlert> alerts;
  final Future<void> Function() onSync;
  final Future<void> Function(ComplianceAlert) onDismiss;
  final Future<void> Function(ComplianceAlert) onMarkRead;
  final Future<void> Function(BuildContext, ComplianceAlert) onOpenInvoice;
  final String emptyMessage;
  final String emptySubtitle;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return _EmptyState(
          icon: emptyIcon, title: emptyMessage, subtitle: emptySubtitle);
    }

    return RefreshIndicator(
      onRefresh: onSync,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        itemCount: alerts.length,
        itemBuilder: (ctx, i) {
          final alert = alerts[i];
          return _AlertCard(
            key: ValueKey(alert.id),
            alert: alert,
            onDismiss: () => onDismiss(alert),
            onTap: () async {
              await onMarkRead(alert);
              if (alert.relatedInvoiceId != null) {
                await onOpenInvoice(ctx, alert);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert card
// ─────────────────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    required this.onDismiss,
  });

  final ComplianceAlert alert;
  final VoidCallback onTap;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = _categoryLabel(alert.category);
    final now = DateTime.now();
    final deadlineDiff = alert.deadline.difference(now);

    return Dismissible(
      key: ValueKey('dismiss_${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: alert.isRead ? null : Border.all(color: Colors.grey.shade200),
            boxShadow: alert.isRead
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            _CategoryChip(
                              label: categoryLabel,
                              color: _categoryColor(alert.category),
                            ),
                            const Spacer(),
                            if (!alert.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Title
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: alert.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Message
                        Text(
                          alert.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Footer row
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 13,
                                color: _deadlineColor(deadlineDiff)),
                            const SizedBox(width: 4),
                            Text(
                              _deadlineText(deadlineDiff, alert.deadline),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _deadlineColor(deadlineDiff),
                              ),
                            ),
                            const Spacer(),
                            if (alert.relatedInvoiceId != null) ...[
                              const Icon(Icons.receipt_long_outlined,
                                  size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              const Text(
                                'View invoice',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 10, color: AppColors.primary),
                            ],
                          ],
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Color _categoryColor(AlertCategory c) {
    switch (c) {
      case AlertCategory.lhdn:
        return const Color(0xFF2E3193);
      case AlertCategory.financial:
        return const Color(0xFF00897B);
      case AlertCategory.audit:
        return const Color(0xFF6A1B9A);
    }
  }

  String _categoryLabel(AlertCategory c) {
    switch (c) {
      case AlertCategory.lhdn:
        return 'LHDN';
      case AlertCategory.financial:
        return 'Financial';
      case AlertCategory.audit:
        return 'Audit';
    }
  }

  String _deadlineText(Duration diff, DateTime deadline) {
    if (diff.isNegative) {
      final d = diff.inDays.abs();
      return d > 0 ? 'Expired ${d}d ago' : 'Expired today';
    }
    if (diff.inHours < 1) return 'Due in <1h';
    if (diff.inHours < 24) return 'Due in ${diff.inHours}h';
    if (diff.inDays < 7) return 'Due in ${diff.inDays}d';
    return 'Due ${Helpers.formatDate(deadline)}';
  }

  Color _deadlineColor(Duration diff) {
    if (diff.isNegative) return AppColors.error;
    if (diff.inHours <= 12) return AppColors.error;
    return AppColors.textSecondary;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chip
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF1E88E5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey[350]),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
