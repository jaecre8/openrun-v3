import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/deal_repository.dart';
import 'data/user_repository.dart';
import 'models/alert_rule.dart';

enum DataMode { firebase, fixture }

/// Wires the app to Firebase, or in debug builds without Firebase config to the bundled fixture.
class AppServices {
  AppServices._(this.mode, this.deals, this.user);

  static late AppServices instance;

  final DataMode mode;
  final DealRepository deals;
  final UserRepository user;

  /// `--dart-define=USE_FIXTURE=true` forces the offline fixture (debug only).
  static const _forceFixture = bool.fromEnvironment('USE_FIXTURE');

  static Future<AppServices> init() async {
    if (!(_forceFixture && !kReleaseMode)) {
      try {
        // Reads GoogleService-Info.plist / google-services.json added by `flutterfire configure`.
        await Firebase.initializeApp();
        if (FirebaseAuth.instance.currentUser == null) {
          // Feed reading works without auth; alerts retry sign-in when needed.
          FirebaseAuth.instance.signInAnonymously().ignore();
        }
        return instance = AppServices._(DataMode.firebase, FirestoreDealRepository(), FirestoreUserRepository());
      } catch (e) {
        if (kReleaseMode) rethrow;
        debugPrint('Firebase unavailable, using fixture data: $e');
      }
    }
    return instance = AppServices._(DataMode.fixture, FixtureDealRepository(), LocalUserRepository());
  }

  /// v2 kept keywords on the device; turn them into server alert rules once.
  Future<void> migrateLegacyKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('v3_migrated') == true) return;
    final old = prefs.getStringList('my_keywords') ?? const [];
    // ["무료"] was the untouched v2 default, not a user choice; it would match too much.
    final keep = old.length == 1 && old.first == '무료' ? const <String>[] : old;
    try {
      for (final k in keep) {
        await user.saveAlert(AlertRule(keyword: k));
      }
      await prefs.setBool('v3_migrated', true);
    } catch (e) {
      debugPrint('Keyword migration will retry next launch: $e');
    }
  }
}
