import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/alert_provider.dart';
import 'package:gp_link/widgets/city_autocomplete.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class CreateAlertScreen extends ConsumerStatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  ConsumerState<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends ConsumerState<CreateAlertScreen> {
  String? _departureCity;
  String? _arrivalCity;
  DateTime? _departureDateMin;
  DateTime? _departureDateMax;
  final _maxPriceController = TextEditingController();
  final _minKgController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _maxPriceController.dispose();
    _minKgController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isMin) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppTheme.primarySky),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isMin) {
          _departureDateMin = picked;
        } else {
          _departureDateMax = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_departureCity == null &&
        _arrivalCity == null &&
        _departureDateMin == null &&
        _maxPriceController.text.isEmpty &&
        _minKgController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez remplir au moins un critère')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final maxPrice = _maxPriceController.text.isNotEmpty
          ? double.tryParse(_maxPriceController.text)
          : null;
      final minKg = _minKgController.text.isNotEmpty
          ? double.tryParse(_minKgController.text)
          : null;

      await ref.read(alertOperationsProvider.notifier).createAlert(
            departureCity:
                _departureCity?.isNotEmpty == true ? _departureCity : null,
            arrivalCity:
                _arrivalCity?.isNotEmpty == true ? _arrivalCity : null,
            departureDateMin: _departureDateMin,
            departureDateMax: _departureDateMax,
            maxPricePerKg: maxPrice,
            minKg: minKg,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte créée avec succès !'),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle alerte')),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Création...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recevez une notification dès qu\'un voyage correspond à vos critères.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 24),

              // Cities
              CityAutocomplete(
                label: 'Ville de départ (optionnel)',
                hintText: 'Ex: Libreville',
                onSelected: (v) => _departureCity = v,
              ),
              const SizedBox(height: 16),
              CityAutocomplete(
                label: 'Ville d\'arrivée (optionnel)',
                hintText: 'Ex: Paris',
                onSelected: (v) => _arrivalCity = v,
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
                          labelText: 'À partir du',
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          _departureDateMin != null
                              ? dateFormat.format(_departureDateMin!)
                              : 'Optionnel',
                          style: TextStyle(
                            color: _departureDateMin != null
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
                          labelText: 'Jusqu\'au',
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          _departureDateMax != null
                              ? dateFormat.format(_departureDateMax!)
                              : 'Optionnel',
                          style: TextStyle(
                            color: _departureDateMax != null
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

              // Price and KG
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Prix max/kg',
                        suffixText: AppConstants.currencySymbol,
                        prefixIcon: const Icon(Icons.attach_money, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minKgController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Kilos min',
                        suffixText: 'kg',
                        prefixIcon: Icon(Icons.inventory_2, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: const Text('Créer l\'alerte'),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Les alertes sont gratuites et illimitées. Vous recevrez une notification push à chaque correspondance.',
                        style: TextStyle(fontSize: 12, color: AppTheme.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
