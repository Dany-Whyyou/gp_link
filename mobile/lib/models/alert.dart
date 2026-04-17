import 'package:gp_link/config/constants.dart';

class Alert {
  final String id;
  final String userId;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDateMin;
  final DateTime? departureDateMax;
  final double? maxPricePerKg;
  final double? minKg;
  final AlertStatus status;
  final int matchCount;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Alert({
    required this.id,
    required this.userId,
    this.departureCity,
    this.arrivalCity,
    this.departureDateMin,
    this.departureDateMax,
    this.maxPricePerKg,
    this.minKg,
    this.status = AlertStatus.active,
    this.matchCount = 0,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      departureCity: json['departure_city'] as String?,
      arrivalCity: json['arrival_city'] as String?,
      departureDateMin: json['departure_date_min'] != null
          ? DateTime.parse(json['departure_date_min'] as String)
          : null,
      departureDateMax: json['departure_date_max'] != null
          ? DateTime.parse(json['departure_date_max'] as String)
          : null,
      maxPricePerKg: (json['max_price_per_kg'] as num?)?.toDouble(),
      minKg: (json['min_kg'] as num?)?.toDouble(),
      status: AlertStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'active'),
        orElse: () => AlertStatus.active,
      ),
      matchCount: json['match_count'] as int? ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'departure_city': departureCity,
      'arrival_city': arrivalCity,
      'departure_date_min': departureDateMin?.toIso8601String(),
      'departure_date_max': departureDateMax?.toIso8601String(),
      'max_price_per_kg': maxPricePerKg,
      'min_kg': minKg,
      'status': status.name,
    };
  }

  String get routeLabel {
    final from = departureCity ?? 'Toutes villes';
    final to = arrivalCity ?? 'Toutes villes';
    return '$from -> $to';
  }

  bool get isActive => status == AlertStatus.active;

  Alert copyWith({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateMin,
    DateTime? departureDateMax,
    double? maxPricePerKg,
    double? minKg,
    AlertStatus? status,
  }) {
    return Alert(
      id: id,
      userId: userId,
      departureCity: departureCity ?? this.departureCity,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      departureDateMin: departureDateMin ?? this.departureDateMin,
      departureDateMax: departureDateMax ?? this.departureDateMax,
      maxPricePerKg: maxPricePerKg ?? this.maxPricePerKg,
      minKg: minKg ?? this.minKg,
      status: status ?? this.status,
      matchCount: matchCount,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
