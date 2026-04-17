import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/announcement.dart';

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback? onTap;
  final bool showTravelerInfo;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onTap,
    this.showTravelerInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boosted badge
            if (announcement.isBoosted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primarySky, AppTheme.accentOrange],
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'ANNONCE BOOSTEE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route
                  Row(
                    children: [
                      const Icon(Icons.flight_takeoff,
                          size: 18, color: AppTheme.gabonGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          announcement.departureCity ?? announcement.departureCountry,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward,
                          size: 16, color: AppTheme.primarySky),
                      const SizedBox(width: 6),
                      const Icon(Icons.flight_land,
                          size: 18, color: AppTheme.primarySky),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          announcement.arrivalCity ?? announcement.arrivalCountry,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(announcement.departureDate),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (announcement.airline != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.airlines,
                            size: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          announcement.airline!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),

                  const Divider(height: 20),

                  // KG and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        label:
                            '${announcement.remainingKg.toStringAsFixed(1)} kg dispo',
                        color: announcement.hasSpace
                            ? AppTheme.gabonGreen
                            : AppTheme.error,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySky.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${announcement.pricePerKg.toStringAsFixed(0)} ${AppConstants.currencySymbol}/kg',
                          style: const TextStyle(
                            color: AppTheme.primaryNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Traveler info
                  if (showTravelerInfo && announcement.traveler != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              AppTheme.primarySky.withValues(alpha: 0.2),
                          child: Text(
                            announcement.traveler!.initials,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          announcement.traveler!.fullName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (announcement.traveler!.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              size: 14, color: AppTheme.primarySky),
                        ],
                        const Spacer(),
                        if (announcement.traveler!.rating > 0)
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: AppTheme.accentOrange),
                              const SizedBox(width: 2),
                              Text(
                                announcement.traveler!.rating
                                    .toStringAsFixed(1),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
