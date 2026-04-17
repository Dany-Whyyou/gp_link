import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/models/notification.dart';
import 'package:gp_link/services/notification_service.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final service = ref.read(notificationServiceProvider);
  return service.getNotifications();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final service = ref.read(notificationServiceProvider);
  return service.getUnreadCount();
});

class NotificationOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationService _service;
  final Ref _ref;

  NotificationOperationsNotifier(this._service, this._ref)
      : super(const AsyncData(null));

  Future<void> markAsRead(String id) async {
    try {
      await _service.markAsRead(id);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    state = const AsyncLoading();
    try {
      await _service.markAllAsRead();
      state = const AsyncData(null);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _service.delete(id);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    state = const AsyncLoading();
    try {
      await _service.deleteAll();
      state = const AsyncData(null);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final notificationOperationsProvider = StateNotifierProvider<
    NotificationOperationsNotifier, AsyncValue<void>>((ref) {
  final service = ref.read(notificationServiceProvider);
  return NotificationOperationsNotifier(service, ref);
});
