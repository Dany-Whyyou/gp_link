import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/booking.dart';
import 'package:gp_link/services/supabase_service.dart';

class BookingService {
  static const _table = AppConstants.bookingsTable;
  static const _selectFull =
      '*, announcements(*), client_profile:profiles!bookings_client_id_fkey(*), traveler_profile:profiles!bookings_traveler_id_fkey(*)';

  /// Get bookings for the current user (as client).
  Future<List<Booking>> getMyBookingsAsClient() async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select(_selectFull)
        .eq('client_id', userId)
        .order('created_at', ascending: false);
    return (result as List).map((e) => Booking.fromJson(e)).toList();
  }

  /// Get bookings for the current user (as traveler).
  Future<List<Booking>> getMyBookingsAsTraveler() async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select(_selectFull)
        .eq('traveler_id', userId)
        .order('created_at', ascending: false);
    return (result as List).map((e) => Booking.fromJson(e)).toList();
  }

  /// Get bookings for a specific announcement.
  Future<List<Booking>> getBookingsForAnnouncement(
      String announcementId) async {
    final result = await SupabaseService.from(_table)
        .select(_selectFull)
        .eq('announcement_id', announcementId)
        .order('created_at', ascending: false);
    return (result as List).map((e) => Booking.fromJson(e)).toList();
  }

  /// Create a booking request.
  Future<Booking> create({
    required String announcementId,
    required String travelerId,
    required double kg,
    required double totalPrice,
    String? packageDescription,
    String? pickupAddress,
    String? deliveryAddress,
    String? recipientName,
    String? recipientPhone,
  }) async {
    final userId = SupabaseService.currentUserId!;

    final data = {
      'announcement_id': announcementId,
      'client_id': userId,
      'traveler_id': travelerId,
      'kg': kg,
      'total_price': totalPrice,
      'status': BookingStatus.pending.name,
      'package_description': packageDescription,
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
    };

    final result = await SupabaseService.from(_table)
        .insert(data)
        .select(_selectFull)
        .single();
    return Booking.fromJson(result);
  }

  /// Accept a booking (traveler action).
  Future<Booking> accept(String id) async {
    final result = await SupabaseService.from(_table)
        .update({
          'status': BookingStatus.accepted.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_selectFull)
        .single();
    return Booking.fromJson(result);
  }

  /// Reject a booking (traveler action).
  Future<Booking> reject(String id, {String? reason}) async {
    final result = await SupabaseService.from(_table)
        .update({
          'status': BookingStatus.rejected.name,
          'rejection_reason': reason,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_selectFull)
        .single();
    return Booking.fromJson(result);
  }

  /// Cancel a booking (client action).
  Future<Booking> cancel(String id) async {
    final result = await SupabaseService.from(_table)
        .update({
          'status': BookingStatus.cancelled.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_selectFull)
        .single();
    return Booking.fromJson(result);
  }

  /// Mark booking as completed.
  Future<Booking> complete(String id) async {
    final result = await SupabaseService.from(_table)
        .update({
          'status': BookingStatus.completed.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_selectFull)
        .single();
    return Booking.fromJson(result);
  }
}
