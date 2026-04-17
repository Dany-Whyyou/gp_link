import 'package:gp_link/config/constants.dart';
import 'package:gp_link/services/supabase_service.dart';

class Pricing {
  final int standardAnnouncement;
  final int boostedAnnouncement;
  final int extension;
  final int extraAnnouncement;
  final int announcementDurationDays;

  const Pricing({
    required this.standardAnnouncement,
    required this.boostedAnnouncement,
    required this.extension,
    required this.extraAnnouncement,
    required this.announcementDurationDays,
  });

  factory Pricing.defaults() => Pricing(
        standardAnnouncement: AppConstants.defaultPriceStandard,
        boostedAnnouncement: AppConstants.defaultPriceBoosted,
        extension: AppConstants.defaultPriceExtension,
        extraAnnouncement: AppConstants.defaultPriceExtra,
        announcementDurationDays: AppConstants.announcementDurationDays,
      );

  factory Pricing.fromJson(Map<String, dynamic> json) => Pricing(
        standardAnnouncement:
            (json['standard_announcement'] as num?)?.toInt() ?? AppConstants.defaultPriceStandard,
        boostedAnnouncement:
            (json['boosted_announcement'] as num?)?.toInt() ?? AppConstants.defaultPriceBoosted,
        extension: (json['extension'] as num?)?.toInt() ?? AppConstants.defaultPriceExtension,
        extraAnnouncement:
            (json['extra_announcement'] as num?)?.toInt() ?? AppConstants.defaultPriceExtra,
        announcementDurationDays:
            (json['announcement_duration_days'] as num?)?.toInt() ??
                AppConstants.announcementDurationDays,
      );

  int priceFor(AnnouncementType type) => switch (type) {
        AnnouncementType.standard => standardAnnouncement,
        AnnouncementType.boosted => boostedAnnouncement,
      };
}

class AppConfigService {
  Future<Pricing> fetchPricing() async {
    try {
      final result = await SupabaseService.from(AppConstants.appConfigTable)
          .select('value')
          .eq('key', 'pricing')
          .maybeSingle();
      if (result == null) return Pricing.defaults();
      final value = result['value'];
      if (value is Map<String, dynamic>) return Pricing.fromJson(value);
      return Pricing.defaults();
    } catch (_) {
      return Pricing.defaults();
    }
  }
}
