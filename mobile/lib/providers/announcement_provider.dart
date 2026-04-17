import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/models/announcement.dart';
import 'package:gp_link/services/announcement_service.dart';

final announcementServiceProvider =
    Provider<AnnouncementService>((ref) => AnnouncementService());

// -- Filter state for search --
class AnnouncementFilter {
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDateMin;
  final DateTime? departureDateMax;
  final double? maxPricePerKg;
  final double? minKg;

  const AnnouncementFilter({
    this.departureCity,
    this.arrivalCity,
    this.departureDateMin,
    this.departureDateMax,
    this.maxPricePerKg,
    this.minKg,
  });

  AnnouncementFilter copyWith({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateMin,
    DateTime? departureDateMax,
    double? maxPricePerKg,
    double? minKg,
  }) {
    return AnnouncementFilter(
      departureCity: departureCity ?? this.departureCity,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      departureDateMin: departureDateMin ?? this.departureDateMin,
      departureDateMax: departureDateMax ?? this.departureDateMax,
      maxPricePerKg: maxPricePerKg ?? this.maxPricePerKg,
      minKg: minKg ?? this.minKg,
    );
  }

  bool get hasFilters =>
      departureCity != null ||
      arrivalCity != null ||
      departureDateMin != null ||
      departureDateMax != null ||
      maxPricePerKg != null ||
      minKg != null;
}

final announcementFilterProvider =
    StateProvider<AnnouncementFilter>((ref) => const AnnouncementFilter());

// -- Announcements list state --
class AnnouncementsListState {
  final List<Announcement> announcements;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int page;

  const AnnouncementsListState({
    this.announcements = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.page = 0,
  });

  AnnouncementsListState copyWith({
    List<Announcement>? announcements,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? page,
  }) {
    return AnnouncementsListState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      page: page ?? this.page,
    );
  }
}

class AnnouncementsNotifier extends StateNotifier<AnnouncementsListState> {
  final AnnouncementService _service;
  final Ref _ref;

  AnnouncementsNotifier(this._service, this._ref)
      : super(const AnnouncementsListState()) {
    loadAnnouncements();
  }

  Future<void> loadAnnouncements() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final filter = _ref.read(announcementFilterProvider);
      final results = await _service.getActiveAnnouncements(
        page: 0,
        departureCity: filter.departureCity,
        arrivalCity: filter.arrivalCity,
        departureDateMin: filter.departureDateMin,
        departureDateMax: filter.departureDateMax,
        maxPricePerKg: filter.maxPricePerKg,
        minKg: filter.minKg,
      );
      state = AnnouncementsListState(
        announcements: results,
        hasMore: results.length >= 20,
        page: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur de chargement des annonces.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final filter = _ref.read(announcementFilterProvider);
      final results = await _service.getActiveAnnouncements(
        page: nextPage,
        departureCity: filter.departureCity,
        arrivalCity: filter.arrivalCity,
        departureDateMin: filter.departureDateMin,
        departureDateMax: filter.departureDateMax,
        maxPricePerKg: filter.maxPricePerKg,
        minKg: filter.minKg,
      );
      state = state.copyWith(
        announcements: [...state.announcements, ...results],
        isLoadingMore: false,
        hasMore: results.length >= 20,
        page: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() => loadAnnouncements();
}

final announcementsProvider =
    StateNotifierProvider<AnnouncementsNotifier, AnnouncementsListState>((ref) {
  final service = ref.read(announcementServiceProvider);
  return AnnouncementsNotifier(service, ref);
});

// -- My announcements --
final myAnnouncementsProvider = FutureProvider<List<Announcement>>((ref) async {
  final service = ref.read(announcementServiceProvider);
  return service.getMyAnnouncements();
});

// -- Single announcement --
final announcementDetailProvider =
    FutureProvider.family<Announcement, String>((ref, id) async {
  final service = ref.read(announcementServiceProvider);
  return service.getById(id);
});

// -- Has active announcement --
final hasActiveAnnouncementProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(announcementServiceProvider);
  return service.hasActiveAnnouncement();
});
