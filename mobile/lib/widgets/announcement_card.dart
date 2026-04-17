import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/announcement.dart';
import 'package:gp_link/models/country.dart';
import 'package:gp_link/providers/country_provider.dart';

class AnnouncementCard extends ConsumerWidget {
  final Announcement announcement;
  final VoidCallback? onTap;
  final bool showTravelerInfo;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onTap,
    this.showTravelerInfo = true,
  });

  Country? _country(List<Country> countries, String name) {
    for (final c in countries) {
      if (c.name == name) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    final countries = ref.watch(countriesProvider).valueOrNull ?? [];
    final depCountry = _country(countries, announcement.departureCountry);
    final arrCountry = _country(countries, announcement.arrivalCountry);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: announcement.isBoosted
                  ? const Color(0xFFFFF7ED) // Orange très pâle
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: announcement.isBoosted
                    ? AppTheme.accentOrange.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
                width: announcement.isBoosted ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (announcement.isBoosted) _boostedStrip(),
                _routeHero(depCountry, arrCountry),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            dateFormat.format(announcement.departureDate),
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrange.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${announcement.pricePerKg.toStringAsFixed(0)} FCFA/kg',
                              style: const TextStyle(
                                color: AppTheme.accentOrangeDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showTravelerInfo &&
                          announcement.traveler != null) ...[
                        const SizedBox(height: 12),
                        _travelerRow(context),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _boostedStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentOrange, AppTheme.accentOrangeDark],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rocket_launch, size: 13, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'ANNONCE BOOSTÉE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeHero(Country? dep, Country? arr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _endpoint(
              flag: dep?.flagEmoji ?? '🌍',
              country: announcement.departureCountry,
              city: announcement.departureCity,
              alignStart: true,
            ),
          ),
          SizedBox(
            width: 80,
            child: CustomPaint(
              size: const Size(80, 32),
              painter: _PathPainter(),
              child: const Center(
                child: Icon(Icons.flight,
                    color: AppTheme.primarySky, size: 22),
              ),
            ),
          ),
          Expanded(
            child: _endpoint(
              flag: arr?.flagEmoji ?? '🌍',
              country: announcement.arrivalCountry,
              city: announcement.arrivalCity,
              alignStart: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _endpoint({
    required String flag,
    required String country,
    required String? city,
    required bool alignStart,
  }) {
    final cross =
        alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(flag, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 4),
        Text(
          country,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.primaryNavy,
          ),
          textAlign: alignStart ? TextAlign.start : TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (city != null && city.isNotEmpty)
          Text(
            city,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: alignStart ? TextAlign.start : TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _travelerRow(BuildContext context) {
    final t = announcement.traveler!;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppTheme.primarySky.withValues(alpha: 0.15),
          backgroundImage:
              t.avatarUrl != null ? NetworkImage(t.avatarUrl!) : null,
          child: t.avatarUrl == null
              ? Text(
                  t.initials,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNavy,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            t.fullName,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (t.isVerified) ...[
          const SizedBox(width: 4),
          const Icon(Icons.verified, size: 14, color: AppTheme.primarySky),
        ],
        const Spacer(),
        if (t.rating > 0)
          Row(
            children: [
              const Icon(Icons.star, size: 13, color: AppTheme.accentOrange),
              const SizedBox(width: 2),
              Text(
                t.rating.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ],
    );
  }
}

class _PathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primarySky.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final midY = size.height / 2;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, midY),
        Offset(startX + dashWidth, midY),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    final dotPaint = Paint()
      ..color = AppTheme.accentOrange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, midY), 3, dotPaint);
    canvas.drawCircle(Offset(size.width, midY), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
