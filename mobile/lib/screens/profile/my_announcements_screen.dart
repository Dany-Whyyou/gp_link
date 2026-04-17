import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/announcement.dart';
import 'package:gp_link/providers/announcement_provider.dart';
import 'package:gp_link/services/announcement_service.dart';
import 'package:intl/intl.dart';

class MyAnnouncementsScreen extends ConsumerWidget {
  const MyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annAsync = ref.watch(myAnnouncementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes annonces')),
      body: annAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) {
          if (list.isEmpty) {
            return _emptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myAnnouncementsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _AnnCard(ann: list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flight_takeoff,
                size: 72, color: AppTheme.primarySky),
            const SizedBox(height: 16),
            const Text(
              'Aucune annonce pour le moment',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Publiez votre premier trajet en quelques secondes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/announcements/create'),
              icon: const Icon(Icons.add),
              label: const Text('Publier une annonce'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnCard extends StatelessWidget {
  final Announcement ann;
  final VoidCallback onAction;
  const _AnnCard({required this.ann, required this.onAction});

  Future<void> _handleAction(BuildContext context, String action) async {
    final service = AnnouncementService();
    try {
      if (action == 'delete') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer cette annonce ?'),
            content: const Text('Cette action est irréversible.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer',
                    style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await service.delete(ann.id);
      } else if (action == 'suspend') {
        await service.suspend(ann.id);
      } else if (action == 'reactivate') {
        await service.reactivate(ann.id);
      } else if (action == 'complete') {
        await service.complete(ann.id);
      }
      onAction();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Action effectuée'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  List<PopupMenuEntry<String>> _menuItems() {
    final items = <PopupMenuEntry<String>>[];
    if (ann.status == AnnouncementStatus.active) {
      items.add(const PopupMenuItem(
        value: 'suspend',
        child: ListTile(
          leading: Icon(Icons.pause_circle_outline),
          title: Text('Désactiver'),
          dense: true,
        ),
      ));
      items.add(const PopupMenuItem(
        value: 'complete',
        child: ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('Marquer comme terminée'),
          dense: true,
        ),
      ));
    }
    if (ann.status == AnnouncementStatus.suspended) {
      items.add(const PopupMenuItem(
        value: 'reactivate',
        child: ListTile(
          leading: Icon(Icons.play_circle_outline),
          title: Text('Réactiver'),
          dense: true,
        ),
      ));
    }
    items.add(const PopupMenuItem(
      value: 'delete',
      child: ListTile(
        leading: Icon(Icons.delete_outline, color: AppTheme.error),
        title: Text('Supprimer', style: TextStyle(color: AppTheme.error)),
        dense: true,
      ),
    ));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: () => context.push('/announcements/${ann.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                  child: Text(
                    ann.routeFull,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                _StatusBadge(status: ann.status),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (value) => _handleAction(context, value),
                  itemBuilder: (_) => _menuItems(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(df.format(ann.departureDate),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.inventory_2, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${ann.availableKg.toStringAsFixed(0)} kg',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                Text(
                    '${ann.pricePerKg.toStringAsFixed(0)} ${AppConstants.currencySymbol}/kg',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (ann.isBoosted) ...[
              const SizedBox(height: 6),
              Row(
                children: const [
                  Icon(Icons.rocket_launch,
                      size: 14, color: AppTheme.accentOrange),
                  SizedBox(width: 4),
                  Text('Boostée',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AnnouncementStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      AnnouncementStatus.active => (
          AppTheme.success.withValues(alpha: 0.15),
          AppTheme.success,
          'Active'
        ),
      AnnouncementStatus.pendingPayment => (
          AppTheme.accentOrange.withValues(alpha: 0.15),
          AppTheme.accentOrange,
          'En attente'
        ),
      AnnouncementStatus.expired => (
          Colors.grey.withValues(alpha: 0.15),
          Colors.grey.shade700,
          'Expirée'
        ),
      AnnouncementStatus.suspended => (
          AppTheme.error.withValues(alpha: 0.15),
          AppTheme.error,
          'Suspendue'
        ),
      AnnouncementStatus.completed => (
          AppTheme.primarySky.withValues(alpha: 0.15),
          AppTheme.primarySky,
          'Terminée'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
