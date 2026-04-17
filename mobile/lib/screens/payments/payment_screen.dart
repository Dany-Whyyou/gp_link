import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/services/payment_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String announcementId;
  final String paymentType;
  final int amount;
  final String label;

  const PaymentScreen({
    super.key,
    required this.announcementId,
    required this.paymentType,
    required this.amount,
    required this.label,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  MobileMoneyOperator _operator = MobileMoneyOperator.airtel;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return 'Numéro invalide';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final service = PaymentService();
      final result = await service.initiatePayment(
        announcementId: widget.announcementId,
        paymentType: widget.paymentType,
        operator: _operator,
        phoneNumber: _phoneController.text.trim().replaceAll(RegExp(r'\D'), ''),
      );
      if (!mounted) return;
      context.pushReplacement('/payments/${result.paymentId}/waiting');
    } on PaymentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySky.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primarySky.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.amount} ${AppConstants.currencySymbol}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Moyen de paiement',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                _OperatorOption(
                  operator: MobileMoneyOperator.airtel,
                  selected: _operator == MobileMoneyOperator.airtel,
                  onTap: () => setState(() => _operator = MobileMoneyOperator.airtel),
                ),
                const SizedBox(height: 8),
                _OperatorOption(
                  operator: MobileMoneyOperator.moov,
                  selected: _operator == MobileMoneyOperator.moov,
                  onTap: () => setState(() => _operator = MobileMoneyOperator.moov),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Numéro Mobile Money',
                    hintText: 'Ex: 077000001',
                    prefixIcon: Icon(Icons.phone, size: 18),
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vous recevrez une demande de confirmation sur votre téléphone. Entrez votre code PIN pour valider.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Payer ${widget.amount} ${AppConstants.currencySymbol}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OperatorOption extends StatelessWidget {
  final MobileMoneyOperator operator;
  final bool selected;
  final VoidCallback onTap;

  const _OperatorOption({
    required this.operator,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primarySky.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primarySky : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              operator == MobileMoneyOperator.airtel
                  ? Icons.phone_android
                  : Icons.smartphone,
              color: selected ? AppTheme.primarySky : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                operator.label,
                style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppTheme.primarySky),
          ],
        ),
      ),
    );
  }
}
