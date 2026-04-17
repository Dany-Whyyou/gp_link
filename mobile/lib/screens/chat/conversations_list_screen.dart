import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/providers/chat_provider.dart';
import 'package:gp_link/widgets/empty_state.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentProfile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: conversationsAsync.when(
        loading: () => const LoadingWidget(message: 'Chargement...'),
        error: (e, _) => ErrorState(
          message: 'Erreur de chargement des conversations',
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Aucune conversation',
              subtitle:
                  'Vos conversations avec les voyageurs et clients apparaîtront ici.',
            );
          }

          return RefreshIndicator(
            color: AppTheme.primarySky,
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final unread = currentProfile != null
                    ? conv.unreadCountFor(currentProfile.id)
                    : 0;
                final otherName =
                    conv.otherParticipant?.fullName ?? 'Utilisateur';
                final otherInitials =
                    conv.otherParticipant?.initials ?? '?';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.primarySky.withValues(alpha: 0.2),
                    child: Text(
                      otherInitials,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontWeight:
                                unread > 0 ? FontWeight.bold : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.lastMessageAt != null)
                        Text(
                          timeago.format(conv.lastMessageAt!, locale: 'fr'),
                          style: TextStyle(
                            fontSize: 12,
                            color: unread > 0
                                ? AppTheme.primarySky
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  subtitle: conv.lastMessageText != null
                      ? Text(
                          conv.lastMessageText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: unread > 0
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        )
                      : null,
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primarySky,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => context.push('/chat/${conv.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
