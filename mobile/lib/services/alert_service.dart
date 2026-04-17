import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/alert.dart';
import 'package:gp_link/services/supabase_service.dart';

class AlertService {
  static const _table = AppConstants.alertsTable;

  /// Get all alerts for the current user.
  Future<List<Alert>> getMyAlerts() async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (result as List).map((e) => Alert.fromJson(e)).toList();
  }

  /// Get active alerts for the current user.
  Future<List<Alert>> getActiveAlerts() async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select()
        .eq('user_id', userId)
        .eq('status', AlertStatus.active.name)
        .order('created_at', ascending: false);
    return (result as List).map((e) => Alert.fromJson(e)).toList();
  }

  /// Create a new alert.
  Future<Alert> create({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateMin,
    DateTime? departureDateMax,
    double? maxPricePerKg,
    double? minKg,
  }) async {
    final userId = SupabaseService.currentUserId!;

    final data = {
      'user_id': userId,
      'departure_city': departureCity,
      'arrival_city': arrivalCity,
      'departure_date_min': departureDateMin?.toIso8601String(),
      'departure_date_max': departureDateMax?.toIso8601String(),
      'max_price_per_kg': maxPricePerKg,
      'min_kg': minKg,
      'status': AlertStatus.active.name,
      'match_count': 0,
    };

    final result =
        await SupabaseService.from(_table).insert(data).select().single();
    return Alert.fromJson(result);
  }

  /// Update an alert.
  Future<Alert> update(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    final result = await SupabaseService.from(_table)
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Alert.fromJson(result);
  }

  /// Pause an alert.
  Future<Alert> pause(String id) async {
    return update(id, {'status': AlertStatus.paused.name});
  }

  /// Resume an alert.
  Future<Alert> resume(String id) async {
    return update(id, {'status': AlertStatus.active.name});
  }

  /// Delete an alert.
  Future<void> delete(String id) async {
    await SupabaseService.from(_table).delete().eq('id', id);
  }
}
