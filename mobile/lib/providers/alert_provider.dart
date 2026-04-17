import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/models/alert.dart';
import 'package:gp_link/services/alert_service.dart';

final alertServiceProvider =
    Provider<AlertService>((ref) => AlertService());

final myAlertsProvider = FutureProvider<List<Alert>>((ref) async {
  final service = ref.read(alertServiceProvider);
  return service.getMyAlerts();
});

final activeAlertsProvider = FutureProvider<List<Alert>>((ref) async {
  final service = ref.read(alertServiceProvider);
  return service.getActiveAlerts();
});

// -- Alert operations notifier --
class AlertOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final AlertService _service;
  final Ref _ref;

  AlertOperationsNotifier(this._service, this._ref)
      : super(const AsyncData(null));

  Future<Alert?> createAlert({
    String? departureCountry,
    String? arrivalCountry,
    DateTime? departureDateMin,
    DateTime? departureDateMax,
    double? maxPricePerKg,
    double? minKg,
  }) async {
    state = const AsyncLoading();
    try {
      final alert = await _service.create(
        departureCountry: departureCountry,
        arrivalCountry: arrivalCountry,
        departureDateMin: departureDateMin,
        departureDateMax: departureDateMax,
        maxPricePerKg: maxPricePerKg,
        minKg: minKg,
      );
      state = const AsyncData(null);
      _ref.invalidate(myAlertsProvider);
      return alert;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return null;
    }
  }

  Future<void> togglePause(Alert alert) async {
    state = const AsyncLoading();
    try {
      if (alert.isActive) {
        await _service.pause(alert.id);
      } else {
        await _service.resume(alert.id);
      }
      state = const AsyncData(null);
      _ref.invalidate(myAlertsProvider);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> deleteAlert(String id) async {
    state = const AsyncLoading();
    try {
      await _service.delete(id);
      state = const AsyncData(null);
      _ref.invalidate(myAlertsProvider);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final alertOperationsProvider =
    StateNotifierProvider<AlertOperationsNotifier, AsyncValue<void>>((ref) {
  final service = ref.read(alertServiceProvider);
  return AlertOperationsNotifier(service, ref);
});
