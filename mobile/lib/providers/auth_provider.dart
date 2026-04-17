import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/profile.dart';
import 'package:gp_link/services/auth_error_translator.dart';
import 'package:gp_link/services/auth_service.dart';
import 'package:gp_link/services/supabase_service.dart';

// -- Service provider --
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// -- Auth state --
enum AuthStatus { initial, unauthenticated, authenticated, needsProfile }

class AuthState {
  final AuthStatus status;
  final Profile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    Profile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated =>
      status == AuthStatus.unauthenticated ||
      status == AuthStatus.initial;
}

// -- Auth notifier --
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  StreamSubscription<AuthState>? _authSub;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    // Listen to Supabase auth changes
    SupabaseService.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        await _loadProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });

    // Check initial state
    if (SupabaseService.isAuthenticated) {
      await _loadProfile();
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _authService.getProfile();
      if (profile != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: profile,
        );
      } else {
        state = const AuthState(status: AuthStatus.needsProfile);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.needsProfile);
    }
  }

  /// Send OTP.
  Future<void> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.sendOtp(phone);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: AuthErrorTranslator.translateSendOtp(e),
      );
    }
  }

  /// Verify OTP.
  Future<bool> verifyOtp(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.verifyOtp(phone, code);
      await _loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: AuthErrorTranslator.translateVerifyOtp(e),
      );
      return false;
    }
  }

  /// Create profile after first login.
  Future<bool> createProfile({
    required String fullName,
    required UserRole role,
    String? city,
    String? country,
    bool acceptedTerms = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _authService.createProfile(
        fullName: fullName,
        role: role,
        city: city,
        country: country,
        acceptedTerms: acceptedTerms,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de la création du profil.',
      );
      return false;
    }
  }

  /// Update profile.
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _authService.updateProfile(updates);
      state = state.copyWith(
        profile: profile,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de la mise à jour du profil.',
      );
      return false;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience providers
final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(authProvider).profile;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
