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
import 'package:gp_link/screens/profile/my_announcements_screen.dart';
import 'package:gp_link/screens/profile/profile_screen.dart';
import 'package:gp_link/services/tutorial_service.dart';
import 'package:gp_link/widgets/home_tutorial.dart';

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
    MyAnnouncementsScreen(),
    ProfileScreen(),
  ];

  final _tutorialService = TutorialService();
  final _keyAnnouncements = GlobalKey();
  final _keyAlerts = GlobalKey();
  final _keyMessages = GlobalKey();
  final _keyProfile = GlobalKey();
  final _keyFab = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  Future<void> _maybeShowTutorial() async {
    final done = await _tutorialService.isHomeCompleted();
    if (done || !mounted) return;
    // Petit délai pour laisser les widgets se poser
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    HomeTutorial(
      targets: HomeTutorialTargets(
        announcementsTab: _keyAnnouncements,
        alertsTab: _keyAlerts,
        messagesTab: _keyMessages,
        profileTab: _keyProfile,
        publishFab: _keyFab,
      ),
      onFinish: _tutorialService.markHomeCompleted,
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final unreadChat = ref.watch(unreadChatCountProvider);
    // ignore: unused_local_variable
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
          BottomNavigationBarItem(
            icon: Icon(Icons.search, key: _keyAnnouncements),
            activeIcon: const Icon(Icons.search),
            label: 'Annonces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active_outlined, key: _keyAlerts),
            activeIcon: const Icon(Icons.notifications_active),
            label: 'Alertes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined, key: _keyMessages),
            activeIcon: const Icon(Icons.inventory_2),
            label: 'Mes annonces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, key: _keyProfile),
            activeIcon: const Icon(Icons.person),
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
      key: _keyFab,
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
  final Key? iconKey;

  const _BadgeIcon({required this.icon, required this.count, this.iconKey});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, key: iconKey),
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
