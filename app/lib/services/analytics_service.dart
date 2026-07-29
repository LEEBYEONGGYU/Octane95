import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
    } catch (_) {
      _analytics = null;
    }
  }

  static Future<void> logAppOpen() async {
    try {
      await _analytics?.logAppOpen();
    } catch (_) {}
  }

  static Future<void> log(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (_) {}
  }
}
