import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_rule.dart';
import '../models/deal.dart';

/// Alert rules, alert history and push settings of the current (anonymous) user.
abstract class UserRepository {
  bool get supportsPush;
  Stream<List<AlertRule>> watchAlerts();
  Future<void> saveAlert(AlertRule rule);
  Future<void> deleteAlert(String id);
  Stream<List<SentAlert>> watchSent();
  Future<void> clearSent();
  Stream<PushSettings> watchSettings();
  Future<void> saveSettings(PushSettings settings);
  Future<void> addFcmToken(String token);
  Future<int> sendTestPush();

  /// 찜한 딜, newest first (snapshots of the deals when saved).
  Stream<List<Deal>> watchFavorites();
  Future<void> setFavorite(Deal deal, bool on);

  /// 추적 상품.
  Stream<List<TrackedProduct>> watchTracked();
  Future<void> saveTracked(TrackedProduct product);
  Future<void> deleteTracked(String key);
}

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  bool get supportsPush => true;

  /// One sign-in shared by every caller: concurrent calls at startup would
  /// otherwise each create their own anonymous user.
  static Future<User>? _signIn;

  Future<User> ensureSignedIn() => _signIn ??= () async {
        // Wait for the persisted session to be restored before deciding to sign in,
        // or a returning user would get a new anonymous account and lose their alerts.
        final restored = _auth.currentUser ?? await _auth.authStateChanges().first;
        return restored ?? (await _auth.signInAnonymously()).user!;
      }()
          .whenComplete(() => _signIn = null);

  Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    final user = await ensureSignedIn();
    return _db.collection('users').doc(user.uid);
  }

  @override
  Stream<List<AlertRule>> watchAlerts() async* {
    final doc = await _userDoc();
    yield* doc
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AlertRule.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> saveAlert(AlertRule rule) async {
    final col = (await _userDoc()).collection('alerts');
    final data = {...rule.toMap(), 'updatedAt': FieldValue.serverTimestamp()};
    if (rule.id == null) {
      await col.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await col.doc(rule.id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> deleteAlert(String id) async => (await _userDoc()).collection('alerts').doc(id).delete();

  @override
  Stream<List<SentAlert>> watchSent() async* {
    final doc = await _userDoc();
    yield* doc
        .collection('sent')
        .orderBy('sentAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => SentAlert.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> clearSent() async {
    final snap = await (await _userDoc()).collection('sent').get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  @override
  Stream<PushSettings> watchSettings() async* {
    final doc = await _userDoc();
    yield* doc.snapshots().map((s) => PushSettings.fromMap(s.data()));
  }

  @override
  Future<void> saveSettings(PushSettings settings) async =>
      (await _userDoc()).set(settings.toMap(), SetOptions(merge: true));

  @override
  Future<void> addFcmToken(String token) async => (await _userDoc()).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Stream<List<Deal>> watchFavorites() async* {
    final doc = await _userDoc();
    yield* doc
        .collection('favorites')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Deal.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> setFavorite(Deal deal, bool on) async {
    final ref = (await _userDoc()).collection('favorites').doc(deal.id);
    if (on) {
      await ref.set({...deal.toFavorite(), 'savedAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  @override
  Stream<List<TrackedProduct>> watchTracked() async* {
    final doc = await _userDoc();
    yield* doc
        .collection('tracked')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => TrackedProduct.fromMap(d.data())).toList());
  }

  @override
  Future<void> saveTracked(TrackedProduct p) async {
    final ref = (await _userDoc()).collection('tracked').doc(p.key);
    final exists = (await ref.get()).exists;
    await ref.set({
      ...p.toMap(),
      exists ? 'updatedAt' : 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteTracked(String key) async => (await _userDoc()).collection('tracked').doc(key).delete();

  @override
  Future<int> sendTestPush() async {
    await _userDoc();
    final res = await FirebaseFunctions.instanceFor(region: 'asia-northeast3').httpsCallable('testPush').call();
    return (res.data['sent'] as num?)?.toInt() ?? 0;
  }
}

/// Debug-only stand-in used with the fixture feed: keeps rules on the device, sends nothing.
class LocalUserRepository implements UserRepository {
  static const _rulesKey = 'local_alert_rules';
  static const _settingsKey = 'local_push_settings';
  final _rules = StreamController<List<AlertRule>>.broadcast();
  final _settings = StreamController<PushSettings>.broadcast();

  @override
  bool get supportsPush => false;

  Future<List<AlertRule>> _readRules() async {
    final raw = (await SharedPreferences.getInstance()).getString(_rulesKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => AlertRule.fromMap(m['id'] as String, Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> _writeRules(List<AlertRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rulesKey, jsonEncode(rules.map((r) => {...r.toMap(), 'id': r.id}).toList()));
    _rules.add(rules);
  }

  @override
  Stream<List<AlertRule>> watchAlerts() async* {
    yield await _readRules();
    yield* _rules.stream;
  }

  @override
  Future<void> saveAlert(AlertRule rule) async {
    final rules = await _readRules();
    if (rule.id == null) {
      rules.insert(0, rule.copyWith(id: DateTime.now().microsecondsSinceEpoch.toString()));
    } else {
      final i = rules.indexWhere((r) => r.id == rule.id);
      if (i >= 0) rules[i] = rule;
    }
    await _writeRules(rules);
  }

  @override
  Future<void> deleteAlert(String id) async => _writeRules((await _readRules()).where((r) => r.id != id).toList());

  @override
  Stream<List<SentAlert>> watchSent() => Stream.value(const []);

  @override
  Future<void> clearSent() async {}

  @override
  Stream<PushSettings> watchSettings() async* {
    final raw = (await SharedPreferences.getInstance()).getString(_settingsKey);
    yield PushSettings.fromMap(raw == null ? null : jsonDecode(raw) as Map<String, dynamic>);
    yield* _settings.stream;
  }

  @override
  Future<void> saveSettings(PushSettings settings) async {
    await (await SharedPreferences.getInstance()).setString(_settingsKey, jsonEncode(settings.toMap()));
    _settings.add(settings);
  }

  @override
  Future<void> addFcmToken(String token) async {}

  @override
  Future<int> sendTestPush() async => 0;

  // Favorites and tracked products stay in memory in the offline fixture mode.
  final List<Deal> _favorites = [];
  final List<TrackedProduct> _tracked = [];
  final _favStream = StreamController<List<Deal>>.broadcast();
  final _trackStream = StreamController<List<TrackedProduct>>.broadcast();

  @override
  Stream<List<Deal>> watchFavorites() async* {
    yield List.of(_favorites);
    yield* _favStream.stream;
  }

  @override
  Future<void> setFavorite(Deal deal, bool on) async {
    _favorites.removeWhere((d) => d.id == deal.id);
    if (on) _favorites.insert(0, deal);
    _favStream.add(List.of(_favorites));
  }

  @override
  Stream<List<TrackedProduct>> watchTracked() async* {
    yield List.of(_tracked);
    yield* _trackStream.stream;
  }

  @override
  Future<void> saveTracked(TrackedProduct p) async {
    _tracked.removeWhere((t) => t.key == p.key);
    _tracked.insert(0, p);
    _trackStream.add(List.of(_tracked));
  }

  @override
  Future<void> deleteTracked(String key) async {
    _tracked.removeWhere((t) => t.key == key);
    _trackStream.add(List.of(_tracked));
  }
}
