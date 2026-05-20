import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SavedRecipesStore extends ChangeNotifier {
  SavedRecipesStore._();

  static final SavedRecipesStore instance = SavedRecipesStore._();

  final Set<String> _ids = <String>{};

  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool isSaved(String recipeId) => _ids.contains(recipeId);

  /// Load this user's saved-recipe IDs from Firestore into the local cache.
  /// Called by AuthGate on sign-in. Safe to call repeatedly.
  Future<void> loadForCurrentUser() async {
    _ids.clear();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      notifyListeners();
      return;
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(uid)
          .collection('savedRecipes')
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        _ids.add(d.id);
      }
    } on Object {
      // Surface the empty set on failure — UI still works, just unpersisted.
    }
    notifyListeners();
  }

  /// Clears the local cache. Called on sign-out.
  void clearLocal() {
    _ids.clear();
    notifyListeners();
  }

  Future<void> toggle(String recipeId) async {
    final bool wasSaved = _ids.contains(recipeId);
    if (wasSaved) {
      _ids.remove(recipeId);
    } else {
      _ids.add(recipeId);
    }
    notifyListeners();

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .collection('savedRecipes')
        .doc(recipeId);
    try {
      if (wasSaved) {
        await ref.delete();
      } else {
        await ref.set(<String, dynamic>{
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    } on Object {
      // Best-effort sync; local state already updated.
    }
  }
}
