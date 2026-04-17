import 'package:gp_link/config/constants.dart';

class Profile {
  final String id;
  final String? phone;
  final String? email;
  final String fullName;
  final UserRole role;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? country;
  final bool isVerified;
  final bool isBlocked;
  final double rating;
  final int totalTrips;
  final int totalDeliveries;
  final String? oneSignalPlayerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    this.phone,
    this.email,
    required this.fullName,
    this.role = UserRole.client,
    this.avatarUrl,
    this.bio,
    this.city,
    this.country,
    this.isVerified = false,
    this.isBlocked = false,
    this.rating = 0.0,
    this.totalTrips = 0,
    this.totalDeliveries = 0,
    this.oneSignalPlayerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      fullName: json['full_name'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (json['role'] as String? ?? 'client'),
        orElse: () => UserRole.client,
      ),
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: json['total_trips'] as int? ?? 0,
      totalDeliveries: json['total_deliveries'] as int? ?? 0,
      oneSignalPlayerId: json['onesignal_player_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'avatar_url': avatarUrl,
      'bio': bio,
      'city': city,
      'country': country,
      'is_verified': isVerified,
      'is_blocked': isBlocked,
      'rating': rating,
      'total_trips': totalTrips,
      'total_deliveries': totalDeliveries,
      'onesignal_player_id': oneSignalPlayerId,
    };
  }

  Profile copyWith({
    String? phone,
    String? email,
    String? fullName,
    UserRole? role,
    String? avatarUrl,
    String? bio,
    String? city,
    String? country,
    bool? isVerified,
    double? rating,
    int? totalTrips,
    int? totalDeliveries,
    String? oneSignalPlayerId,
  }) {
    return Profile(
      id: id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      country: country ?? this.country,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      oneSignalPlayerId: oneSignalPlayerId ?? this.oneSignalPlayerId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  bool get isVoyageur => role == UserRole.voyageur;
  bool get isClient => role == UserRole.client;
  bool get isAdmin => role == UserRole.admin;
}
