import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/alert.dart';
import 'package:gp_link/providers/alert_provider.dart';
import 'package:gp_link/widgets/empty_state.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class AlertsListScreen extends ConsumerWidget {
  const AlertsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(myAlertsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes alertes'),
      ),
      body: alertsAsync.when(
        loading: () => const LoadingWidget(message: 'Chargement...'),
        error: (e, _) => ErrorState(
          message: 'Erreur de chargement',
          onRetry: () => ref.invalidate(myAlertsProvider),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_active_outlined,
              title: 'Aucune alerte',
              subtitle:
                  'Créez une alerte pour être notifié quand un voyageur correspond à vos critères.',
              actionLabel: 'Créer une alerte',
              onAction: () => context.push('/alerts/create'),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryGold,
            onRefresh: () async => ref.invalidate(myAlertsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _AlertCard(
                  alert: alert,
                  dateFormat: dateFormat,
                  onTogglePause: () {
                    ref.read(alertOperationsProvider.notifier).togglePause(alert);
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Supprimer l\'alerte ?'),
                        content: const Text(
                            'Cette action est irréversible.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Supprimer',
                                style: TextStyle(color: AppTheme.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref
                          .read(alertOperationsProvider.notifier)
                          .deleteAlert(alert.id);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final DateFormat dateFormat;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.dateFormat,
    required this.onTogglePause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (alert.status) {
      AlertStatus.active => AppTheme.success,
      AlertStatus.paused => AppTheme.warning,
      AlertStatus.expired => AppTheme.error,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert.status.label,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (alert.matchCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${alert.matchCount} match(es)',
                      style: const TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Route
            Row(
              children: [
                const Icon(Icons.flight_takeoff,
                    size: 16, color: AppTheme.accentGreen),
                const SizedBox(width: 6),
                Text(alert.departureCity ?? 'Toutes villes',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward,
                    size: 14, color: AppTheme.primaryGold),
                const SizedBox(width: 8),
                const Icon(Icons.flight_land,
                    size: 16, color: AppTheme.accentBlue),
                const SizedBox(width: 6),
                Text(alert.arrivalCity ?? 'Toutes villes',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),

            const SizedBox(height: 8),

            // Criteria
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (alert.departureDateMin != null)
                  _CriteriaChip(
                    icon: Icons.calendar_today,
                    label: 'Dès ${dateFormat.format(alert.departureDateMin!)}',
                  ),
                if (alert.maxPricePerKg != null)
                  _CriteriaChip(
                    icon: Icons.attach_money,
                    label:
                        'Max ${alert.maxPricePerKg!.toStringAsFixed(0)} ${AppConstants.currencySymbol}/kg',
                  ),
                if (alert.minKg != null)
                  _CriteriaChip(
                    icon: Icons.inventory_2,
                    label: 'Min ${alert.minKg!.toStringAsFixed(0)} kg',
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onTogglePause,
                  icon: Icon(
                    alert.isActive ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(alert.isActive ? 'Pause' : 'Reprendre'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.error),
                  label: const Text('Supprimer',
                      style: TextStyle(color: AppTheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CriteriaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CriteriaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            )),
      ],
    );
  }
}
