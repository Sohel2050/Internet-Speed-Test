import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a store review after a good result, at most once every 90 days
/// and only after the user has run at least 5 tests.
class ReviewPrompt {
  static const _key = 'review_asked_ms';

  static Future<void> maybeAsk({required int testCount}) async {
    if (testCount < 5) return;
    try {
      final p = await SharedPreferences.getInstance();
      final last = p.getInt(_key) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < const Duration(days: 90).inMilliseconds) return;
      final r = InAppReview.instance;
      if (await r.isAvailable()) {
        await p.setInt(_key, now);
        await r.requestReview();
      }
    } catch (_) {}
  }
}
