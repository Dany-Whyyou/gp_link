import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/announcement.dart';
import 'package:gp_link/models/profile.dart';

class Booking {
  final String id;
  final String announcementId;
  final String clientId;
  final String travelerId;
  final double kg;
  final double totalPrice;
  final BookingStatus status;
  final String? packageDescription;
  final String? pickupAddress;
  final String? deliveryAddress;
  final String? recipientName;
  final String? recipientPhone;
  final String? rejectionReason;
  final String? trackingCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final Announcement? announcement;
  final Profile? client;
  final Profile? traveler;

  const Booking({
    required this.id,
    required this.announcementId,
    required this.clientId,
    required this.travelerId,
    required this.kg,
    required this.totalPrice,
    this.status = BookingStatus.pending,
    this.packageDescription,
    this.pickupAddress,
    this.deliveryAddress,
    this.recipientName,
    this.recipientPhone,
    this.rejectionReason,
    this.trackingCode,
    required this.createdAt,
    required this.updatedAt,
    this.announcement,
    this.client,
    this.traveler,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    Announcement? announcement;
    if (json['announcements'] != null && json['announcements'] is Map) {
      announcement =
          Announcement.fromJson(json['announcements'] as Map<String, dynamic>);
    }

    Profile? client;
    if (json['client_profile'] != null && json['client_profile'] is Map) {
      client =
          Profile.fromJson(json['client_profile'] as Map<String, dynamic>);
    }

    Profile? traveler;
    if (json['traveler_profile'] != null && json['traveler_profile'] is Map) {
      traveler =
          Profile.fromJson(json['traveler_profile'] as Map<String, dynamic>);
    }

    return Booking(
      id: json['id'] as String,
      announcementId: json['announcement_id'] as String,
      clientId: json['client_id'] as String,
      travelerId: json['traveler_id'] as String,
      kg: (json['kg'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => BookingStatus.pending,
      ),
      packageDescription: json['package_description'] as String?,
      pickupAddress: json['pickup_address'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      trackingCode: json['tracking_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      announcement: announcement,
      client: client,
      traveler: traveler,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'announcement_id': announcementId,
      'client_id': clientId,
      'traveler_id': travelerId,
      'kg': kg,
      'total_price': totalPrice,
      'status': status.name,
      'package_description': packageDescription,
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
    };
  }

  bool get isPending => status == BookingStatus.pending;
  bool get isAccepted => status == BookingStatus.accepted;
  bool get isCompleted => status == BookingStatus.completed;

  String get priceFormatted =>
      '${totalPrice.toStringAsFixed(0)} ${AppConstants.currencySymbol}';
}
