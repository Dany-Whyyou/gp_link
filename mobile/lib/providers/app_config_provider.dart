import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/providers/country_provider.dart';
import 'package:gp_link/services/app_config_service.dart';

final appConfigServiceProvider = Provider<AppConfigService>((ref) => AppConfigService());

final pricingProvider = FutureProvider<Pricing>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  final countries = await ref.watch(countriesProvider.future);
  final country = countries.where((c) => c.name == profile?.country).firstOrNull;
  return ref.read(appConfigServiceProvider).fetchPricing(
        currencyCode: country?.currencyCode ?? 'XAF',
        currencySymbol: country?.currencySymbol ?? 'FCFA',
      );
});
