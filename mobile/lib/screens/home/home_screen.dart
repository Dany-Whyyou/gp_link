import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/providers/chat_provider.dart';
import 'package:gp_link/providers/free_offer_provider.dart';
import 'package:gp_link/providers/notification_provider.dart';
import 'package:gp_link/screens/announcements/announcements_list_screen.dart';
import 'package:gp_link/screens/alerts/alerts_list_screen.dart';
import 'package:gp_link/screens/chat/conversations_list_screen.dart';
import 'package:gp_link/screens/profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    AnnouncementsListScreen(),
    AlertsListScreen(),
    ConversationsListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadChat = ref.watch(unreadChatCountProvider);
    final unreadNotif = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search),
            label: 'Annonces',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active_outlined),
            activeIcon: Icon(Icons.notifications_active),
            label: 'Alertes',
          ),
          BottomNavigationBarItem(
            icon: _BadgeIcon(
              icon: Icons.chat_bubble_outline,
              count: unreadChat.valueOrNull ?? 0,
            ),
            activeIcon: _BadgeIcon(
              icon: Icons.chat_bubble,
              count: unreadChat.valueOrNull ?? 0,
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? _buildFab(context)
          : _currentIndex == 1
              ? FloatingActionButton(
                  backgroundColor: AppTheme.primarySky,
                  onPressed: () => context.push('/alerts/create'),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
    );
  }

  Widget? _buildFab(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) return null;

    return FloatingActionButton.extended(
      backgroundColor: AppTheme.primarySky,
      onPressed: _onPublishTap,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Publier',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _onPublishTap() async {
    // Invalide pour forcer un fetch frais (évite le cache entre publications)
    ref.invalidate(freeOfferProvider);
    final offer = await ref.read(freeOfferProvider.future);

    if (!mounted) return;

    if (offer.hasFreeFirst) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.card_giftcard,
              color: AppTheme.accentOrange, size: 48),
          title: const Text('Votre première annonce est offerte !',
              textAlign: TextAlign.center),
          content: const Text(
            'Profitez de GP Link en publiant votre première annonce '
            'gratuitement. Aucun paiement ne vous sera demandé.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/announcements/create');
              },
              child: const Text('Publier maintenant'),
            ),
          ],
        ),
      );
    } else if (offer.promoRemaining > 0) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.local_offer,
              color: AppTheme.accentOrange, size: 48),
          title: Text(
            'Promo en cours : ${offer.promoRemaining} annonce${offer.promoRemaining > 1 ? "s" : ""} gratuite${offer.promoRemaining > 1 ? "s" : ""} restante${offer.promoRemaining > 1 ? "s" : ""}',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Profitez de la promotion en cours pour publier votre annonce sans frais.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/announcements/create');
              },
              child: const Text('Publier'),
            ),
          ],
        ),
      );
    } else {
      context.push('/announcements/create');
    }
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _BadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
