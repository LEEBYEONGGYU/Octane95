import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewPromptPolicy {
  static const int minimumRecordCount = 3;
  static const int minimumLaunchCount = 5;
  static const Duration minimumInstallAge = Duration(days: 7);
  static const Duration regularCooldown = Duration(days: 30);
  static const Duration additionalRecordCooldown = Duration(days: 14);
  static const int additionalRecordsForRetry = 3;

  static bool isEligible({
    required DateTime now,
    required int recordCount,
    required int launchCount,
    required DateTime firstLaunchAt,
    required bool reviewCompleted,
    DateTime? lastPromptAt,
    int lastPromptRecordCount = 0,
  }) {
    if (reviewCompleted ||
        recordCount < minimumRecordCount ||
        launchCount < minimumLaunchCount ||
        now.difference(firstLaunchAt) < minimumInstallAge) {
      return false;
    }

    if (lastPromptAt == null) return true;

    final sinceLastPrompt = now.difference(lastPromptAt);
    if (sinceLastPrompt >= regularCooldown) return true;

    return sinceLastPrompt >= additionalRecordCooldown &&
        recordCount >= lastPromptRecordCount + additionalRecordsForRetry;
  }
}

class ReviewPromptService {
  static const _firstLaunchAtKey = 'review_first_launch_at';
  static const _launchCountKey = 'review_launch_count';
  static const _completedKey = 'review_completed';
  static const _lastPromptAtKey = 'review_last_prompt_at';
  static const _lastPromptRecordCountKey = 'review_last_prompt_record_count';

  static Future<void> registerLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    if (!prefs.containsKey(_firstLaunchAtKey)) {
      await prefs.setString(_firstLaunchAtKey, now.toIso8601String());
    }
    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    await prefs.setInt(_launchCountKey, launchCount + 1);
  }

  static Future<bool> isEligible({required int recordCount}) async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunchAt = DateTime.tryParse(
      prefs.getString(_firstLaunchAtKey) ?? '',
    );
    if (firstLaunchAt == null) return false;

    final lastPromptAt = DateTime.tryParse(
      prefs.getString(_lastPromptAtKey) ?? '',
    );

    return ReviewPromptPolicy.isEligible(
      now: DateTime.now(),
      recordCount: recordCount,
      launchCount: prefs.getInt(_launchCountKey) ?? 0,
      firstLaunchAt: firstLaunchAt,
      reviewCompleted: prefs.getBool(_completedKey) ?? false,
      lastPromptAt: lastPromptAt,
      lastPromptRecordCount: prefs.getInt(_lastPromptRecordCountKey) ?? 0,
    );
  }

  static Future<void> markShown({required int recordCount}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptAtKey, DateTime.now().toIso8601String());
    await prefs.setInt(_lastPromptRecordCountKey, recordCount);
  }

  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }

  static Future<void> requestReview() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  }
}
