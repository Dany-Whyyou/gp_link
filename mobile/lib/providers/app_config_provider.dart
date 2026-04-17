import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/services/app_config_service.dart';

final appConfigServiceProvider = Provider<AppConfigService>((ref) => AppConfigService());

final pricingProvider = FutureProvider<Pricing>((ref) async {
  return ref.read(appConfigServiceProvider).fetchPricing();
});
