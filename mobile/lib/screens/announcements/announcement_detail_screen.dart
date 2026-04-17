import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/announcement.dart';
import 'package:gp_link/providers/announcement_provider.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/services/booking_service.dart';
import 'package:gp_link/services/chat_service.dart';
import 'package:gp_link/widgets/empty_state.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  final String announcementId;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcementId,
  });

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  bool _isBooking = false;
  final _kgController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  @override
  void dispose() {
    _kgController.dispose();
    _descriptionController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  Future<void> _book(Announcement announcement) async {
    final kg = double.tryParse(_kgController.text) ?? 0;
    if (kg <= 0 || kg > announcement.remainingKg) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantité de kilos invalide')),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      final bookingService = BookingService();
      await bookingService.create(
        announcementId: announcement.id,
        travelerId: announcement.userId,
        kg: kg,
        totalPrice: kg * announcement.pricePerKg,
        packageDescription: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        recipientName: _recipientNameController.text.trim().isNotEmpty
            ? _recipientNameController.text.trim()
            : null,
        recipientPhone: _recipientPhoneController.text.trim().isNotEmpty
            ? _recipientPhoneController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de réservation envoyée !'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _contactTraveler(Announcement announcement) async {
    try {
      final chatService = ChatService();
      final conversation = await chatService.getOrCreateConversation(
        otherUserId: announcement.userId,
        announcementId: announcement.id,
      );
      if (mounted) {
        context.push('/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcementAsync =
        ref.watch(announcementDetailProvider(widget.announcementId));
    final currentProfile = ref.watch(currentProfileProvider);
    final dateFormat = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l\'annonce'),
      ),
      body: announcementAsync.when(
        loading: () => const LoadingWidget(message: 'Chargement...'),
        error: (e, _) => ErrorState(
          message: 'Impossible de charger l\'annonce',
          onRetry: () => ref.invalidate(
              announcementDetailProvider(widget.announcementId)),
        ),
        data: (announcement) {
          final isMine = currentProfile?.id == announcement.userId;
          final kg = double.tryParse(_kgController.text) ?? 0;
          final totalPrice = kg * announcement.pricePerKg;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.gabonGreen, AppTheme.primarySky],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      if (announcement.isBoosted)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'BOOSTEE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.flight_takeoff,
                                    color: Colors.white, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  announcement.departureCity,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  announcement.departureCountry,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 24),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.flight_land,
                                    color: Colors.white, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  announcement.arrivalCity,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  announcement.arrivalCountry,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dateFormat.format(announcement.departureDate),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Details cards
                _DetailRow(
                    icon: Icons.inventory_2,
                    label: 'Kilos disponibles',
                    value:
                        '${announcement.remainingKg.toStringAsFixed(1)} / ${announcement.availableKg.toStringAsFixed(1)} kg'),
                _DetailRow(
                    icon: Icons.attach_money,
                    label: 'Prix par kilo',
                    value:
                        '${announcement.pricePerKg.toStringAsFixed(0)} ${AppConstants.currencySymbol}'),
                if (announcement.airline != null)
                  _DetailRow(
                      icon: Icons.airlines,
                      label: 'Compagnie',
                      value: announcement.airline!),
                if (announcement.flightNumber != null)
                  _DetailRow(
                      icon: Icons.confirmation_number,
                      label: 'Vol',
                      value: announcement.flightNumber!),
                if (announcement.collectAtAirport)
                  const _DetailRow(
                      icon: Icons.location_on,
                      label: 'Récupération',
                      value: 'A l\'aéroport'),
                if (announcement.deliverToAddress)
                  const _DetailRow(
                      icon: Icons.local_shipping,
                      label: 'Livraison',
                      value: 'A domicile'),

                if (announcement.description != null &&
                    announcement.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(announcement.description!),
                ],

                if (announcement.acceptedItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Objets acceptés',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: announcement.acceptedItems
                        .map((item) => Chip(
                              label: Text(item),
                              avatar: const Icon(Icons.check_circle,
                                  size: 16, color: AppTheme.success),
                            ))
                        .toList(),
                  ),
                ],

                if (announcement.rejectedItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Objets refusés',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: announcement.rejectedItems
                        .map((item) => Chip(
                              label: Text(item),
                              avatar: const Icon(Icons.cancel,
                                  size: 16, color: AppTheme.error),
                            ))
                        .toList(),
                  ),
                ],

                // Traveler profile
                if (announcement.traveler != null) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Voyageur',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppTheme.primarySky.withValues(alpha: 0.2),
                      child: Text(
                        announcement.traveler!.initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(announcement.traveler!.fullName),
                        if (announcement.traveler!.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              size: 18, color: AppTheme.primarySky),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${announcement.traveler!.totalTrips} voyages - '
                      '${announcement.traveler!.rating.toStringAsFixed(1)} / 5',
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Booking form (only for clients, not own announcement)
                if (!isMine &&
                    announcement.isActive &&
                    announcement.hasSpace) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Réserver des kilos',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _kgController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Nombre de kilos',
                      suffixText: 'kg',
                      helperText:
                          'Max: ${announcement.remainingKg.toStringAsFixed(1)} kg',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description du colis',
                      hintText: 'Décrivez le contenu de votre colis...',
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _recipientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du destinataire',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _recipientPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone du destinataire',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySky.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total estimé',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${totalPrice.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed:
                        _isBooking ? null : () => _book(announcement),
                    child: _isBooking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Envoyer la demande'),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () => _contactTraveler(announcement),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Contacter le voyageur'),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primarySky),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              )),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
