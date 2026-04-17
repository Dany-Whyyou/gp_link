import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gp_link/models/conversation.dart';
import 'package:gp_link/models/message.dart';
import 'package:gp_link/services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// -- Conversations list --
final conversationsProvider =
    FutureProvider<List<Conversation>>((ref) async {
  final service = ref.read(chatServiceProvider);
  return service.getConversations();
});

// -- Unread count --
final unreadChatCountProvider = FutureProvider<int>((ref) async {
  final service = ref.read(chatServiceProvider);
  return service.getTotalUnreadCount();
});

// -- Messages for a conversation --
class ChatMessagesState {
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const ChatMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  ChatMessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  final ChatService _service;
  final String conversationId;
  final Ref _ref;
  StreamSubscription<Message>? _subscription;

  ChatMessagesNotifier(this._service, this.conversationId, this._ref)
      : super(const ChatMessagesState()) {
    _loadMessages();
    _subscribeToRealtime();
  }

  Future<void> _loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _service.getMessages(conversationId);
      state = ChatMessagesState(messages: messages);
      // Mark as read
      await _service.markAsRead(conversationId);
      _ref.invalidate(unreadChatCountProvider);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur de chargement des messages.',
      );
    }
  }

  void _subscribeToRealtime() {
    _subscription = _service
        .subscribeToMessages(conversationId)
        .listen((message) {
      // Add new message to the top (messages are sorted newest first)
      state = state.copyWith(
        messages: [message, ...state.messages],
      );
      // Mark as read
      _service.markAsRead(conversationId);
    });
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    state = state.copyWith(isSending: true);
    try {
      final message = await _service.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
      );
      // Add to list (will also come via realtime, deduplicate)
      if (!state.messages.any((m) => m.id == message.id)) {
        state = state.copyWith(
          messages: [message, ...state.messages],
          isSending: false,
        );
      } else {
        state = state.copyWith(isSending: false);
      }
      _ref.invalidate(conversationsProvider);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: 'Erreur d\'envoi du message.',
      );
    }
  }

  Future<void> refresh() => _loadMessages();

  @override
  void dispose() {
    _subscription?.cancel();
    _service.unsubscribe();
    super.dispose();
  }
}

final chatMessagesProvider = StateNotifierProvider.family<
    ChatMessagesNotifier, ChatMessagesState, String>((ref, conversationId) {
  final service = ref.read(chatServiceProvider);
  return ChatMessagesNotifier(service, conversationId, ref);
});
