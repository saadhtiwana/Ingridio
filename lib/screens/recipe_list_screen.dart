import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ingridio/models/recipe.dart';
import 'package:ingridio/screens/recipe_detail_screen.dart';

/// Reusable list screen for any set of recipe IDs (Saved, Cooked, etc.).
///
/// Listens to the provided `listenable` (typically the store) so the list
/// rebuilds live when items are added/removed elsewhere in the app.
class RecipeListScreen extends StatelessWidget {
  const RecipeListScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyBody,
    required this.emptyIcon,
    required this.listenable,
    required this.recipesProvider,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyBody;
  final IconData emptyIcon;

  /// The store to listen to for changes.
  final Listenable listenable;

  /// Returns the recipes to display. Called inside ListenableBuilder so the
  /// list rebuilds whenever the store notifies.
  final List<Recipe> Function() recipesProvider;

  static const Color _primary = Color(0xFF9D4300);
  static const Color _primaryContainer = Color(0xFFF97316);
  static const Color _background = Color(0xFFFFF8F5);
  static const Color _onSurface = Color(0xFF2F1400);
  static const Color _onSurfaceVariant = Color(0xFF584237);
  static const Color _surfaceContainerLow = Color(0xFFFFF1E9);
  static const Color _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _outlineVariant = Color(0xFFE0C0B1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        foregroundColor: _onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: _onSurface,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: listenable,
        builder: (BuildContext context, Widget? child) {
          final List<Recipe> recipes = recipesProvider();

          if (recipes.isEmpty) {
            return _EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              body: emptyBody,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  recipes.length == 1
                      ? '1 recipe'
                      : '${recipes.length} recipes',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: recipes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    return _RecipeRow(
                      recipe: recipes[index],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RecipeDetailScreen(recipe: recipes[index]),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RecipeListScreen._surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: RecipeListScreen._outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Image.network(
                    recipe.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: RecipeListScreen._surfaceContainerLow,
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: RecipeListScreen._primaryContainer,
                      ),
                    ),
                    loadingBuilder: (BuildContext ctx, Widget child,
                        ImageChunkEvent? p) {
                      if (p == null) {
                        return child;
                      }
                      return Container(
                        color: RecipeListScreen._surfaceContainerLow,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: RecipeListScreen._onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: RecipeListScreen._onSurfaceVariant
                              .withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.cookTime,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: RecipeListScreen._onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '•',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: RecipeListScreen._onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            recipe.cuisine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: RecipeListScreen._onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: RecipeListScreen._onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: RecipeListScreen._surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: RecipeListScreen._primaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: RecipeListScreen._onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: RecipeListScreen._onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
