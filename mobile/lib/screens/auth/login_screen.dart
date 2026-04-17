import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/config/theme.dart';
import 'package:gp_link/models/country.dart';
import 'package:gp_link/providers/auth_provider.dart';
import 'package:gp_link/providers/country_provider.dart';
import 'package:gp_link/widgets/loading_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Country? _country;
  String? _phoneE164;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _toE164() {
    final c = _country;
    if (c == null || c.dialCode == null) return null;
    final digits = _phoneController.text
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) return null;
    return '${c.dialCode}$digits';
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final e164 = _toE164();
    if (e164 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro invalide')),
      );
      return;
    }
    setState(() => _phoneE164 = e164);
    ref.read(authProvider.notifier).clearError();
    await ref.read(authProvider.notifier).sendOtp(e164);
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state.error == null) {
      setState(() => _otpSent = true);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) return;
    final e164 = _phoneE164;
    if (e164 == null) return;
    ref.read(authProvider.notifier).clearError();
    final success = await ref
        .read(authProvider.notifier)
        .verifyOtp(e164, _otpController.text.trim());
    if (!mounted) return;
    if (success) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.needsProfile) {
        context.go('/register');
      } else {
        context.go('/home');
      }
    }
  }

  Country _guessCountry(List<Country> countries) {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final deviceCountry = deviceLocale.countryCode;
    if (deviceCountry != null) {
      final match = countries.where((c) => c.code == deviceCountry).firstOrNull;
      if (match != null) return match;
    }
    return countries.firstWhere(
      (c) => c.code == 'GA',
      orElse: () => countries.first,
    );
  }

  Widget _buildPhoneRow(List<Country> countries) {
    _country ??= _guessCountry(countries);
    final c = _country!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Pays',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                isExpanded: true,
                value: c.code,
                items: countries
                    .map((item) => DropdownMenuItem(
                          value: item.code,
                          child: Text(item.shortLabel,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final picked =
                      countries.firstWhere((item) => item.code == v);
                  setState(() => _country = picked);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              labelText: 'Numéro',
              hintText: c.phoneExample ?? '',
              prefixIcon: const Icon(Icons.phone, size: 20),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Requis';
              final digits = value
                  .replaceAll(RegExp(r'\D'), '')
                  .replaceFirst(RegExp(r'^0+'), '');
              final min = c.phoneMinDigits ?? 7;
              final max = c.phoneMaxDigits ?? 15;
              if (digits.length < min) {
                return 'Trop court ($min chiffres min)';
              }
              if (digits.length > max) return 'Trop long';
              return null;
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final countriesAsync = ref.watch(countriesProvider);

    return Scaffold(
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        message: _otpSent ? 'Vérification...' : 'Envoi du code...',
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  SvgPicture.asset(
                    'assets/logo/logo_v1_monogram.svg',
                    width: 96,
                    height: 96,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primarySky,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConstants.appTagline,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Text(
                    _otpSent ? 'Entrez le code reçu par SMS' : 'Connexion',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _otpSent
                        ? 'Un code à 6 chiffres a été envoyé au $_phoneE164'
                        : 'Sélectionnez votre pays et entrez votre numéro',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 24),
                  if (!_otpSent) ...[
                    countriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Erreur: $e',
                          style: const TextStyle(color: AppTheme.error)),
                      data: _buildPhoneRow,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _sendOtp,
                      child: const Text('Recevoir le code'),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 12,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Code de vérification',
                        hintText: '------',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      onChanged: (value) {
                        if (value.length == 6) _verifyOtp();
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _verifyOtp,
                      child: const Text('Vérifier'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() => _otpSent = false);
                        _otpController.clear();
                      },
                      child: const Text('Modifier le numéro'),
                    ),
                    TextButton(
                      onPressed: authState.isLoading ? null : _sendOtp,
                      child: const Text('Renvoyer le code'),
                    ),
                  ],
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: const TextStyle(
                                  color: AppTheme.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
