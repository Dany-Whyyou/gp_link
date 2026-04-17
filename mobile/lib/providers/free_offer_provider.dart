import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/services/supabase_service.dart';

class FreeOfferInfo {
  final bool hasFreeFirst;
  final int promoRemaining;

  const FreeOfferInfo({
    required this.hasFreeFirst,
    required this.promoRemaining,
  });

  bool get hasAnyFree => hasFreeFirst || promoRemaining > 0;
}

/// Détermine si l'utilisateur bénéficie d'une annonce gratuite.
/// Côté mobile on fait une approximation - la vérité est côté serveur
/// dans mypvit-initiate.
final freeOfferProvider = FutureProvider<FreeOfferInfo>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) {
    return const FreeOfferInfo(hasFreeFirst: false, promoRemaining: 0);
  }

  // Récupère les configs promo
  final configRows = await SupabaseService.from('app_config')
      .select('key, value')
      .inFilter('key', [
    'free_first_announcement',
    'promo_active',
    'promo_free_count',
    'promo_start_date',
    'promo_end_date',
  ]);
  final cfg = <String, String>{};
  for (final row in (configRows as List)) {
    final v = row['value'];
    cfg[row['key'] as String] = v is String ? v : v.toString();
  }

  bool asBool(String? v) => v == 'true' || v == '"true"';
  int? asInt(String? v) => v == null ? null : int.tryParse(v.replaceAll('"', ''));
  DateTime? asDate(String? v) =>
      v == null ? null : DateTime.tryParse(v.replaceAll('"', ''));

  bool hasFreeFirst = false;
  int promoRemaining = 0;

  // Compte les annonces complétées de l'user
  final completedRes = await SupabaseService.from('payments')
      .select('id, amount, paid_at')
      .eq('user_id', userId)
      .eq('type', 'announcement')
      .eq('status', 'completed');
  final completed = (completedRes as List);

  // 1. Première annonce gratuite (à vie)
  if (asBool(cfg['free_first_announcement']) && completed.isEmpty) {
    hasFreeFirst = true;
  }

  // 2. Promo
  if (asBool(cfg['promo_active'])) {
    final now = DateTime.now();
    final start = asDate(cfg['promo_start_date']);
    final end = asDate(cfg['promo_end_date']);
    final count = asInt(cfg['promo_free_count']) ?? 0;
    final withinWindow =
        (start == null || !now.isBefore(start)) &&
        (end == null || !now.isAfter(end));
    if (withinWindow && count > 0) {
      int usedInPromo = 0;
      for (final p in completed) {
        final amount = p['amount'];
        final paidAt = p['paid_at'] != null
            ? DateTime.tryParse(p['paid_at'] as String)
            : null;
        final amountInt = amount is int ? amount : (amount as num?)?.toInt() ?? -1;
        if (amountInt != 0 || paidAt == null) continue;
        if (start != null && paidAt.isBefore(start)) continue;
        if (end != null && paidAt.isAfter(end)) continue;
        usedInPromo++;
      }
      promoRemaining = count - usedInPromo;
      if (promoRemaining < 0) promoRemaining = 0;
    }
  }

  return FreeOfferInfo(
    hasFreeFirst: hasFreeFirst,
    promoRemaining: promoRemaining,
  );
});
