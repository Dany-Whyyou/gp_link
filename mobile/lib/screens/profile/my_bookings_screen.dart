import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/booking.dart';
import 'package:gp_link/services/booking_service.dart';
import 'package:intl/intl.dart';

final _myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final service = BookingService();
  final client = await service.getMyBookingsAsClient();
  final traveler = await service.getMyBookingsAsTraveler();
  final merged = {for (final b in [...client, ...traveler]) b.id: b};
  final all = merged.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all;
});

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) {
          if (list.isEmpty) {
            return _empty();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_myBookingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _BookingCard(b: list[i]),
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
              Icon(Icons.bookmark_outline,
                  size: 72, color: AppTheme.primarySky),
              SizedBox(height: 16),
              Text('Aucune réservation',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              SizedBox(height: 8),
              Text(
                'Réservez des kilos sur une annonce pour la voir ici.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
}

class _BookingCard extends StatelessWidget {
  final Booking b;
  const _BookingCard({required this.b});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Réservation ${b.id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              _StatusPill(status: b.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.inventory_2, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${b.kg.toStringAsFixed(0)} kg',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.attach_money, size: 16, color: Colors.grey),
              Text('${b.totalPrice} ${AppConstants.currencySymbol}',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Créée le ${df.format(b.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final BookingStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primarySky.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.primarySky)),
    );
  }
}
