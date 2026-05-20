import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ingridio/logic/recipe_serializer.dart';
import 'package:ingridio/models/recipe.dart';

/// Per-user history of recipes the user has cooked.
///
/// Stores the FULL Recipe object in Firestore so Gemini-generated recipes
/// can be displayed in the Cooked list after the user finishes one.
class CookedRecipesStore extends ChangeNotifier {
  CookedRecipesStore._();

  static final CookedRecipesStore instance = CookedRecipesStore._();

  final Map<String, Recipe> _recipes = <String, Recipe>{};

  Set<String> get ids => _recipes.keys.toSet();
  List<Recipe> get recipes => List<Recipe>.unmodifiable(_recipes.values);

  int get count => _recipes.length;

  bool contains(String recipeId) => _recipes.containsKey(recipeId);

  Future<void> loadForCurrentUser() async {
    _recipes.clear();
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
          .collection('cookedRecipes')
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        final Map<String, dynamic> data = d.data();
        final Map<String, dynamic>? recipeMap =
            data['recipe'] is Map ? Map<String, dynamic>.from(data['recipe'] as Map) : null;
        if (recipeMap != null) {
          final Recipe r = RecipeSerializer.fromMap(recipeMap, fallbackId: d.id);
          _recipes[d.id] = r;
        }
      }
    } on Object {
      // Empty list on failure.
    }
    notifyListeners();
  }

  void clearLocal() {
    _recipes.clear();
    notifyListeners();
  }

  Future<void> add(Recipe recipe) async {
    final bool wasNew = !_recipes.containsKey(recipe.id);
    _recipes[recipe.id] = recipe;
    notifyListeners();
    if (!wasNew) {
      return;
    }
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cookedRecipes')
          .doc(recipe.id)
          .set(<String, dynamic>{
        'cookedAt': FieldValue.serverTimestamp(),
        'recipe': RecipeSerializer.toMap(recipe),
      });
    } on Object {
      // Best-effort.
    }
  }
}
