import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/notification.dart';
import 'package:gp_link/services/supabase_service.dart';

class NotificationService {
  static const _table = AppConstants.notificationsTable;

  /// Get notifications for the current user.
  Future<List<AppNotification>> getNotifications({
    int page = 0,
    int pageSize = AppConstants.pageSize,
  }) async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return (result as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  /// Get unread notification count.
  Future<int> getUnreadCount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return 0;

    final result = await SupabaseService.from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (result as List).length;
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String id) async {
    await SupabaseService.from(_table)
        .update({'is_read': true}).eq('id', id);
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    final userId = SupabaseService.currentUserId!;
    await SupabaseService.from(_table)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Delete a notification.
  Future<void> delete(String id) async {
    await SupabaseService.from(_table).delete().eq('id', id);
  }

  /// Delete all notifications for the current user.
  Future<void> deleteAll() async {
    final userId = SupabaseService.currentUserId!;
    await SupabaseService.from(_table).delete().eq('user_id', userId);
  }
}
