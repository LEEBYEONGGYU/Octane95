import 'package:flutter_test/flutter_test.dart';
import 'package:octane95/services/review_prompt_service.dart';
import 'package:octane95/utils/display_format.dart';

void main() {
  group('ReviewPromptPolicy', () {
    final now = DateTime(2026, 7, 30);
    final firstLaunchAt = DateTime(2026, 7, 1);

    test('requires records, launches, and install age', () {
      expect(
        ReviewPromptPolicy.isEligible(
          now: now,
          recordCount: 3,
          launchCount: 5,
          firstLaunchAt: firstLaunchAt,
          reviewCompleted: false,
        ),
        isTrue,
      );
      expect(
        ReviewPromptPolicy.isEligible(
          now: now,
          recordCount: 2,
          launchCount: 5,
          firstLaunchAt: firstLaunchAt,
          reviewCompleted: false,
        ),
        isFalse,
      );
    });

    test('allows a later retry without prompting too frequently', () {
      expect(
        ReviewPromptPolicy.isEligible(
          now: now,
          recordCount: 6,
          launchCount: 8,
          firstLaunchAt: firstLaunchAt,
          reviewCompleted: false,
          lastPromptAt: now.subtract(const Duration(days: 15)),
          lastPromptRecordCount: 3,
        ),
        isTrue,
      );
      expect(
        ReviewPromptPolicy.isEligible(
          now: now,
          recordCount: 6,
          launchCount: 8,
          firstLaunchAt: firstLaunchAt,
          reviewCompleted: false,
          lastPromptAt: now.subtract(const Duration(days: 5)),
          lastPromptRecordCount: 3,
        ),
        isFalse,
      );
    });

    test('never prompts after review completion', () {
      expect(
        ReviewPromptPolicy.isEligible(
          now: now,
          recordCount: 20,
          launchCount: 20,
          firstLaunchAt: firstLaunchAt,
          reviewCompleted: true,
        ),
        isFalse,
      );
    });
  });

  group('DisplayFormat', () {
    test('formats octane, liters, and won consistently', () {
      expect(DisplayFormat.ron(94.75), '94.8 RON');
      expect(DisplayFormat.ron(94.75, detail: true), '94.75 RON');
      expect(DisplayFormat.liter(50), '50.0 L');
      expect(DisplayFormat.won(94000), '94,000원');
      expect(DisplayFormat.unitPrice(2000), '2,000원/L');
    });
  });
}
