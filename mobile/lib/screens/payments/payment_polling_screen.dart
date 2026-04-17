import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/payment.dart';
import 'package:gp_link/providers/announcement_provider.dart';
import 'package:gp_link/services/payment_service.dart';

class PaymentPollingScreen extends ConsumerStatefulWidget {
  final String paymentId;

  const PaymentPollingScreen({super.key, required this.paymentId});

  @override
  ConsumerState<PaymentPollingScreen> createState() => _PaymentPollingScreenState();
}

class _PaymentPollingScreenState extends ConsumerState<PaymentPollingScreen> {
  Stream<Payment>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = PaymentService().watchPayment(widget.paymentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: StreamBuilder<Payment>(
          stream: _stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const _LoadingState();
            }
            final payment = snapshot.data!;
            if (payment.isCompleted) {
              return _SuccessState(payment: payment, onClose: () => context.go('/home'));
            }
            if (payment.isFailed || payment.isExpired) {
              return _FailureState(
                payment: payment,
                onRetry: () => context.pop(),
                onClose: () => context.go('/home'),
              );
            }
            return const _WaitingState();
          },
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _WaitingState extends StatelessWidget {
  const _WaitingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 80,
            width: 80,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 32),
          const Text(
            'En attente de confirmation',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'Vérifiez votre téléphone et entrez votre code PIN pour confirmer le paiement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cette opération peut prendre jusqu\'à 3 minutes.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessState extends ConsumerWidget {
  final Payment payment;
  final VoidCallback onClose;

  const _SuccessState({required this.payment, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.invalidate(announcementsProvider);
    ref.invalidate(myAnnouncementsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppTheme.success, size: 64),
          ),
          const SizedBox(height: 32),
          const Text(
            'Paiement confirmé !',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            '${payment.amount.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
            style: const TextStyle(fontSize: 20, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 12),
          const Text(
            'Votre annonce est maintenant active.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              child: const Text('Retour à l\'accueil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  final Payment payment;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _FailureState({
    required this.payment,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = payment.isExpired;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpired ? Icons.timer_off : Icons.close,
              color: AppTheme.error,
              size: 64,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isExpired ? 'Délai dépassé' : 'Paiement échoué',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            isExpired
                ? 'Vous n\'avez pas confirmé le paiement à temps. Votre annonce n\'a pas été publiée.'
                : 'Le paiement n\'a pas pu être confirmé. Aucun montant n\'a été débité.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onClose,
              child: const Text('Retour à l\'accueil'),
            ),
          ),
        ],
      ),
    );
  }
}
