import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/services/tutorial_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.primarySky.withValues(alpha: 0.2),
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl == null
                  ? Text(
                      profile.initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),

            // Name and role
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (profile.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified,
                      color: AppTheme.primarySky, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: profile.isVoyageur
                    ? AppTheme.gabonGreen.withValues(alpha: 0.15)
                    : AppTheme.primarySky.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                profile.role.label,
                style: TextStyle(
                  color: profile.isVoyageur
                      ? AppTheme.gabonGreen
                      : AppTheme.primarySky,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _StatCard(
                    label: 'Voyages',
                    value: '${profile.totalTrips}',
                    icon: Icons.flight,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Livraisons',
                    value: '${profile.totalDeliveries}',
                    icon: Icons.inventory_2,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Note',
                    value: profile.rating > 0
                        ? profile.rating.toStringAsFixed(1)
                        : '-',
                    icon: Icons.star,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info section
            _InfoSection(
              items: [
                if (profile.phone != null)
                  _InfoItem(
                      icon: Icons.phone, label: 'Téléphone', value: profile.phone!),
                if (profile.email != null)
                  _InfoItem(
                      icon: Icons.email, label: 'Email', value: profile.email!),
                if (profile.city != null)
                  _InfoItem(
                      icon: Icons.location_city,
                      label: 'Ville',
                      value: profile.city!),
                if (profile.country != null)
                  _InfoItem(
                      icon: Icons.flag, label: 'Pays', value: profile.country!),
              ],
            ),

            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(profile.bio!),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Menu items
            _MenuSection(
              items: [
                _MenuItem(
                  icon: Icons.announcement_outlined,
                  label: 'Mes annonces',
                  onTap: () => context.push('/my/announcements'),
                ),
                _MenuItem(
                  icon: Icons.bookmark_outline,
                  label: 'Mes réservations',
                  onTap: () => context.push('/my/bookings'),
                ),
                _MenuItem(
                  icon: Icons.payment,
                  label: 'Mes paiements',
                  onTap: () => context.push('/my/payments'),
                ),
                _MenuItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages',
                  onTap: () => context.push('/messages'),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications'),
                ),
                _MenuItem(
                  icon: Icons.school_outlined,
                  label: 'Revoir le tutoriel',
                  onTap: () async {
                    await TutorialService().reset();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Le tutoriel s\'affichera à la prochaine ouverture'),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.help_outline,
                  label: 'Aide et support',
                  onTap: () => _openExternalUrl(AppConstants.supportUrl),
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  label: 'Conditions Générales d\'Utilisation',
                  onTap: () => _openExternalUrl(AppConstants.termsUrl),
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Politique de confidentialité',
                  onTap: () => _openExternalUrl(AppConstants.privacyUrl),
                ),
                _MenuItem(
                  icon: Icons.info_outline,
                  label: 'À propos',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          '© ${DateTime.now().year} Dadel, Libreville Gabon.\nTous droits réservés.',
                      children: const [
                        SizedBox(height: 12),
                        Text(
                          'GP Link est une plateforme de mise en relation entre voyageurs et expéditeurs de colis.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Déconnexion'),
                      content: const Text(
                          'Voulez-vous vraiment vous déconnecter ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Déconnexion',
                              style: TextStyle(color: AppTheme.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(authProvider.notifier).signOut();
                  }
                },
                icon: const Icon(Icons.logout, color: AppTheme.error),
                label: const Text('Se déconnecter',
                    style: TextStyle(color: AppTheme.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              '${AppConstants.appName} v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primarySky, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final List<_InfoItem> items;

  const _InfoSection({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: items,
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppTheme.primarySky),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      trailing: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Column(
          children: items,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: AppTheme.primarySky),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
