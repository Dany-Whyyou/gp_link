import 'package:gp_link/config/constants.dart';

class Payment {
  final String id;
  final String userId;
  final String? announcementId;
  final String? bookingId;
  final double amount;
  final String currency;
  final String paymentType;
  final PaymentStatus status;
  final String? reference;
  final String? mypvitTransactionId;
  final String? paymentMethod;
  final String? operator;
  final String? phoneNumber;
  final DateTime? paidAt;
  final DateTime? failedAt;
  final bool needsReview;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.userId,
    this.announcementId,
    this.bookingId,
    required this.amount,
    this.currency = 'XAF',
    required this.paymentType,
    this.status = PaymentStatus.pending,
    this.reference,
    this.mypvitTransactionId,
    this.paymentMethod,
    this.operator,
    this.phoneNumber,
    this.paidAt,
    this.failedAt,
    this.needsReview = false,
    this.metadata,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      announcementId: json['announcement_id'] as String?,
      bookingId: json['booking_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'XAF',
      paymentType: json['type'] as String? ?? json['payment_type'] as String? ?? 'announcement',
      status: PaymentStatus.fromString(json['status'] as String? ?? 'pending'),
      reference: json['reference'] as String?,
      mypvitTransactionId: json['mypvit_transaction_id'] as String?,
      paymentMethod: json['payment_method'] as String?,
      operator: json['operator'] as String?,
      phoneNumber: json['phone_number'] as String?,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      failedAt: json['failed_at'] != null ? DateTime.parse(json['failed_at'] as String) : null,
      needsReview: json['needs_review'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isPending => status == PaymentStatus.pending;
  bool get isCompleted => status == PaymentStatus.completed;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isExpired => status == PaymentStatus.expired;

  String get amountFormatted =>
      '${amount.toStringAsFixed(0)} ${AppConstants.currencySymbol}';
}
