import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/notification.dart';
import 'package:gp_link/providers/notification_provider.dart';
import 'package:gp_link/widgets/empty_state.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'read_all':
                  ref
                      .read(notificationOperationsProvider.notifier)
                      .markAllAsRead();
                  break;
                case 'delete_all':
                  _confirmDeleteAll(context, ref);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 18),
                    SizedBox(width: 8),
                    Text('Tout marquer comme lu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 18, color: AppTheme.error),
                    SizedBox(width: 8),
                    Text('Tout supprimer',
                        style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const LoadingWidget(message: 'Chargement...'),
        error: (e, _) => ErrorState(
          message: 'Erreur de chargement',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Aucune notification',
              subtitle: 'Vos notifications apparaîtront ici.',
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryGold,
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _NotificationTile(
                  notification: notif,
                  onTap: () {
                    if (!notif.isRead) {
                      ref
                          .read(notificationOperationsProvider.notifier)
                          .markAsRead(notif.id);
                    }
                    // Navigate based on type
                    // Could parse notif.data for destination
                  },
                  onDismiss: () {
                    ref
                        .read(notificationOperationsProvider.notifier)
                        .deleteNotification(notif.id);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer toutes les notifications ?'),
        content: const Text('Cette action est irréversible.'),
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
      ref.read(notificationOperationsProvider.notifier).deleteAll();
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'booking':
        return Icons.bookmark;
      case 'alert_match':
        return Icons.notifications_active;
      case 'chat':
        return Icons.chat_bubble;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.info;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'booking':
        return AppTheme.accentBlue;
      case 'alert_match':
        return AppTheme.primaryGold;
      case 'chat':
        return AppTheme.accentGreen;
      case 'payment':
        return AppTheme.primaryAmber;
      default:
        return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        onTap: onTap,
        tileColor: notification.isRead
            ? null
            : AppTheme.primaryGold.withValues(alpha: 0.05),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconForType(notification.type),
              color: color, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              timeago.format(notification.createdAt, locale: 'fr'),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGold,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
