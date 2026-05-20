import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ingridio/data/mock_data.dart';
import 'package:ingridio/models/ingredient.dart';

class PantryManager extends ChangeNotifier {
  PantryManager._();

  static final PantryManager instance = PantryManager._();

  final List<Ingredient> _items = <Ingredient>[];

  List<Ingredient> get items => List<Ingredient>.unmodifiable(_items);

  int get totalCount => _items.length;

  /// Loads this user's pantry from Firestore into the local cache.
  /// Seeds with [MockData.mockPantry] on the user's very first sign-in so the
  /// demo has something to look at.
  Future<void> loadForCurrentUser() async {
    _items.clear();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      notifyListeners();
      return;
    }
    final CollectionReference<Map<String, dynamic>> col = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .collection('pantry');
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await col.get();
      if (snap.docs.isEmpty) {
        await _seedDefaults(col);
        _items.addAll(MockData.mockPantry);
      } else {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
          _items.add(_fromDoc(d));
        }
      }
    } on Object {
      // Fallback to mock pantry so the UI isn't empty.
      _items.addAll(MockData.mockPantry);
    }
    notifyListeners();
  }

  void clearLocal() {
    _items.clear();
    notifyListeners();
  }

  Future<void> add(Ingredient ingredient) async {
    _items.add(ingredient);
    notifyListeners();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .doc(ingredient.id)
          .set(_toMap(ingredient));
    } on Object {
      // Local cache already updated; ignore sync failure.
    }
  }

  Future<void> removeById(String id) async {
    _items.removeWhere((Ingredient e) => e.id == id);
    notifyListeners();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .doc(id)
          .delete();
    } on Object {
      // Best-effort.
    }
  }

  static String newId() => 'ing_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _seedDefaults(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    for (final Ingredient i in MockData.mockPantry) {
      batch.set(col.doc(i.id), _toMap(i));
    }
    await batch.commit();
  }

  static Map<String, dynamic> _toMap(Ingredient i) {
    return <String, dynamic>{
      'name': i.name,
      'category': i.category,
      'quantity': i.quantity,
      'unit': i.unit,
      'daysLeft': i.daysLeft,
      'stockLevel': i.stockLevel,
      'source': i.source.name,
    };
  }

  static Ingredient _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final Map<String, dynamic> data = d.data();
    return Ingredient(
      id: d.id,
      name: (data['name'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Other',
      quantity: data['quantity'] is int ? data['quantity'] as int : null,
      unit: data['unit'] as String?,
      daysLeft: data['daysLeft'] is int ? data['daysLeft'] as int : null,
      stockLevel: data['stockLevel'] as String?,
      source: _parseSource(data['source'] as String?),
    );
  }

  static IngredientSource _parseSource(String? raw) {
    switch (raw) {
      case 'camera':
        return IngredientSource.camera;
      case 'manual':
      default:
        return IngredientSource.manual;
    }
  }
}
