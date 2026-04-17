/// App-wide constants for GP Link
class AppConstants {
  AppConstants._();

  // -- App info --
  static const String appName = 'GP Link';
  static const String appTagline = 'Envoyez vos colis, voyagez léger';
  static const String currency = 'XAF';
  static const String currencySymbol = 'FCFA';

  // -- Supabase --
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vppdjobdmeuoqnqlxaez.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // -- MyPvit --
  // The app never calls MyPvit directly: it goes through the mypvit-initiate Edge Function.
  static String get mypvitInitiateUrl => '$supabaseUrl/functions/v1/mypvit-initiate';

  // -- OneSignal --
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '',
  );

  // -- Default pricing (FCFA) - fallback values if app_config fetch fails --
  static const int defaultPriceStandard = 1500;
  static const int defaultPriceBoosted = 3000;
  static const int defaultPriceExtension = 1000;
  static const int defaultPriceExtra = 2000;

  // -- Limits --
  static const int maxActiveAnnouncements = 1;
  static const int maxKgPerAnnouncement = 50;
  static const int minKgPerAnnouncement = 1;
  static const int announcementDurationDays = 7;
  static const int boostedDurationDays = 7;

  // -- Payment polling --
  static const Duration paymentPollInterval = Duration(seconds: 5);
  static const Duration paymentPollTimeout = Duration(minutes: 3);

  // -- Pagination --
  static const int pageSize = 20;

  // -- Phone auth --
  static const String defaultCountryCode = '+241'; // Gabon

  // -- Storage buckets --
  static const String avatarsBucket = 'avatars';
  static const String documentsBucket = 'documents';

  // -- Supabase tables --
  static const String profilesTable = 'profiles';
  static const String announcementsTable = 'announcements';
  static const String alertsTable = 'alerts';
  static const String bookingsTable = 'bookings';
  static const String paymentsTable = 'payments';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  static const String reviewsTable = 'reviews';
  static const String reportsTable = 'reports';
  static const String notificationsTable = 'notifications';
  static const String citiesTable = 'cities';
  static const String appConfigTable = 'app_config';
}

/// User roles
enum UserRole {
  client,
  voyageur,
  admin;

  String get label {
    switch (this) {
      case UserRole.client:
        return 'Client';
      case UserRole.voyageur:
        return 'Voyageur';
      case UserRole.admin:
        return 'Administrateur';
    }
  }
}

/// Announcement status
enum AnnouncementStatus {
  pendingPayment('pending_payment'),
  active('active'),
  expired('expired'),
  suspended('suspended'),
  completed('completed');

  const AnnouncementStatus(this.value);
  final String value;

  static AnnouncementStatus fromString(String s) {
    return AnnouncementStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => AnnouncementStatus.pendingPayment,
    );
  }

  String get label {
    switch (this) {
      case AnnouncementStatus.pendingPayment:
        return 'En attente de paiement';
      case AnnouncementStatus.active:
        return 'Active';
      case AnnouncementStatus.expired:
        return 'Expirée';
      case AnnouncementStatus.suspended:
        return 'Suspendue';
      case AnnouncementStatus.completed:
        return 'Terminée';
    }
  }
}

/// Announcement type
enum AnnouncementType {
  standard,
  boosted;

  String get label {
    switch (this) {
      case AnnouncementType.standard:
        return 'Standard';
      case AnnouncementType.boosted:
        return 'Boosté';
    }
  }

  int get defaultPrice {
    switch (this) {
      case AnnouncementType.standard:
        return AppConstants.defaultPriceStandard;
      case AnnouncementType.boosted:
        return AppConstants.defaultPriceBoosted;
    }
  }
}

/// Payment status
enum PaymentStatus {
  pending,
  completed,
  failed,
  expired,
  refunded;

  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'En attente';
      case PaymentStatus.completed:
        return 'Complété';
      case PaymentStatus.failed:
        return 'Échoué';
      case PaymentStatus.expired:
        return 'Expiré';
      case PaymentStatus.refunded:
        return 'Remboursé';
    }
  }

  static PaymentStatus fromString(String s) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Mobile Money operator
enum MobileMoneyOperator {
  airtel('AIRTEL_MONEY'),
  moov('MOOV_MONEY'),
  test('TEST');

  const MobileMoneyOperator(this.code);
  final String code;

  String get label {
    switch (this) {
      case MobileMoneyOperator.airtel:
        return 'Airtel Money';
      case MobileMoneyOperator.moov:
        return 'Moov Money';
      case MobileMoneyOperator.test:
        return 'Test (sandbox)';
    }
  }

  static MobileMoneyOperator? fromCode(String? code) {
    if (code == null) return null;
    for (final op in MobileMoneyOperator.values) {
      if (op.code == code) return op;
    }
    return null;
  }
}

/// Booking status
enum BookingStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  completed;

  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'En attente';
      case BookingStatus.accepted:
        return 'Acceptée';
      case BookingStatus.rejected:
        return 'Refusée';
      case BookingStatus.cancelled:
        return 'Annulée';
      case BookingStatus.completed:
        return 'Terminée';
    }
  }
}

/// Alert status
enum AlertStatus {
  active,
  paused,
  expired;

  String get label {
    switch (this) {
      case AlertStatus.active:
        return 'Active';
      case AlertStatus.paused:
        return 'En pause';
      case AlertStatus.expired:
        return 'Expirée';
    }
  }
}
