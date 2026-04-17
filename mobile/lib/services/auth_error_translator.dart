import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduit les erreurs Supabase Auth en messages utilisateur en français.
class AuthErrorTranslator {
  AuthErrorTranslator._();

  static String translateSendOtp(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'phone_provider_disabled':
          return 'Le service SMS n\'est pas disponible. Contactez le support.';
        case 'over_sms_send_rate_limit':
          return 'Trop de demandes. Patientez quelques minutes avant de réessayer.';
        case 'invalid_phone':
          return 'Le numéro de téléphone n\'est pas valide.';
        case 'signup_disabled':
          return 'Les inscriptions sont temporairement fermées.';
        case 'phone_exists':
          return 'Ce numéro est déjà utilisé avec un autre compte.';
        case 'sms_send_failed':
          return 'L\'envoi du SMS a échoué. Vérifiez votre numéro.';
        case 'rate_limit_exceeded':
          return 'Trop de tentatives. Réessayez dans quelques minutes.';
        case 'weak_password':
        case 'email_address_not_authorized':
          return error.message;
      }
      // Status code fallback
      if (error.statusCode == '429') {
        return 'Trop de demandes. Patientez avant de réessayer.';
      }
      if (error.statusCode == '400') {
        return 'Numéro de téléphone invalide.';
      }
      if (error.statusCode == '500' || error.statusCode == '502') {
        return 'Le serveur est momentanément indisponible. Réessayez.';
      }
      return 'Erreur : ${error.message}';
    }
    return _translateNetwork(error, 'Impossible d\'envoyer le code.');
  }

  static String translateVerifyOtp(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'otp_expired':
          return 'Code expiré. Demandez un nouveau code.';
        case 'otp_disabled':
          return 'La vérification par SMS est désactivée.';
        case 'invalid_credentials':
          return 'Code incorrect.';
        case 'over_request_rate_limit':
          return 'Trop de tentatives. Patientez avant de réessayer.';
      }
      if (error.statusCode == '403') {
        return 'Code incorrect ou expiré.';
      }
      if (error.statusCode == '400') {
        return 'Code invalide.';
      }
      if (error.statusCode == '500') {
        return 'Erreur serveur. Réessayez.';
      }
      return 'Erreur : ${error.message}';
    }
    return _translateNetwork(error, 'Impossible de vérifier le code.');
  }

  static String _translateNetwork(Object error, String fallback) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable')) {
      return 'Pas de connexion internet. Vérifiez votre réseau.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Délai dépassé. Vérifiez votre connexion.';
    }
    if (msg.contains('handshake') || msg.contains('certificate')) {
      return 'Erreur de sécurité réseau.';
    }
    return fallback;
  }
}
