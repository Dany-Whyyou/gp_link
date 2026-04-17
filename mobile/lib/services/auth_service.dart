import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/models/profile.dart';
import 'package:gp_link/services/supabase_service.dart';

class AuthService {
  final _auth = SupabaseService.auth;

  /// Send OTP. Phone must already be in E.164 format (e.g., "+24177730634").
  Future<void> sendOtp(String phoneE164) async {
    await _auth.signInWithOtp(phone: phoneE164);
  }

  /// Verify the OTP code. Phone must be E.164.
  Future<AuthResponse> verifyOtp(String phoneE164, String code) async {
    return await _auth.verifyOTP(
      phone: phoneE164,
      token: code,
      type: OtpType.sms,
    );
  }

  /// Create or update the user profile after first login.
  Future<Profile> createProfile({
    required String fullName,
    required UserRole role,
    String? city,
    String? country,
  }) async {
    final userId = SupabaseService.currentUserId!;
    final phone = _auth.currentUser?.phone;
    final now = DateTime.now().toIso8601String();

    final data = {
      'id': userId,
      'full_name': fullName,
      'role': role.name,
      'phone': phone,
      'city': city,
      'country': country ?? 'Gabon',
      'created_at': now,
      'updated_at': now,
    };

    final result = await SupabaseService.from(AppConstants.profilesTable)
        .upsert(data)
        .select()
        .single();

    return Profile.fromJson(result);
  }

  /// Get the current user's profile.
  Future<Profile?> getProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final result = await SupabaseService.from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (result == null) return null;
      return Profile.fromJson(result);
    } catch (e) {
      return null;
    }
  }

  /// Update profile fields.
  Future<Profile> updateProfile(Map<String, dynamic> updates) async {
    final userId = SupabaseService.currentUserId!;
    updates['updated_at'] = DateTime.now().toIso8601String();

    final result = await SupabaseService.from(AppConstants.profilesTable)
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return Profile.fromJson(result);
  }

  /// Get a profile by user ID (public view).
  Future<Profile?> getProfileById(String userId) async {
    try {
      final result = await SupabaseService.from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (result == null) return null;
      return Profile.fromJson(result);
    } catch (e) {
      return null;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Listen to auth state changes.
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Check if a profile exists for the current user.
  Future<bool> hasProfile() async {
    final profile = await getProfile();
    return profile != null;
  }
}
