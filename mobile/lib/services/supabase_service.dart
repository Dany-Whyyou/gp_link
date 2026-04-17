import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gp_link/config/constants.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }

  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
  static RealtimeClient get realtime => client.realtime;

  static String? get currentUserId => auth.currentUser?.id;
  static User? get currentUser => auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static SupabaseQueryBuilder from(String table) => client.from(table);

  static StorageFileApi bucket(String name) => storage.from(name);

  /// Upload a file to a storage bucket and return the public URL.
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes as dynamic,
          fileOptions: FileOptions(
            contentType: contentType ?? 'image/jpeg',
            upsert: true,
          ),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }
}
