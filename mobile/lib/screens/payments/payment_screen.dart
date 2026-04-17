import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/services/payment_service.dart';

enum _PaymentChoice { airtel, moov, store }

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
  _PaymentChoice _choice = _PaymentChoice.airtel;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isGabon {
    final profile = ref.read(authProvider).profile;
    return profile?.country == 'Gabon';
  }

  bool get _isMobileMoney =>
      _choice == _PaymentChoice.airtel || _choice == _PaymentChoice.moov;

  String? _validatePhone(String? v) {
    if (!_isMobileMoney) return null;
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return 'Numéro invalide';
    return null;
  }

  Future<void> _submit() async {
    if (_choice == _PaymentChoice.store) {
      _showStoreDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final operator = _choice == _PaymentChoice.airtel
          ? MobileMoneyOperator.airtel
          : MobileMoneyOperator.moov;

      final service = PaymentService();
      final result = await service.initiatePayment(
        announcementId: widget.announcementId,
        paymentType: widget.paymentType,
        operator: operator,
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

  void _showStoreDialog() {
    final storeName = Platform.isIOS ? 'Apple Pay' : 'Google Play';
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Paiement $storeName'),
        content: const Text(
          'Le paiement via le store natif sera bientôt disponible. En attendant, contactez-nous pour effectuer votre paiement manuellement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGabon = _isGabon;

    // Si l'user n'est pas au Gabon, on pré-sélectionne le store
    if (!isGabon && _isMobileMoney) {
      _choice = _PaymentChoice.store;
    }

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
                    border:
                        Border.all(color: AppTheme.primarySky.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(widget.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),

                if (isGabon) ...[
                  _ChoiceOption(
                    icon: Icons.phone_android,
                    label: 'Airtel Money',
                    selected: _choice == _PaymentChoice.airtel,
                    onTap: () =>
                        setState(() => _choice = _PaymentChoice.airtel),
                  ),
                  const SizedBox(height: 8),
                  _ChoiceOption(
                    icon: Icons.smartphone,
                    label: 'Moov Money',
                    selected: _choice == _PaymentChoice.moov,
                    onTap: () =>
                        setState(() => _choice = _PaymentChoice.moov),
                  ),
                  const SizedBox(height: 8),
                ],

                _ChoiceOption(
                  icon: Platform.isIOS ? Icons.apple : Icons.shop,
                  label: Platform.isIOS
                      ? 'Apple Pay (App Store)'
                      : 'Google Play',
                  selected: _choice == _PaymentChoice.store,
                  onTap: () => setState(() => _choice = _PaymentChoice.store),
                ),

                if (!isGabon) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Le Mobile Money est disponible uniquement au Gabon. Vous pouvez payer via le store de votre téléphone.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                if (_isMobileMoney) ...[
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.blue),
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
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 8),
                ],

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Payer ${widget.amount} ${AppConstants.currencySymbol}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceOption({
    required this.icon,
    required this.label,
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
            Icon(icon, color: selected ? AppTheme.primarySky : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.primarySky),
          ],
        ),
      ),
    );
  }
}
