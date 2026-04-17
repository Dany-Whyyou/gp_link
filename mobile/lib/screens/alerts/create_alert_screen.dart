import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/alert_provider.dart';
import 'package:gp_link/widgets/country_picker.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class CreateAlertScreen extends ConsumerStatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  ConsumerState<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends ConsumerState<CreateAlertScreen> {
  String? _departureCountry;
  String? _arrivalCountry;
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
    if (_departureCountry == null &&
        _arrivalCountry == null &&
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
            departureCountry: _departureCountry,
            arrivalCountry: _arrivalCountry,
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

              // Countries
              CountryPicker(
                label: 'Pays de départ (optionnel)',
                value: _departureCountry,
                onSelected: (c) => setState(() => _departureCountry = c.name),
              ),
              const SizedBox(height: 16),
              CountryPicker(
                label: 'Pays d\'arrivée (optionnel)',
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

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix max / kg',
                        hintText: 'Ex: 5000',
                        suffixText: 'FCFA',
                        prefixIcon: Icon(Icons.attach_money, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minKgController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kg min',
                        hintText: 'Ex: 5',
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
            ],
          ),
        ),
      ),
    );
  }
}
