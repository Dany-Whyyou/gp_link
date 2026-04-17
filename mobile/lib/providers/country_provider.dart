import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/models/country.dart';
import 'package:gp_link/services/country_service.dart';

final countryServiceProvider = Provider<CountryService>((ref) => CountryService());

final countriesProvider = FutureProvider<List<Country>>((ref) async {
  return ref.read(countryServiceProvider).fetchAll();
});
