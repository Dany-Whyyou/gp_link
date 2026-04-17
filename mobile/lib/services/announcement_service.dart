import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/announcement.dart';
import 'package:gp_link/services/supabase_service.dart';

class AnnouncementService {
  static const _table = AppConstants.announcementsTable;
  static const _selectWithProfile =
      '*, profiles!announcements_user_id_fkey(*)';

  /// Fetch active announcements with optional filters, paginated.
  Future<List<Announcement>> getActiveAnnouncements({
    int page = 0,
    int pageSize = AppConstants.pageSize,
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateMin,
    DateTime? departureDateMax,
    double? maxPricePerKg,
    double? minKg,
  }) async {
    var query = SupabaseService.from(_table)
        .select(_selectWithProfile)
        .eq('status', AnnouncementStatus.active.value)
        .gte('departure_date', DateTime.now().toIso8601String());

    if (departureCity != null && departureCity.isNotEmpty) {
      query = query.ilike('departure_city', '%$departureCity%');
    }
    if (arrivalCity != null && arrivalCity.isNotEmpty) {
      query = query.ilike('arrival_city', '%$arrivalCity%');
    }
    if (departureDateMin != null) {
      query =
          query.gte('departure_date', departureDateMin.toIso8601String());
    }
    if (departureDateMax != null) {
      query =
          query.lte('departure_date', departureDateMax.toIso8601String());
    }
    if (maxPricePerKg != null) {
      query = query.lte('price_per_kg', maxPricePerKg);
    }
    if (minKg != null) {
      query = query.gte('available_kg', minKg);
    }

    final result = await query
        .order('type', ascending: false) // boosted first
        .order('departure_date', ascending: true)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return (result as List).map((e) => Announcement.fromJson(e)).toList();
  }

  /// Get a single announcement by ID.
  Future<Announcement> getById(String id) async {
    final result = await SupabaseService.from(_table)
        .select(_selectWithProfile)
        .eq('id', id)
        .single();
    return Announcement.fromJson(result);
  }

  /// Get announcements for the current user.
  Future<List<Announcement>> getMyAnnouncements() async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select(_selectWithProfile)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (result as List).map((e) => Announcement.fromJson(e)).toList();
  }

  /// Check if user already has an active announcement.
  Future<bool> hasActiveAnnouncement() async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select('id')
        .eq('user_id', userId)
        .inFilter('status', [
          AnnouncementStatus.active.value,
          AnnouncementStatus.pendingPayment.value,
        ])
        .limit(1);
    return (result as List).isNotEmpty;
  }

  /// Create a new announcement (status = pending_payment).
  Future<Announcement> create({
    String? departureCity,
    required String departureCountry,
    String? arrivalCity,
    required String arrivalCountry,
    required DateTime departureDate,
    DateTime? arrivalDate,
    required double availableKg,
    required double pricePerKg,
    AnnouncementType type = AnnouncementType.standard,
    String? description,
    String? flightNumber,
    String? airline,
    List<String>? acceptedItems,
    List<String>? rejectedItems,
    bool collectAtAirport = true,
    bool deliverToAddress = false,
    String? meetingPoint,
  }) async {
    final userId = SupabaseService.currentUserId!;

    final data = {
      'user_id': userId,
      'departure_city': departureCity,
      'departure_country': departureCountry,
      'arrival_city': arrivalCity,
      'arrival_country': arrivalCountry,
      'departure_date': departureDate.toIso8601String(),
      'arrival_date': arrivalDate?.toIso8601String(),
      'available_kg': availableKg,
      'price_per_kg': pricePerKg.toInt(),
      'booked_kg': 0,
      'type': type.name,
      'status': AnnouncementStatus.pendingPayment.value,
      'description': description,
      'flight_number': flightNumber,
      'airline': airline,
      'accepted_items': acceptedItems ?? [],
      'rejected_items': rejectedItems ?? [],
      'collect_at_airport': collectAtAirport,
      'deliver_to_address': deliverToAddress,
      'meeting_point': meetingPoint,
    };

    final result = await SupabaseService.from(_table)
        .insert(data)
        .select(_selectWithProfile)
        .single();

    return Announcement.fromJson(result);
  }

  /// Update an existing announcement.
  Future<Announcement> update(
      String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final result = await SupabaseService.from(_table)
        .update(updates)
        .eq('id', id)
        .select(_selectWithProfile)
        .single();

    return Announcement.fromJson(result);
  }

  /// Activate an announcement after payment.
  Future<Announcement> activate(String id) async {
    final expiresAt = DateTime.now()
        .add(const Duration(days: AppConstants.announcementDurationDays));

    return update(id, {
      'status': AnnouncementStatus.active.value,
      'expires_at': expiresAt.toIso8601String(),
    });
  }

  /// Mark as completed.
  Future<Announcement> complete(String id) async {
    return update(id, {'status': AnnouncementStatus.completed.value});
  }

  /// Delete (only if pending payment).
  Future<void> delete(String id) async {
    await SupabaseService.from(_table)
        .delete()
        .eq('id', id)
        .eq('status', AnnouncementStatus.pendingPayment.value);
  }

  /// Search cities from the cities table.
  Future<List<Map<String, dynamic>>> searchCities(String query) async {
    if (query.length < 2) return [];
    final result = await SupabaseService.from(AppConstants.citiesTable)
        .select()
        .ilike('name', '%$query%')
        .limit(10);
    return List<Map<String, dynamic>>.from(result);
  }
}
