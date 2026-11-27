import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_rule.dart';

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
}
