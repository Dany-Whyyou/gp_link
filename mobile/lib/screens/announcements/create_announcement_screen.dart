import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/announcement_provider.dart';
import 'package:gp_link/providers/app_config_provider.dart';
import 'package:gp_link/providers/free_offer_provider.dart';
import 'package:gp_link/services/app_config_service.dart';
import 'package:gp_link/services/payment_service.dart';
import 'package:gp_link/widgets/country_picker.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState
    extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _departureCountry = 'Gabon';
  String _arrivalCountry = 'France';
  DateTime? _departureDate;
  DateTime? _arrivalDate;
  AnnouncementType _type = AnnouncementType.standard;
  bool _collectAtAirport = true;
  bool _deliverToAddress = false;
  bool _isSubmitting = false;

  final _acceptedItems = <String>[];
  final _rejectedItems = <String>[];
  final _itemController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDeparture) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDeparture
          ? (_departureDate ?? now.add(const Duration(days: 1)))
          : (_arrivalDate ?? _departureDate ?? now.add(const Duration(days: 2))),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context)
                .colorScheme
                .copyWith(primary: AppTheme.primarySky),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isDeparture) {
          _departureDate = picked;
        } else {
          _arrivalDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date de départ')),
      );
      return;
    }
    if (_departureCountry == _arrivalCountry) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le pays de départ et d\'arrivée doivent être différents')),
      );
      return;
    }

    final hasActive = await ref.read(hasActiveAnnouncementProvider.future);
    final freeOffer = await ref.read(freeOfferProvider.future);
    final pricing = ref.read(pricingProvider).value ?? Pricing.defaults();

    // Détermine le type de paiement et le montant
    final String paymentType;
    final int amount;
    if (_type == AnnouncementType.boosted) {
      paymentType = 'boost';
      amount = pricing.boostedAnnouncement;
    } else if (freeOffer.hasFreeFirst || freeOffer.promoRemaining > 0) {
      paymentType = 'announcement';
      amount = 0;
    } else if (hasActive) {
      paymentType = 'extra_announcement';
      amount = pricing.extraAnnouncement;
    } else {
      paymentType = 'announcement';
      amount = pricing.standardAnnouncement;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(announcementServiceProvider);
      final announcement = await service.create(
        departureCountry: _departureCountry,
        arrivalCountry: _arrivalCountry,
        departureDate: _departureDate!,
        arrivalDate: _arrivalDate,
        availableKg: 20, // Valeur par défaut (champ masqué côté UI)
        pricePerKg: double.parse(_priceController.text),
        type: _type,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        flightNumber: null,
        airline: null,
        acceptedItems: _acceptedItems,
        rejectedItems: _rejectedItems,
        collectAtAirport: _collectAtAirport,
        deliverToAddress: _deliverToAddress,
      );

      ref.invalidate(announcementsProvider);
      ref.invalidate(myAnnouncementsProvider);

      if (amount <= 0) {
        final paymentService = PaymentService();
        await paymentService.initiatePayment(
          announcementId: announcement.id,
          paymentType: paymentType,
          operator: MobileMoneyOperator.test,
          phoneNumber: '',
        );
        ref.invalidate(announcementsProvider);
        ref.invalidate(myAnnouncementsProvider);
        ref.invalidate(freeOfferProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Annonce publiée avec succès !'),
              backgroundColor: AppTheme.success,
            ),
          );
          context.go('/home');
        }
        return;
      }

      if (mounted) {
        context.pushReplacement('/payments/new', extra: {
          'announcement_id': announcement.id,
          'payment_type': paymentType,
          'amount': amount,
          'label': 'Publication ${_type.label}',
        });
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle annonce')),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Publication en cours...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type selection
                Text('Type d\'annonce',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TypeChip(
                        label: 'Standard',
                        price:
                            '${ref.watch(pricingProvider).value?.standardAnnouncement ?? AppConstants.defaultPriceStandard} ${AppConstants.currencySymbol}',
                        isSelected: _type == AnnouncementType.standard,
                        onTap: () =>
                            setState(() => _type = AnnouncementType.standard),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeChip(
                        label: 'Boosté',
                        price:
                            '${ref.watch(pricingProvider).value?.boostedAnnouncement ?? AppConstants.defaultPriceBoosted} ${AppConstants.currencySymbol}',
                        isSelected: _type == AnnouncementType.boosted,
                        isBoosted: true,
                        onTap: () =>
                            setState(() => _type = AnnouncementType.boosted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Countries
                CountryPicker(
                  label: 'Pays de départ',
                  value: _departureCountry,
                  onSelected: (c) => setState(() => _departureCountry = c.name),
                ),
                const SizedBox(height: 16),
                CountryPicker(
                  label: 'Pays d\'arrivée',
                  value: _arrivalCountry,
                  onSelected: (c) => setState(() => _arrivalCountry = c.name),
                ),
                const SizedBox(height: 16),

                // Dates
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de départ *',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _departureDate != null
                                ? dateFormat.format(_departureDate!)
                                : 'Sélectionner',
                            style: TextStyle(
                              color: _departureDate != null
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date d\'arrivée',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _arrivalDate != null
                                ? dateFormat.format(_arrivalDate!)
                                : 'Optionnel',
                            style: TextStyle(
                              color: _arrivalDate != null
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Prix par kg *',
                          suffixText: AppConstants.currencySymbol,
                          prefixIcon: const Icon(Icons.attach_money, size: 18),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requis';
                          final price = int.tryParse(v);
                          if (price == null || price <= 0) {
                            return 'Prix invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    hintText: 'Informations complémentaires...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Collection options
                Text('Options de remise',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _collectAtAirport,
                  onChanged: (v) =>
                      setState(() => _collectAtAirport = v ?? true),
                  title: const Text('Récupération à l\'aéroport'),
                  activeColor: AppTheme.primarySky,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _deliverToAddress,
                  onChanged: (v) =>
                      setState(() => _deliverToAddress = v ?? false),
                  title: const Text('Rendez-vous après l\'arrivée'),
                  activeColor: AppTheme.primarySky,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 16),

                // Accepted items
                _ItemsSection(
                  title: 'Objets acceptés',
                  items: _acceptedItems,
                  color: AppTheme.success,
                  onAdd: (item) =>
                      setState(() => _acceptedItems.add(item)),
                  onRemove: (i) =>
                      setState(() => _acceptedItems.removeAt(i)),
                ),
                const SizedBox(height: 12),

                // Rejected items
                _ItemsSection(
                  title: 'Objets refusés',
                  items: _rejectedItems,
                  color: AppTheme.error,
                  onAdd: (item) =>
                      setState(() => _rejectedItems.add(item)),
                  onRemove: (i) =>
                      setState(() => _rejectedItems.removeAt(i)),
                ),

                const SizedBox(height: 24),

                // Frais de publication : dynamique selon contexte
                _FeeSummary(selectedType: _type),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: const Text('Publier'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeeSummary extends ConsumerWidget {
  final AnnouncementType selectedType;

  const _FeeSummary({required this.selectedType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricing = ref.watch(pricingProvider).value ?? Pricing.defaults();
    final hasActiveAsync = ref.watch(hasActiveAnnouncementProvider);
    final freeOfferAsync = ref.watch(freeOfferProvider);

    final hasActive = hasActiveAsync.valueOrNull ?? false;
    final freeFirst = freeOfferAsync.valueOrNull?.hasFreeFirst ?? false;
    final promoRemaining = freeOfferAsync.valueOrNull?.promoRemaining ?? 0;

    int amount;
    String? notice;

    if (selectedType == AnnouncementType.boosted) {
      amount = pricing.boostedAnnouncement;
      notice = 'Votre annonce sera mise en avant pendant 7 jours';
    } else if (freeFirst) {
      amount = 0;
      notice = 'Offre de bienvenue : votre première annonce est gratuite.';
    } else if (promoRemaining > 0) {
      amount = 0;
      notice =
          'Promotion en cours : $promoRemaining annonce${promoRemaining > 1 ? "s" : ""} gratuite${promoRemaining > 1 ? "s" : ""} restante${promoRemaining > 1 ? "s" : ""}.';
    } else if (hasActive) {
      amount = pricing.extraAnnouncement;
      notice =
          'Vous avez déjà une annonce active, celle-ci sera tarifée comme annonce supplémentaire.';
    } else {
      amount = pricing.standardAnnouncement;
      notice = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED), // orange très pâle
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.accentOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Frais de publication',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '$amount ${pricing.currencySymbol}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primaryNavy,
                ),
              ),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: 8),
            Text(
              notice,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade700, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String price;
  final bool isSelected;
  final bool isBoosted;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.price,
    required this.isSelected,
    this.isBoosted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isBoosted
                  ? AppTheme.accentOrange.withValues(alpha: 0.15)
                  : AppTheme.primarySky.withValues(alpha: 0.1))
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isBoosted ? AppTheme.accentOrange : AppTheme.primarySky)
                : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isBoosted ? Icons.rocket_launch : Icons.flight_takeoff,
              color: isBoosted ? AppTheme.accentOrange : AppTheme.primarySky,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(price,
                style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavy)),
          ],
        ),
      ),
    );
  }
}

class _ItemsSection extends StatefulWidget {
  final String title;
  final List<String> items;
  final Color color;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;

  const _ItemsSection({
    required this.title,
    required this.items,
    required this.color,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_ItemsSection> createState() => _ItemsSectionState();
}

class _ItemsSectionState extends State<_ItemsSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ajouter un objet...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    widget.onAdd(v.trim());
                    _controller.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle, color: widget.color),
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  widget.onAdd(_controller.text.trim());
                  _controller.clear();
                }
              },
            ),
          ],
        ),
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.items.asMap().entries.map((entry) {
              return Chip(
                label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => widget.onRemove(entry.key),
                backgroundColor: widget.color.withValues(alpha: 0.1),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
