import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/profile.dart';

class Announcement {
  final String id;
  final String userId;
  final String? departureCity;
  final String departureCountry;
  final String? arrivalCity;
  final String arrivalCountry;
  final DateTime departureDate;
  final DateTime? arrivalDate;
  final double availableKg;
  final double pricePerKg;
  final double? bookedKg;
  final AnnouncementType type;
  final AnnouncementStatus status;
  final String? description;
  final String? flightNumber;
  final String? airline;
  final List<String> acceptedItems;
  final List<String> rejectedItems;
  final bool collectAtAirport;
  final bool deliverToAddress;
  final String? meetingPoint;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final Profile? traveler;

  const Announcement({
    required this.id,
    required this.userId,
    this.departureCity,
    required this.departureCountry,
    this.arrivalCity,
    required this.arrivalCountry,
    required this.departureDate,
    this.arrivalDate,
    required this.availableKg,
    required this.pricePerKg,
    this.bookedKg,
    this.type = AnnouncementType.standard,
    this.status = AnnouncementStatus.pendingPayment,
    this.description,
    this.flightNumber,
    this.airline,
    this.acceptedItems = const [],
    this.rejectedItems = const [],
    this.collectAtAirport = true,
    this.deliverToAddress = false,
    this.meetingPoint,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.traveler,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    Profile? traveler;
    if (json['profiles'] != null && json['profiles'] is Map) {
      traveler = Profile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    return Announcement(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      departureCity: json['departure_city'] as String?,
      departureCountry: json['departure_country'] as String? ?? 'Gabon',
      arrivalCity: json['arrival_city'] as String?,
      arrivalCountry: json['arrival_country'] as String? ?? '',
      departureDate: DateTime.parse(json['departure_date'] as String),
      arrivalDate: json['arrival_date'] != null
          ? DateTime.parse(json['arrival_date'] as String)
          : null,
      availableKg: (json['available_kg'] as num).toDouble(),
      pricePerKg: (json['price_per_kg'] as num).toDouble(),
      bookedKg: (json['booked_kg'] as num?)?.toDouble(),
      type: AnnouncementType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'standard'),
        orElse: () => AnnouncementType.standard,
      ),
      status: AnnouncementStatus.fromString(
        json['status'] as String? ?? 'pending_payment',
      ),
      description: json['description'] as String?,
      flightNumber: json['flight_number'] as String?,
      airline: json['airline'] as String?,
      acceptedItems: (json['accepted_items'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      rejectedItems: (json['rejected_items'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      collectAtAirport: json['collect_at_airport'] as bool? ?? true,
      deliverToAddress: json['deliver_to_address'] as bool? ?? false,
      meetingPoint: json['meeting_point'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
      traveler: traveler,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'departure_city': departureCity,
      'departure_country': departureCountry,
      'arrival_city': arrivalCity,
      'arrival_country': arrivalCountry,
      'departure_date': departureDate.toIso8601String(),
      'arrival_date': arrivalDate?.toIso8601String(),
      'available_kg': availableKg,
      'price_per_kg': pricePerKg,
      'type': type.name,
      'status': status.value,
      'description': description,
      'flight_number': flightNumber,
      'airline': airline,
      'accepted_items': acceptedItems,
      'rejected_items': rejectedItems,
      'collect_at_airport': collectAtAirport,
      'deliver_to_address': deliverToAddress,
      'meeting_point': meetingPoint,
    };
  }

  double get remainingKg => availableKg - (bookedKg ?? 0);
  bool get hasSpace => remainingKg > 0;
  bool get isActive => status == AnnouncementStatus.active;
  bool get isBoosted => type == AnnouncementType.boosted;

  String get route =>
      '${departureCity ?? departureCountry} -> ${arrivalCity ?? arrivalCountry}';
  String get routeFull {
    final dep = departureCity != null
        ? '$departureCity ($departureCountry)'
        : departureCountry;
    final arr = arrivalCity != null
        ? '$arrivalCity ($arrivalCountry)'
        : arrivalCountry;
    return '$dep -> $arr';
  }

  Announcement copyWith({
    double? availableKg,
    double? pricePerKg,
    AnnouncementType? type,
    AnnouncementStatus? status,
    String? description,
    String? flightNumber,
    String? airline,
    List<String>? acceptedItems,
    List<String>? rejectedItems,
    bool? collectAtAirport,
    bool? deliverToAddress,
    String? meetingPoint,
  }) {
    return Announcement(
      id: id,
      userId: userId,
      departureCity: departureCity,
      departureCountry: departureCountry,
      arrivalCity: arrivalCity,
      arrivalCountry: arrivalCountry,
      departureDate: departureDate,
      arrivalDate: arrivalDate,
      availableKg: availableKg ?? this.availableKg,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      bookedKg: bookedKg,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      flightNumber: flightNumber ?? this.flightNumber,
      airline: airline ?? this.airline,
      acceptedItems: acceptedItems ?? this.acceptedItems,
      rejectedItems: rejectedItems ?? this.rejectedItems,
      collectAtAirport: collectAtAirport ?? this.collectAtAirport,
      deliverToAddress: deliverToAddress ?? this.deliverToAddress,
      meetingPoint: meetingPoint ?? this.meetingPoint,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      traveler: traveler,
    );
  }
}
