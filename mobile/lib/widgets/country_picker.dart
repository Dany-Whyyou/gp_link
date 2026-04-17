import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/country.dart';
import 'package:gp_link/providers/country_provider.dart';

class CountryPicker extends ConsumerWidget {
  final String label;
  final String? value;
  final ValueChanged<Country> onSelected;

  const CountryPicker({
    super.key,
    required this.label,
    this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countriesAsync = ref.watch(countriesProvider);

    return countriesAsync.when(
      loading: () => const _PickerShell(child: LinearProgressIndicator()),
      error: (e, _) => _PickerShell(
        child: Text('Erreur: $e',
            style: const TextStyle(color: AppTheme.error, fontSize: 12)),
      ),
      data: (countries) {
        final selected = countries.firstWhere(
          (c) => c.name == value,
          orElse: () => countries.first,
        );
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.public, size: 20),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              value: value ?? selected.name,
              items: countries
                  .map((c) => DropdownMenuItem(
                        value: c.name,
                        child: Text(c.displayLabel),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                final picked = countries.firstWhere((c) => c.name == v);
                onSelected(picked);
              },
            ),
          ),
        );
      },
    );
  }
}

class _PickerShell extends StatelessWidget {
  final Widget child;
  const _PickerShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
