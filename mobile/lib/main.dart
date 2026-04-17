import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:gp_link/app.dart';
import 'package:gp_link/config/constants.dart';
import 'package:gp_link/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialize Supabase
  await SupabaseService.initialize();

  // Configure timeago for French
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setDefaultLocale('fr');

  // Initialize OneSignal (uncomment when ready)
  // OneSignal.initialize(AppConstants.oneSignalAppId);
  // OneSignal.Notifications.requestPermission(true);

  runApp(
    const ProviderScope(
      child: GPLinkApp(),
    ),
  );
}
