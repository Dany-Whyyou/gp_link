import 'package:gp_link/models/message.dart';
import 'package:gp_link/models/profile.dart';

class Conversation {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final String? announcementId;
  final String? bookingId;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount1;
  final int unreadCount2;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final Profile? otherParticipant;
  final Message? lastMessage;

  const Conversation({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    this.announcementId,
    this.bookingId,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount1 = 0,
    this.unreadCount2 = 0,
    required this.createdAt,
    required this.updatedAt,
    this.otherParticipant,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    Profile? otherParticipant;
    if (json['other_participant'] != null && json['other_participant'] is Map) {
      otherParticipant =
          Profile.fromJson(json['other_participant'] as Map<String, dynamic>);
    }

    return Conversation(
      id: json['id'] as String,
      participant1Id: json['participant_1_id'] as String,
      participant2Id: json['participant_2_id'] as String,
      announcementId: json['announcement_id'] as String?,
      bookingId: json['booking_id'] as String?,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount1: json['unread_count_1'] as int? ?? 0,
      unreadCount2: json['unread_count_2'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      otherParticipant: otherParticipant,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participant_1_id': participant1Id,
      'participant_2_id': participant2Id,
      'announcement_id': announcementId,
      'booking_id': bookingId,
    };
  }

  int unreadCountFor(String userId) {
    if (userId == participant1Id) return unreadCount1;
    if (userId == participant2Id) return unreadCount2;
    return 0;
  }

  String otherParticipantId(String currentUserId) {
    return currentUserId == participant1Id ? participant2Id : participant1Id;
  }

  bool hasUnread(String userId) => unreadCountFor(userId) > 0;
}
