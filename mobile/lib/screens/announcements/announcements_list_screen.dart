import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/announcement_provider.dart';
import 'package:gp_link/providers/notification_provider.dart';
import 'package:gp_link/widgets/announcement_card.dart';
import 'package:gp_link/widgets/empty_state.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class AnnouncementsListScreen extends ConsumerStatefulWidget {
  const AnnouncementsListScreen({super.key});

  @override
  ConsumerState<AnnouncementsListScreen> createState() =>
      _AnnouncementsListScreenState();
}

class _AnnouncementsListScreenState
    extends ConsumerState<AnnouncementsListScreen> {
  final _scrollController = ScrollController();
  bool _showFilters = false;
  final _departureCityController = TextEditingController();
  final _arrivalCityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(announcementsProvider.notifier).loadMore();
    }
  }

  void _applyFilters() {
    final departure = _departureCityController.text.trim();
    final arrival = _arrivalCityController.text.trim();

    ref.read(announcementFilterProvider.notifier).state = AnnouncementFilter(
      departureCity: departure.isNotEmpty ? departure : null,
      arrivalCity: arrival.isNotEmpty ? arrival : null,
    );
    ref.read(announcementsProvider.notifier).refresh();
    setState(() => _showFilters = false);
  }

  void _clearFilters() {
    _departureCityController.clear();
    _arrivalCityController.clear();
    ref.read(announcementFilterProvider.notifier).state =
        const AnnouncementFilter();
    ref.read(announcementsProvider.notifier).refresh();
    setState(() => _showFilters = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _departureCityController.dispose();
    _arrivalCityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementsProvider);
    final filter = ref.watch(announcementFilterProvider);
    final unreadNotif = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if ((unreadNotif.valueOrNull ?? 0) > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${unreadNotif.valueOrNull}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: filter.hasFilters ? AppTheme.primaryGold : null,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters panel
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _departureCityController,
                          decoration: const InputDecoration(
                            labelText: 'Départ',
                            hintText: 'Ville de départ',
                            prefixIcon:
                                Icon(Icons.flight_takeoff, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _arrivalCityController,
                          decoration: const InputDecoration(
                            labelText: 'Arrivée',
                            hintText: 'Ville d\'arrivée',
                            prefixIcon:
                                Icon(Icons.flight_land, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearFilters,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text('Effacer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text('Rechercher'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Active filter chips
          if (filter.hasFilters && !_showFilters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  if (filter.departureCity != null)
                    Chip(
                      label: Text('De: ${filter.departureCity}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(announcementFilterProvider.notifier).state =
                            AnnouncementFilter(arrivalCity: filter.arrivalCity);
                        ref.read(announcementsProvider.notifier).refresh();
                      },
                    ),
                  if (filter.arrivalCity != null)
                    Chip(
                      label: Text('Vers: ${filter.arrivalCity}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(announcementFilterProvider.notifier).state =
                            AnnouncementFilter(
                                departureCity: filter.departureCity);
                        ref.read(announcementsProvider.notifier).refresh();
                      },
                    ),
                ],
              ),
            ),

          // List
          Expanded(
            child: _buildList(state),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AnnouncementsListState state) {
    if (state.isLoading && state.announcements.isEmpty) {
      return const ShimmerListLoader();
    }

    if (state.error != null && state.announcements.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(announcementsProvider.notifier).refresh(),
      );
    }

    if (state.announcements.isEmpty) {
      return EmptyState(
        icon: Icons.flight,
        title: 'Aucune annonce',
        subtitle: 'Aucune annonce ne correspond à votre recherche.',
        actionLabel: 'Rafraîchir',
        onAction: () => ref.read(announcementsProvider.notifier).refresh(),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: () => ref.read(announcementsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: state.announcements.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.announcements.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                ),
              ),
            );
          }

          final announcement = state.announcements[index];
          return AnnouncementCard(
            announcement: announcement,
            onTap: () =>
                context.push('/announcements/${announcement.id}'),
          );
        },
      ),
    );
  }
}
