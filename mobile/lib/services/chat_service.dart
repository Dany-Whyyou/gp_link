import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/conversation.dart';
import 'package:gp_link/models/message.dart';
import 'package:gp_link/services/supabase_service.dart';

class ChatService {
  RealtimeChannel? _messagesChannel;

  /// Get all conversations for the current user.
  Future<List<Conversation>> getConversations() async {
    final userId = SupabaseService.currentUserId!;

    final result = await SupabaseService.from(AppConstants.conversationsTable)
        .select()
        .or('participant_1_id.eq.$userId,participant_2_id.eq.$userId')
        .order('last_message_at', ascending: false, nullsFirst: false);

    final conversations = <Conversation>[];
    for (final row in result as List) {
      final conv = Conversation.fromJson(row, currentUserId: userId);

      // Fetch other participant's profile
      final otherId = conv.otherParticipantId(userId);
      final profileResult = await SupabaseService.from(AppConstants.profilesTable)
          .select()
          .eq('id', otherId)
          .maybeSingle();

      if (profileResult != null) {
        conversations.add(Conversation.fromJson(
          {...row, 'other_participant': profileResult},
          currentUserId: userId,
        ));
      } else {
        conversations.add(conv);
      }
    }

    return conversations;
  }

  /// Get or create a conversation between two users.
  Future<Conversation> getOrCreateConversation({
    required String otherUserId,
    String? announcementId,
    String? bookingId,
  }) async {
    final userId = SupabaseService.currentUserId!;

    // Check existing
    final existing =
        await SupabaseService.from(AppConstants.conversationsTable)
            .select()
            .or(
              'and(participant_1_id.eq.$userId,participant_2_id.eq.$otherUserId),'
              'and(participant_1_id.eq.$otherUserId,participant_2_id.eq.$userId)',
            )
            .maybeSingle();

    if (existing != null) {
      return Conversation.fromJson(existing, currentUserId: userId);
    }

    // Create new
    final data = {
      'participant_1_id': userId,
      'participant_2_id': otherUserId,
      'announcement_id': announcementId,
      'booking_id': bookingId,
    };

    final result = await SupabaseService.from(AppConstants.conversationsTable)
        .insert(data)
        .select()
        .single();

    return Conversation.fromJson(result, currentUserId: userId);
  }

  /// Get messages for a conversation, paginated.
  Future<List<Message>> getMessages(
    String conversationId, {
    int page = 0,
    int pageSize = 50,
  }) async {
    final result = await SupabaseService.from(AppConstants.messagesTable)
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return (result as List).map((e) => Message.fromJson(e)).toList();
  }

  /// Send a text message.
  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String type = 'text',
  }) async {
    final userId = SupabaseService.currentUserId!;

    final data = {
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
      'type': type,
    };

    final result = await SupabaseService.from(AppConstants.messagesTable)
        .insert(data)
        .select()
        .single();

    // Update conversation last message
    await SupabaseService.from(AppConstants.conversationsTable)
        .update({
          'last_message_text': content,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .eq('id', conversationId);

    return Message.fromJson(result);
  }

  /// Mark all messages in a conversation as read.
  Future<void> markAsRead(String conversationId) async {
    final userId = SupabaseService.currentUserId!;

    await SupabaseService.from(AppConstants.messagesTable)
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('is_read', false);

    // Reset unread count
    final conv = await SupabaseService.from(AppConstants.conversationsTable)
        .select()
        .eq('id', conversationId)
        .single();

    final updateField = conv['participant_1_id'] == userId
        ? 'unread_count_1'
        : 'unread_count_2';

    await SupabaseService.from(AppConstants.conversationsTable)
        .update({updateField: 0}).eq('id', conversationId);
  }

  /// Subscribe to new messages in a conversation via Supabase Realtime.
  Stream<Message> subscribeToMessages(String conversationId) {
    final controller = StreamController<Message>.broadcast();

    _messagesChannel = SupabaseService.client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final message = Message.fromJson(payload.newRecord);
            controller.add(message);
          },
        )
        .subscribe();

    controller.onCancel = () {
      unsubscribe();
    };

    return controller.stream;
  }

  /// Unsubscribe from realtime messages.
  Future<void> unsubscribe() async {
    if (_messagesChannel != null) {
      await SupabaseService.client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  /// Get unread message count across all conversations.
  Future<int> getTotalUnreadCount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return 0;

    final result =
        await SupabaseService.from(AppConstants.conversationsTable)
            .select('participant_1_id, participant_2_id, unread_count_1, unread_count_2')
            .or('participant_1_id.eq.$userId,participant_2_id.eq.$userId');

    int total = 0;
    for (final row in result as List) {
      if (row['participant_1_id'] == userId) {
        total += (row['unread_count_1'] as int? ?? 0);
      } else {
        total += (row['unread_count_2'] as int? ?? 0);
      }
    }
    return total;
  }
}
