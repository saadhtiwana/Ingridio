import 'package:ingridio/models/recipe.dart';
import 'package:ingridio/models/recipe_cooking_step.dart';
import 'package:ingridio/models/recipe_ingredient_line.dart';

/// Converts Recipe (and its nested types) to/from Firestore-friendly maps.
/// Kept as a free function set so the Recipe model stays a pure value object.
class RecipeSerializer {
  RecipeSerializer._();

  static Map<String, dynamic> toMap(Recipe r) {
    return <String, dynamic>{
      'id': r.id,
      'name': r.name,
      'cuisine': r.cuisine,
      'cookTime': r.cookTime,
      'difficulty': r.difficulty,
      'imageUrl': r.imageUrl,
      'cardSubtitle': r.cardSubtitle,
      'showAiBadge': r.showAiBadge,
      'calories': r.calories,
      'tag': r.tag,
      'description': r.description,
      'searchKeywords': r.searchKeywords,
      'ingredients': r.ingredients,
      'steps': r.steps,
      'ingredientLines': r.ingredientLines
          ?.map(_ingredientLineToMap)
          .toList(growable: false),
      'cookingSteps':
          r.cookingSteps?.map(_cookingStepToMap).toList(growable: false),
      'proteinG': r.proteinG,
      'carbsG': r.carbsG,
      'fatsG': r.fatsG,
      'fiberG': r.fiberG,
      'stepTitles': r.stepTitles,
    };
  }

  static Recipe fromMap(Map<String, dynamic> m, {String? fallbackId}) {
    return Recipe(
      id: (m['id'] as String?) ?? fallbackId ?? '',
      name: (m['name'] as String?) ?? 'Recipe',
      cuisine: (m['cuisine'] as String?) ?? 'Suggested',
      cookTime: (m['cookTime'] as String?) ?? '—',
      difficulty: (m['difficulty'] as String?) ?? 'Easy',
      imageUrl: (m['imageUrl'] as String?) ?? '',
      cardSubtitle: m['cardSubtitle'] as String?,
      showAiBadge: (m['showAiBadge'] as bool?) ?? false,
      calories: _asInt(m['calories']),
      tag: m['tag'] as String?,
      description: m['description'] as String?,
      searchKeywords: _asStringList(m['searchKeywords']),
      ingredients: _asStringList(m['ingredients']),
      steps: _asStringList(m['steps']),
      ingredientLines: _readIngredientLines(m['ingredientLines']),
      cookingSteps: _readCookingSteps(m['cookingSteps']),
      proteinG: _asInt(m['proteinG']),
      carbsG: _asInt(m['carbsG']),
      fatsG: _asInt(m['fatsG']),
      fiberG: _asInt(m['fiberG']),
      stepTitles: m['stepTitles'] is List
          ? List<String>.from(
              (m['stepTitles'] as List<dynamic>).whereType<String>(),
            )
          : null,
    );
  }

  static Map<String, dynamic> _ingredientLineToMap(RecipeIngredientLine l) {
    return <String, dynamic>{
      'name': l.name,
      'amountAtTwoServings': l.amountAtTwoServings,
      'unit': l.unit,
      'preparation': l.preparation,
      'imageUrl': l.imageUrl,
    };
  }

  static Map<String, dynamic> _cookingStepToMap(RecipeCookingStep s) {
    return <String, dynamic>{'title': s.title, 'body': s.body};
  }

  static List<RecipeIngredientLine>? _readIngredientLines(Object? raw) {
    if (raw is! List) {
      return null;
    }
    final List<RecipeIngredientLine> out = <RecipeIngredientLine>[];
    for (final Object? el in raw) {
      if (el is! Map) {
        continue;
      }
      final Map<String, dynamic> m = Map<String, dynamic>.from(el);
      out.add(
        RecipeIngredientLine(
          name: (m['name'] as String?) ?? '',
          amountAtTwoServings: _asDouble(m['amountAtTwoServings']) ?? 1,
          unit: (m['unit'] as String?) ?? 'unit',
          preparation: m['preparation'] as String?,
          imageUrl: m['imageUrl'] as String?,
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  static List<RecipeCookingStep>? _readCookingSteps(Object? raw) {
    if (raw is! List) {
      return null;
    }
    final List<RecipeCookingStep> out = <RecipeCookingStep>[];
    for (final Object? el in raw) {
      if (el is! Map) {
        continue;
      }
      final Map<String, dynamic> m = Map<String, dynamic>.from(el);
      out.add(
        RecipeCookingStep(
          title: (m['title'] as String?) ?? 'Step',
          body: (m['body'] as String?) ?? '',
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  static List<String> _asStringList(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw.whereType<String>().toList(growable: false);
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
