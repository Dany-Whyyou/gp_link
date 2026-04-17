import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/payment.dart';
import 'package:gp_link/services/supabase_service.dart';

class PaymentInitiationResult {
  final String paymentId;
  final String reference;
  final int amount;
  final String? mypvitTransactionId;
  final String message;

  PaymentInitiationResult({
    required this.paymentId,
    required this.reference,
    required this.amount,
    required this.mypvitTransactionId,
    required this.message,
  });

  factory PaymentInitiationResult.fromJson(Map<String, dynamic> json) {
    return PaymentInitiationResult(
      paymentId: json['payment_id'] as String,
      reference: json['reference'] as String,
      amount: (json['amount'] as num).toInt(),
      mypvitTransactionId: json['mypvit_transaction_id'] as String?,
      message: json['message'] as String? ?? '',
    );
  }
}

class PaymentException implements Exception {
  final String message;
  final Map<String, dynamic>? details;
  PaymentException(this.message, [this.details]);
  @override
  String toString() => 'PaymentException: $message';
}

class PaymentService {
  static const _table = AppConstants.paymentsTable;

  Future<PaymentInitiationResult> initiatePayment({
    required String announcementId,
    required String paymentType,
    required MobileMoneyOperator operator,
    required String phoneNumber,
  }) async {
    final session = SupabaseService.auth.currentSession;
    if (session == null) {
      throw PaymentException('Non authentifié');
    }

    final response = await http.post(
      Uri.parse(AppConstants.mypvitInitiateUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConstants.supabaseAnonKey,
      },
      body: jsonEncode({
        'announcement_id': announcementId,
        'payment_type': paymentType,
        'operator': operator.code,
        'phone_number': phoneNumber,
      }),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PaymentException(
        'Réponse invalide (${response.statusCode}) : ${response.body}',
      );
    }
    if (response.statusCode != 200) {
      final err = body['error']?.toString() ??
          body['msg']?.toString() ??
          body['message']?.toString() ??
          'Erreur de paiement';
      throw PaymentException(
        '[${response.statusCode}] $err',
        body['details'] as Map<String, dynamic>?,
      );
    }
    return PaymentInitiationResult.fromJson(body);
  }

  Future<Payment> getById(String id) async {
    final result = await SupabaseService.from(_table).select().eq('id', id).single();
    return Payment.fromJson(result);
  }

  Stream<Payment> watchPayment(String paymentId) async* {
    final deadline = DateTime.now().add(AppConstants.paymentPollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final payment = await getById(paymentId);
        yield payment;
        if (!payment.isPending) return;
      } catch (_) {
        // Transient error — retry on next tick
      }
      await Future<void>.delayed(AppConstants.paymentPollInterval);
    }
  }

  Future<List<Payment>> getMyPayments() async {
    final userId = SupabaseService.currentUserId!;
    final result = await SupabaseService.from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (result as List)
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Payment?> getPaymentForAnnouncement(String announcementId) async {
    final result = await SupabaseService.from(_table)
        .select()
        .eq('announcement_id', announcementId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (result == null) return null;
    return Payment.fromJson(result);
  }
}
