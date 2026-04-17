import 'package:gp_link/models/country.dart';
import 'package:gp_link/services/supabase_service.dart';

class CountryService {
  Future<List<Country>> fetchAll() async {
    final result = await SupabaseService.from('countries')
        .select()
        .order('is_popular', ascending: false)
        .order('name');
    return (result as List)
        .map((e) => Country.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
