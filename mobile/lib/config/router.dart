import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/screens/onboarding/onboarding_screen.dart';
import 'package:gp_link/screens/auth/login_screen.dart';
import 'package:gp_link/screens/auth/register_screen.dart';
import 'package:gp_link/screens/home/home_screen.dart';
import 'package:gp_link/screens/announcements/announcement_detail_screen.dart';
import 'package:gp_link/screens/announcements/create_announcement_screen.dart';
import 'package:gp_link/screens/alerts/create_alert_screen.dart';
import 'package:gp_link/screens/chat/chat_screen.dart';
import 'package:gp_link/screens/profile/edit_profile_screen.dart';
import 'package:gp_link/screens/notifications/notifications_screen.dart';
import 'package:gp_link/screens/payments/payment_screen.dart';
import 'package:gp_link/screens/payments/payment_polling_screen.dart';
import 'package:gp_link/screens/profile/my_announcements_screen.dart';
import 'package:gp_link/screens/profile/my_bookings_screen.dart';
import 'package:gp_link/screens/profile/my_payments_screen.dart';
import 'package:gp_link/screens/chat/conversations_list_screen.dart';

/// Notifier qui déclenche un refresh du router quand authProvider change,
/// SANS recréer le GoRouter (qui perdrait le state des écrans).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) async {
      final path = state.uri.path;
      final isOnboarding = path == '/onboarding';
      final isAuth = path == '/login' || path == '/register';

      // Check onboarding
      if (!isOnboarding) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingComplete =
            prefs.getBool('onboarding_complete') ?? false;
        if (!onboardingComplete) return '/onboarding';
      }

      final authState = ref.read(authProvider);

      if (authState.status == AuthStatus.unauthenticated) {
        if (!isAuth && !isOnboarding) return '/login';
      }
      if (authState.status == AuthStatus.needsProfile) {
        if (path != '/register') return '/register';
      }
      if (authState.status == AuthStatus.authenticated) {
        if (isAuth || isOnboarding) return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/announcements/create',
        builder: (context, state) => const CreateAnnouncementScreen(),
      ),
      GoRoute(
        path: '/announcements/:id',
        builder: (context, state) => AnnouncementDetailScreen(
          announcementId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/alerts/create',
        builder: (context, state) => const CreateAlertScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/payments/new',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PaymentScreen(
            announcementId: extra['announcement_id'] as String,
            paymentType: extra['payment_type'] as String,
            amount: extra['amount'] as int,
            label: extra['label'] as String,
          );
        },
      ),
      GoRoute(
        path: '/payments/:id/waiting',
        builder: (context, state) => PaymentPollingScreen(
          paymentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/my/announcements',
        builder: (context, state) => const MyAnnouncementsScreen(),
      ),
      GoRoute(
        path: '/my/bookings',
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/my/payments',
        builder: (context, state) => const MyPaymentsScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const ConversationsListScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Page introuvable'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
});
