import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/payment.dart';
import 'package:gp_link/services/payment_service.dart';
import 'package:intl/intl.dart';

final _myPaymentsProvider = FutureProvider<List<Payment>>((ref) async {
  return PaymentService().getMyPayments();
});

class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myPaymentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes paiements')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) {
          if (list.isEmpty) {
            return _empty();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_myPaymentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _PayCard(p: list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payment, size: 72, color: AppTheme.primarySky),
              SizedBox(height: 16),
              Text('Aucun paiement',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              SizedBox(height: 8),
              Text('Vos paiements apparaîtront ici après votre première publication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
}

class _PayCard extends StatelessWidget {
  final Payment p;
  const _PayCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final (Color bg, Color fg, IconData icon) = switch (p.status) {
      PaymentStatus.completed => (
          AppTheme.success.withValues(alpha: 0.15),
          AppTheme.success,
          Icons.check_circle
        ),
      PaymentStatus.pending => (
          AppTheme.accentOrange.withValues(alpha: 0.15),
          AppTheme.accentOrange,
          Icons.hourglass_bottom
        ),
      PaymentStatus.failed => (
          AppTheme.error.withValues(alpha: 0.15),
          AppTheme.error,
          Icons.cancel
        ),
      PaymentStatus.expired => (
          Colors.grey.withValues(alpha: 0.15),
          Colors.grey.shade700,
          Icons.timer_off
        ),
      PaymentStatus.refunded => (
          AppTheme.primarySky.withValues(alpha: 0.15),
          AppTheme.primarySky,
          Icons.reply
        ),
    };

    final typeLabel = switch (p.paymentType) {
      'announcement' => 'Annonce standard',
      'boost' => 'Annonce boostée',
      'extension' => 'Extension',
      'extra_announcement' => 'Annonce supplémentaire',
      _ => p.paymentType,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(df.format(p.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (p.operator != null)
                  Text(p.operator!,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.amount.toStringAsFixed(0)} ${p.currency == 'XAF' ? AppConstants.currencySymbol : p.currency}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: fg, fontSize: 15),
              ),
              Text(p.status.label,
                  style: TextStyle(fontSize: 11, color: fg)),
            ],
          ),
        ],
      ),
    );
  }
}
