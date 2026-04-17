import 'package:shared_preferences/shared_preferences.dart';

/// Gère l'état "tutoriel déjà vu ou non" localement (SharedPreferences).
class TutorialService {
  static const _kHomeKey = 'tutorial_home_completed_v1';

  Future<bool> isHomeCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHomeKey) ?? false;
  }

  Future<void> markHomeCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHomeKey, true);
  }

  /// Réinitialise le tutoriel pour permettre de le revoir.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHomeKey);
  }
}
