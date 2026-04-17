import 'package:gp_link/config/constants.dart';
import 'package:gp_link/services/supabase_service.dart';

class Pricing {
  final int standardAnnouncement;
  final int boostedAnnouncement;
  final int extension;
  final int extraAnnouncement;
  final int announcementDurationDays;
  final String currencyCode;
  final String currencySymbol;

  const Pricing({
    required this.standardAnnouncement,
    required this.boostedAnnouncement,
    required this.extension,
    required this.extraAnnouncement,
    required this.announcementDurationDays,
    this.currencyCode = 'XAF',
    this.currencySymbol = 'FCFA',
  });

  factory Pricing.defaults() => Pricing(
        standardAnnouncement: AppConstants.defaultPriceStandard,
        boostedAnnouncement: AppConstants.defaultPriceBoosted,
        extension: AppConstants.defaultPriceExtension,
        extraAnnouncement: AppConstants.defaultPriceExtra,
        announcementDurationDays: AppConstants.announcementDurationDays,
      );

  int priceFor(AnnouncementType type) => switch (type) {
        AnnouncementType.standard => standardAnnouncement,
        AnnouncementType.boosted => boostedAnnouncement,
      };
}

class AppConfigService {
  /// Lit les prix dans la devise du pays de l'utilisateur.
  /// Fallback sur les clés sans suffixe devise si absentes.
  Future<Pricing> fetchPricing({
    String currencyCode = 'XAF',
    String currencySymbol = 'FCFA',
  }) async {
    try {
      final suffixes = ['_$currencyCode', ''];
      final keys = <String>[];
      for (final type in [
        'standard',
        'boosted',
        'extension',
        'extra_announcement',
      ]) {
        for (final s in suffixes) {
          keys.add('price_$type$s');
        }
      }
      keys.add('announcement_duration_days');

      final result = await SupabaseService.from(AppConstants.appConfigTable)
          .select('key, value')
          .inFilter('key', keys);
      final map = <String, String>{};
      for (final row in (result as List)) {
        final k = row['key'] as String;
        final v = row['value'];
        map[k] = v is String ? v : v.toString();
      }
      int parseWithFallback(String type, int def) {
        for (final s in suffixes) {
          final raw = (map['price_$type$s'] ?? '').replaceAll('"', '');
          final v = int.tryParse(raw);
          if (v != null) return v;
        }
        return def;
      }

      return Pricing(
        standardAnnouncement:
            parseWithFallback('standard', AppConstants.defaultPriceStandard),
        boostedAnnouncement:
            parseWithFallback('boosted', AppConstants.defaultPriceBoosted),
        extension:
            parseWithFallback('extension', AppConstants.defaultPriceExtension),
        extraAnnouncement: parseWithFallback(
            'extra_announcement', AppConstants.defaultPriceExtra),
        announcementDurationDays: int.tryParse(
                (map['announcement_duration_days'] ?? '').replaceAll('"', '')) ??
            AppConstants.announcementDurationDays,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
      );
    } catch (_) {
      return Pricing.defaults();
    }
  }
}
