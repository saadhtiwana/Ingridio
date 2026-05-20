import 'package:flutter_test/flutter_test.dart';
import 'package:ingridio/data/mock_data.dart';
import 'package:ingridio/logic/recipe_matcher.dart';
import 'package:ingridio/logic/step_timer_parse.dart';
import 'package:ingridio/models/recipe_match_result.dart';

void main() {
  group('RecipeMatcher', () {
    test('returns 0 match for empty pantry', () {
      final List<RecipeMatchResult> results =
          RecipeMatcher.match(const <String>[], MockData.mockRecipes);
      // Recipes with no ingredient data are filtered out; the rest score 0.
      for (final RecipeMatchResult r in results) {
        expect(r.matchPercent, 0);
      }
    });

    test('matches recipes by substring-tolerant ingredient names', () {
      final List<RecipeMatchResult> results = RecipeMatcher.match(
        const <String>['Quinoa', 'Avocado', 'Spinach', 'Tomatoes'],
        MockData.mockRecipes,
      );
      expect(results, isNotEmpty);
      // Top match should be the Harvest Quinoa Bowl (id '9').
      expect(results.first.recipe.id, '9');
      expect(results.first.matchPercent, greaterThan(0));
    });

    test('results are sorted descending by match percent', () {
      final List<RecipeMatchResult> results = RecipeMatcher.match(
        const <String>['Spinach', 'Tomatoes'],
        MockData.mockRecipes,
      );
      for (int i = 1; i < results.length; i++) {
        expect(
          results[i - 1].matchPercent >= results[i].matchPercent,
          isTrue,
        );
      }
    });
  });

  group('step_timer_parse', () {
    test('parses minutes', () {
      expect(parseDurationFromStepText('Simmer for 20 minutes'),
          const Duration(minutes: 20));
      expect(parseDurationFromStepText('Boil 5 mins'),
          const Duration(minutes: 5));
    });

    test('parses hours and seconds', () {
      expect(parseDurationFromStepText('Bake for 1 hour'),
          const Duration(hours: 1));
      expect(parseDurationFromStepText('Wait 30 seconds'),
          const Duration(seconds: 30));
    });

    test('returns null when no duration mentioned', () {
      expect(parseDurationFromStepText('Stir gently'), isNull);
    });

    test('stepTextSuggestsTimer detects timer keywords', () {
      expect(stepTextSuggestsTimer('Simmer 20 minutes'), isTrue);
      expect(stepTextSuggestsTimer('Stir gently'), isFalse);
    });
  });
}
