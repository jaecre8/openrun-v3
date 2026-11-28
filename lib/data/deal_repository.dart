import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/deal.dart';
import '../models/product.dart';

class DealPage {
  final List<Deal> deals;
  final Object? cursor;
  final bool hasMore;
  const DealPage(this.deals, this.cursor, this.hasMore);
}

abstract class DealRepository {
  /// Newest first. Pass the previous page's [cursor] to continue.
  Future<DealPage> fetch({DealCategory? category, Object? cursor, int limit = 40});

  /// Deals with a 역대 최저가 / 평소보다 저렴 badge, newest first.
  Future<DealPage> fetchBargains({Object? cursor, int limit = 40});

  /// Price history of one product, or null if none was recorded.
  Future<ProductHistory?> product(String key);
}

class FirestoreDealRepository implements DealRepository {
  final FirebaseFirestore _db;
  FirestoreDealRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<DealPage> fetch({DealCategory? category, Object? cursor, int limit = 40}) async {
    Query<Map<String, dynamic>> q = _db.collection('deals');
    if (category != null) q = q.where('category', isEqualTo: category.name);
    q = q.orderBy('postedAt', descending: true).limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    final deals = snap.docs.map((d) => Deal.fromMap(d.id, d.data())).toList();
    return DealPage(deals, snap.docs.isEmpty ? cursor : snap.docs.last, snap.docs.length == limit);
  }

  @override
  Future<DealPage> fetchBargains({Object? cursor, int limit = 40}) async {
    Query<Map<String, dynamic>> q = _db
        .collection('deals')
        .where('insightKind', whereIn: ['lowest', 'below_avg'])
        .orderBy('postedAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    final deals = snap.docs.map((d) => Deal.fromMap(d.id, d.data())).toList();
    return DealPage(deals, snap.docs.isEmpty ? cursor : snap.docs.last, snap.docs.length == limit);
  }

  @override
  Future<ProductHistory?> product(String key) async {
    final doc = await _db.collection('products').doc(key).get();
    return doc.exists ? ProductHistory.fromMap(key, doc.data()!) : null;
  }
}

/// Debug-only: serves a snapshot written by `functions/scripts/make_fixture.ts`,
/// so the UI can run before Firebase is configured.
class FixtureDealRepository implements DealRepository {
  List<Deal>? _all;

  Future<List<Deal>> _load() async {
    if (_all != null) return _all!;
    final raw = jsonDecode(await rootBundle.loadString('assets/fixtures/deals.json')) as List;
    _all = raw.map((m) => Deal.fromMap(m['id'] as String, Map<String, dynamic>.from(m as Map))).toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return _all!;
  }

  @override
  Future<DealPage> fetch({DealCategory? category, Object? cursor, int limit = 40}) async {
    final all = (await _load()).where((d) => category == null || d.category == category).toList();
    final start = cursor is int ? cursor : 0;
    final end = (start + limit).clamp(0, all.length);
    return DealPage(all.sublist(start, end), end, end < all.length);
  }

  @override
  Future<DealPage> fetchBargains({Object? cursor, int limit = 40}) async {
    final all = (await _load()).where((d) => d.insightKind != null).toList();
    final start = cursor is int ? cursor : 0;
    final end = (start + limit).clamp(0, all.length);
    return DealPage(all.sublist(start, end), end, end < all.length);
  }

  @override
  Future<ProductHistory?> product(String key) async => null;
}
