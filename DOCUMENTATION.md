# Ingridio — Technical Documentation

> A complete, end-to-end reference for the Ingridio Flutter application.
> Read top-to-bottom on first visit. Use the table of contents to jump.

---

## Table of contents

1. [What Ingridio does](#1-what-ingridio-does)
2. [Tech stack at a glance](#2-tech-stack-at-a-glance)
3. [High-level architecture](#3-high-level-architecture)
4. [Repository layout](#4-repository-layout)
5. [Application bootstrap & navigation flow](#5-application-bootstrap--navigation-flow)
6. [Firebase integration deep-dive](#6-firebase-integration-deep-dive)
7. [Authentication & JWT](#7-authentication--jwt)
8. [Cloud Firestore data model](#8-cloud-firestore-data-model)
9. [State stores (in-memory caches)](#9-state-stores-in-memory-caches)
10. [Domain models](#10-domain-models)
11. [Gemini AI vision pipeline](#11-gemini-ai-vision-pipeline)
12. [Recipe matching algorithm](#12-recipe-matching-algorithm)
13. [Screen-by-screen reference](#13-screen-by-screen-reference)
14. [Design system](#14-design-system)
15. [Build & run on Android](#15-build--run-on-android)
16. [Build & run on Web (Cloud Run)](#16-build--run-on-web-cloud-run)
17. [Environment variables & secrets](#17-environment-variables--secrets)
18. [Testing](#18-testing)
19. [Demo script for the lab evaluation](#19-demo-script-for-the-lab-evaluation)
20. [Known limitations & future work](#20-known-limitations--future-work)
21. [Troubleshooting](#21-troubleshooting)
22. [Contributors & license](#22-contributors--license)

---

## 1. What Ingridio does

Ingridio is a mobile-first recipe assistant that converts a photo of your fridge, pantry, or countertop into a curated list of recipes you can actually cook with what you already own. The product loop is:

1. **Scan** — user opens the in-app camera (or picks from gallery) and captures food ingredients.
2. **Detect** — the image is sent to Google's Gemini 2.0 Flash vision model, which returns the list of detected ingredients plus suggested recipes as structured JSON.
3. **Match** — the detected ingredients are scored against a curated recipe catalogue using a substring-tolerant matcher; results are ranked by ingredient-match percentage.
4. **Choose** — the user picks a recipe, sees a detail page with scaled ingredient quantities, macros, and step-by-step cooking instructions.
5. **Cook** — guided cooking mode walks the user through each step, with auto-detected inline timers, AI tips, and final star-rating capture.
6. **Persist** — saved recipes, pantry items, cooked-history, ratings, and personal preferences are stored per-user in Cloud Firestore behind Firebase Authentication.

The app is designed for fast, low-friction cooking decisions, especially for users juggling Pakistani / South-Asian cuisine, Mediterranean, Italian, and "healthy bowl" style dishes.

---

## 2. Tech stack at a glance

| Layer | Technology | Version pin (key) |
| --- | --- | --- |
| Mobile framework | **Flutter** | SDK ^3.11.0 |
| Language | **Dart** | 3.x |
| State management | `ChangeNotifier` + `ListenableBuilder` (no external library) | — |
| AI vision | **Google Gemini 2.0 Flash** via `google_generative_ai` | ^0.4.7 |
| Authentication | **Firebase Authentication** (Email/Password, JWT ID tokens) | ^5.3.1 |
| Database | **Cloud Firestore** (NoSQL, real-time) | ^5.4.4 |
| Firebase init | `firebase_core` | ^3.6.0 |
| Camera | `camera` plugin | ^0.11.0 |
| Image picking | `image_picker` | ^1.2.2 |
| Permissions | `permission_handler` | ^11.4.0 |
| HTTP | `http` | ^1.2.2 |
| Asset caching | `flutter_cache_manager` | ^3.3.1 |
| Env loading | `flutter_dotenv` | ^6.0.1 |
| Fonts | `google_fonts` (Plus Jakarta Sans + Be Vietnam Pro) | ^8.0.2 |
| Web hosting | **Google Cloud Run** (Nginx Alpine container) | — |
| CI/build | **Google Cloud Build** | — |
| Containerisation | **Docker** (multi-stage Flutter→Nginx) | — |

There are **no backend servers written for this project**. Firebase handles persistence and auth; Gemini handles vision; the Flutter app is the only piece of code we ship.

---

## 3. High-level architecture

```
                    ┌──────────────────────────┐
                    │       Flutter app         │
                    │  (Android / Web target)   │
                    └────────┬─────────┬────────┘
                             │         │
              ┌──────────────┘         └──────────────┐
              │                                       │
              ▼                                       ▼
   ┌──────────────────┐                  ┌────────────────────────┐
   │  Camera/Gallery  │                  │   Firebase services    │
   │  → image bytes   │                  │ ─────────────────────  │
   └────────┬─────────┘                  │  Auth (email/password) │
            │                            │  Firestore (per-user)  │
            ▼                            └────────────┬───────────┘
   ┌──────────────────┐                               │
   │  GeminiService   │                               │
   │ google_generative│  ──── JSON ────► RecipeMatcher│
   │      _ai         │                  + UI         │
   └──────────────────┘                               │
                                                      │
                                                      ▼
                                          ┌────────────────────────┐
                                          │   In-app state stores  │
                                          │  (ChangeNotifier sing.)│
                                          │  - PantryManager       │
                                          │  - SavedRecipesStore   │
                                          │  - CookedRecipesStore  │
                                          │  - RecipeRatingStore   │
                                          │  - UserPreferencesStore│
                                          └────────────────────────┘
```

### Data lifecycle
- On sign-in, `AuthGate` calls `loadForCurrentUser()` on each store in parallel.
- Stores keep an **in-memory mirror** of the Firestore data, so UI reads are sync.
- Mutations (`add`, `removeById`, `toggle`, `save`, etc.) update the local cache **synchronously**, call `notifyListeners()`, and then write to Firestore asynchronously. The UI never blocks on the network.
- On sign-out, every store's `clearLocal()` is called and the user is routed back through `AuthGate`.

---

## 4. Repository layout

```
Ingridio/
├── android/                      Android-specific Gradle build, app config
│   ├── app/
│   │   ├── google-services.json   # Firebase Android config (project-linked)
│   │   ├── build.gradle.kts       # App-level Gradle (Kotlin DSL)
│   │   └── src/main/AndroidManifest.xml
│   ├── build.gradle.kts           # Root Gradle file
│   └── settings.gradle.kts        # Declares Google Services plugin
├── ios/                          (iOS scaffold — not actively built)
├── web/                          (Web shell for Flutter web target)
├── assets/
│   ├── .env                       # GEMINI_API_KEY (gitignored)
│   └── images/                    # Onboarding hero photos, profile placeholder
├── lib/
│   ├── main.dart                  # Entry point — Firebase.initializeApp + MaterialApp
│   ├── data/
│   │   └── mock_data.dart         # MockData: pantry seed + curated recipe catalogue
│   ├── logic/
│   │   ├── cooked_recipes_store.dart
│   │   ├── design_system.dart     # DesignSystem constants + AppleCard/AppleButton widgets
│   │   ├── image_cache_manager.dart
│   │   ├── pantry_manager.dart    # Firestore-backed pantry
│   │   ├── recipe_matcher.dart    # % match algorithm
│   │   ├── recipe_rating_store.dart
│   │   ├── route_transitions.dart
│   │   ├── saved_recipes_store.dart # Firestore-backed saves
│   │   ├── step_timer_parse.dart  # Regex parser for "5 mins" in steps
│   │   └── user_preferences_store.dart # Firestore-backed user prefs
│   ├── models/
│   │   ├── food_vision_result.dart
│   │   ├── ingredient.dart
│   │   ├── recipe.dart
│   │   ├── recipe_cooking_step.dart
│   │   ├── recipe_ingredient_line.dart
│   │   ├── recipe_match_result.dart
│   │   ├── scanned_ingredient.dart
│   │   └── user_preferences.dart
│   ├── screens/
│   │   ├── auth_gate.dart         # Routes by auth state, bootstraps user data
│   │   ├── cooking_mode_screen.dart
│   │   ├── discovery_screen.dart
│   │   ├── home_screen.dart       # 5-tab shell + scan FAB
│   │   ├── login_screen.dart      # Firebase email/password sign-in
│   │   ├── onboarding_screen.dart # 4-page PageView intro
│   │   ├── pantry_screen.dart
│   │   ├── personalize_screen.dart
│   │   ├── profile_screen.dart    # User profile + JWT viewer + logout
│   │   ├── recipe_detail_screen.dart
│   │   ├── recipe_match_screen.dart
│   │   ├── scan_result_screen.dart
│   │   ├── scan_screen.dart       # Camera capture + gallery pick
│   │   └── signup_screen.dart     # Firebase signup form
│   └── services/
│       ├── auth_service.dart      # FirebaseAuth wrapper + idToken() helper
│       ├── food_detection_service.dart
│       └── gemini_service.dart    # google_generative_ai integration
├── scripts/
│   ├── build_web.sh
│   └── build_web.ps1
├── test/
│   └── widget_test.dart           # 7 unit tests (matcher + step parser)
├── Dockerfile                     # Multi-stage Flutter → Nginx
├── cloudbuild.yaml                # Cloud Build pipeline → Cloud Run
├── pubspec.yaml                   # Dependencies + assets manifest
├── analysis_options.yaml          # Lint config
├── README.md                      # Marketing-style overview
└── DOCUMENTATION.md               # This file
```

---

## 5. Application bootstrap & navigation flow

`main.dart` does three things, in order:

```dart
WidgetsFlutterBinding.ensureInitialized();
await dotenv.load(fileName: 'assets/.env', isOptional: true);
await Firebase.initializeApp();   // reads android/app/google-services.json
runApp(const MyApp());
```

`MyApp` sets `home: const AuthGate()`. Everything from that point is decided by the user's Firebase Auth state.

### Decision tree on app launch

```
AuthGate.build()
   │
   ├── authStateChanges() == null  → OnboardingScreen
   │                                  └─→ LoginScreen
   │                                       ├─→ SignupScreen → PersonalizeScreen → AuthGate
   │                                       └─→ Sign in success → AuthGate (re-evaluates)
   │
   └── authStateChanges() == User  → _BootstrapGate
                                      ├─ loads UserPreferencesStore from Firestore
                                      ├─ loads SavedRecipesStore  from Firestore
                                      ├─ loads PantryManager       from Firestore
                                      └─→ HomeScreen (5-tab shell)
```

### HomeScreen tab structure

`HomeScreen` uses an `IndexedStack` (preserves state across tab switches):

| Index | Tab | Screen |
| --- | --- | --- |
| 0 | Home | `_HomeTab` (hero card + curated bento + inventory snippet) |
| 1 | Scan | `ScanScreen` (camera + gallery + Gemini detection) |
| 2 | Pantry | `PantryScreen` |
| 3 | Discovery | `DiscoveryScreen` |
| 4 | Profile | `ProfileScreen` |

A glass-styled bottom nav bar (`_GlassBottomNav`) switches tabs. A floating circular scan FAB shortcuts directly to the Scan tab.

---

## 6. Firebase integration deep-dive

### Initialization

The Firebase SDK is initialised in `main.dart` with no explicit options:

```dart
await Firebase.initializeApp();
```

On Android, this is enough — the Google Services Gradle plugin (`com.google.gms.google-services`, version 4.4.2) generates a `DefaultFirebaseOptions` config at build time by reading `android/app/google-services.json`.

The plugin is wired in two places:
- `android/settings.gradle.kts` — declares the plugin under `plugins { ... apply false }`.
- `android/app/build.gradle.kts` — applies the plugin in the app module.

Firebase's Android SDK requires **`minSdk >= 23`** and **`multiDexEnabled = true`**, both set in `android/app/build.gradle.kts` via the Flutter defaults.

### Services in use

| Service | Purpose | Where in code |
| --- | --- | --- |
| `firebase_core` | SDK bootstrap | `lib/main.dart` |
| `firebase_auth` | Email/password auth + JWT issuance | `lib/services/auth_service.dart` |
| `cloud_firestore` | Per-user persisted state | All `lib/logic/*_store.dart` & `pantry_manager.dart` |

No other Firebase products (Storage, FCM, Analytics, Crashlytics, Remote Config) are used.

---

## 7. Authentication & JWT

### AuthService (`lib/services/auth_service.dart`)

Lightweight wrapper around `FirebaseAuth.instance`. Exposes:

| Method | Description |
| --- | --- |
| `signIn(email, password)` | `signInWithEmailAndPassword` |
| `signUp(email, password, displayName?)` | `createUserWithEmailAndPassword`, then `updateDisplayName` if provided |
| `signOut()` | `FirebaseAuth.signOut()` |
| `currentUser` | Sync getter |
| `authStateChanges()` | Stream consumed by `AuthGate` |
| `sendPasswordResetEmail(email)` | For the "Forgot?" link on login |
| `idToken({forceRefresh})` | Returns the Firebase **JWT ID token** as a `String?` |
| `describeAuthError(error)` | Maps `FirebaseAuthException` codes to user-friendly messages |

### JWT demonstration

Firebase Auth issues a **signed JWT** for every authenticated session. Tokens are:
- Signed with Google's private RSA key
- Verifiable by anyone using Google's public JWKs at `https://securetoken.google.com/<project_id>/.well-known/openid-configuration`
- Refreshed automatically by the SDK every hour

The Profile screen has a **"View Auth Token (JWT)"** tile that calls `AuthService.instance.idToken()` and displays the raw token in a copy-able dialog. Pasting this token into [jwt.io](https://jwt.io) decodes it into three sections:

```jsonc
// Header
{ "alg": "RS256", "kid": "...", "typ": "JWT" }

// Payload
{
  "iss": "https://securetoken.google.com/ingridio-abc12",
  "aud": "ingridio-abc12",
  "auth_time": 1747844293,
  "user_id": "...",
  "sub": "...",
  "iat": 1747844293,
  "exp": 1747847893,
  "email": "test@ingridio.com",
  "email_verified": false,
  "firebase": { "identities": { "email": ["..."] }, "sign_in_provider": "password" }
}

// Signature: RSA-SHA256
```

This is the artefact used to satisfy the lab's "JWT-based authentication" requirement.

### Sign-up flow

1. `SignupScreen` collects display name (optional), email, password (min 6 chars).
2. Calls `AuthService.signUp(...)`.
3. On success, navigates to `PersonalizeScreen` (cuisine + diet selection).
4. `PersonalizeScreen._onSave()` saves preferences to Firestore and routes through `AuthGate`.
5. `AuthGate` sees the signed-in user, bootstraps all stores, lands on `HomeScreen`.

### Sign-in flow

1. `LoginScreen` collects email + password.
2. Calls `AuthService.signIn(...)`.
3. On success, `pushAndRemoveUntil(AuthGate)` — Auth Gate re-evaluates and routes to Home.

### Error mapping

```dart
'invalid-credential' / 'user-not-found' / 'wrong-password' → 'Email or password is incorrect.'
'email-already-in-use' → 'An account already exists with that email.'
'weak-password' → 'Password must be at least 6 characters.'
'network-request-failed' → 'No internet connection. Try again.'
'operation-not-allowed' → 'Email/password sign-in is not enabled in Firebase.'
```

---

## 8. Cloud Firestore data model

All user-scoped data is stored under `users/{uid}/...`. The document schema:

```
users/
  └─ {uid}/                              ← user document
       │   displayName: string?
       │   selectedCuisines: string[]    ← e.g. ["Pakistani", "Italian"]
       │   selectedDiets:    string[]    ← e.g. ["Halal", "High Protein"]
       │   notificationsEnabled: bool
       │   selectedLanguage: string      ← "English (US)" / "Urdu" / "Arabic"
       │   updatedAt: timestamp (server-generated)
       │
       ├─ pantry/
       │    └─ {ingredientId}/            ← e.g. "tomatoes"
       │         name: string
       │         category: string         ← "Fresh Produce" / "Spices" / "Grains" / "Dairy & Proteins" / "Other"
       │         quantity: int?
       │         unit: string?
       │         daysLeft: int?
       │         stockLevel: string?
       │         source: string           ← "camera" | "manual"
       │
       └─ savedRecipes/
            └─ {recipeId}/                ← existence-only marker doc
                 savedAt: timestamp (server-generated)
```

### Read/write flow

| Action | Local effect | Remote effect |
| --- | --- | --- |
| Sign in | `loadForCurrentUser()` on every store reads all docs once | none |
| Add ingredient | Local cache append + notify | `set()` doc in `pantry/` |
| Remove ingredient | Local cache remove + notify | `delete()` doc |
| Toggle save | Local set add/remove + notify | `set()` or `delete()` doc |
| Update preferences | Local field write | `set({...}, merge: true)` on user doc |
| Sign out | `clearLocal()` on every store | Firestore data preserved for next sign-in |

### Pantry seeding

On a brand-new user's first `loadForCurrentUser()` call, `PantryManager` detects an empty `pantry` collection and bulk-writes the 15 mock ingredients via a `WriteBatch`. This is wrapped in try/catch — if the seed fails (e.g. no network), the local cache falls back to `MockData.mockPantry` so the UI never appears empty.

### Security rules

The Firestore database is provisioned in **test mode** for the duration of the lab evaluation. Rules look like:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2026, 6, 19);
    }
  }
}
```

For production deployment, rules should be tightened to:

```js
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

---

## 9. State stores (in-memory caches)

Every store is a `ChangeNotifier` singleton mirroring the Firestore subset it owns. Screens consume them with `ListenableBuilder(listenable: Store.instance, builder: ...)`.

### PantryManager (`lib/logic/pantry_manager.dart`)

```dart
PantryManager.instance.items          // List<Ingredient> (unmodifiable)
PantryManager.instance.totalCount     // int
PantryManager.instance.add(ingredient)         // local + async Firestore set()
PantryManager.instance.removeById(id)          // local + async Firestore delete()
PantryManager.instance.loadForCurrentUser()    // hydrate from Firestore (with seeding fallback)
PantryManager.instance.clearLocal()            // on sign-out
PantryManager.newId()                          // 'ing_<microseconds>'
```

### SavedRecipesStore (`lib/logic/saved_recipes_store.dart`)

```dart
SavedRecipesStore.instance.ids                // Set<String> (unmodifiable)
SavedRecipesStore.instance.isSaved(id)        // bool
SavedRecipesStore.instance.toggle(id)         // local + async Firestore set/delete
SavedRecipesStore.instance.loadForCurrentUser()
SavedRecipesStore.instance.clearLocal()
```

### CookedRecipesStore (`lib/logic/cooked_recipes_store.dart`)

```dart
CookedRecipesStore.instance.count
CookedRecipesStore.instance.contains(id)
CookedRecipesStore.instance.add(id)          // currently local-only, in-memory
CookedRecipesStore.instance.clearLocal()
```

### RecipeRatingStore (`lib/logic/recipe_rating_store.dart`)

```dart
RecipeRatingStore.instance.starsFor(id)      // int?
RecipeRatingStore.instance.setRating(id, n)  // n.clamp(1, 5)
```

### UserPreferencesStore (`lib/logic/user_preferences_store.dart`)

Static-accessor API (kept for backwards compatibility), Firestore-synced under the hood:

```dart
UserPreferencesStore.current               // UserPreferences?
UserPreferencesStore.notificationsEnabled  // bool
UserPreferencesStore.selectedLanguage      // 'English (US)' | 'Urdu' | 'Arabic'
UserPreferencesStore.save(prefs)
UserPreferencesStore.setNotificationsEnabled(bool)
UserPreferencesStore.setLanguage(string)
UserPreferencesStore.loadForCurrentUser()
UserPreferencesStore.reset()
```

---

## 10. Domain models

### `Recipe` (`lib/models/recipe.dart`)

```dart
class Recipe {
  final String id, name, cuisine, cookTime, difficulty, imageUrl;
  final String? cardSubtitle, tag, description;
  final bool showAiBadge;
  final int? calories, proteinG, carbsG, fatsG, fiberG;
  final List<String> searchKeywords, ingredients, steps;
  final List<RecipeIngredientLine>? ingredientLines;
  final List<RecipeCookingStep>?    cookingSteps;
  final List<String>?               stepTitles;

  bool get hasNutrition;                       // any macro non-null
  bool matchesSearch(String queryLower);       // for Discovery search
}
```

### `Ingredient`

```dart
enum IngredientSource { camera, manual }

class Ingredient {
  final String id, name, category;
  final int? quantity, daysLeft;
  final String? unit, stockLevel;
  final IngredientSource source;
}
```

### `RecipeIngredientLine`

```dart
class RecipeIngredientLine {
  final String name;
  final double amountAtTwoServings;            // base quantity for serving=2
  final String unit;
  final String? preparation, imageUrl;
}
```

### `RecipeCookingStep`

```dart
class RecipeCookingStep { final String title, body; }
```

### `RecipeMatchResult`

```dart
class RecipeMatchResult { final Recipe recipe; final int matchPercent; }
```

### `ScannedIngredient`

```dart
enum IngredientConfidence { high, medium }
class ScannedIngredient { final String name; final IngredientConfidence confidence; }
```

### `FoodVisionResult`

Returned by `GeminiService.analyzeImageBytes`. Wraps the three things Gemini produces from one image: detected names, structured `Ingredient` objects, and AI-generated `Recipe` suggestions.

### `UserPreferences`

```dart
class UserPreferences {
  final String? displayName;
  final List<String> selectedCuisines, selectedDiets;
}
```

---

## 11. Gemini AI vision pipeline

`GeminiService` (`lib/services/gemini_service.dart`) is the AI brain of the app.

### Configuration

- **Model**: `gemini-3-flash-preview` (set via `_modelName` constant — easy to swap to `gemini-2.0-flash` or another model)
- **API key resolution order**:
  1. `String.fromEnvironment('GEMINI_API_KEY')` — passed via `--dart-define` in CI/Docker builds
  2. `dotenv.maybeGet('GEMINI_API_KEY')` — read from `assets/.env` at runtime
  3. Empty string → graceful fallback path (no exception)
- **Generation config**: `temperature: 0.4`, `responseMimeType: 'application/json'`

### Prompt structure

A single text-prompt asks Gemini to analyse the image and return JSON matching this shape:

```jsonc
{
  "detected_ingredients": ["tomatoes", "spinach", ...],
  "recipes": [
    {
      "name": "Caprese Salad",
      "match_percentage": 95,
      "prep_time": "10 mins",
      "calories": 220,
      "ingredients": [
        { "name": "Tomatoes", "amount": "2", "have_it": true },
        ...
      ],
      "steps": [
        { "step_number": 1, "instruction": "Slice tomatoes...", "duration_seconds": 60 },
        ...
      ],
      "tags": ["italian", "vegetarian", "quick"]
    }
  ]
}
```

### Robust JSON extraction

`_isolateJsonObject(raw)` handles Gemini's occasional Markdown code fences:
- Strips ```` ``` ```` fences if present
- Finds the outermost `{ ... }` block
- Throws `FormatException` if no object is found

### Robust parsing

`_parseFoodVisionResult(map)` is tolerant of variations:
- Accepts both snake_case (`match_percentage`) and camelCase (`matchPercentage`) keys
- Coerces ints from `int`, `double`, or `String`
- `_parseAmount("1/2 cup")` handles fractional quantities → `(0.5, 'cup')`
- Sorts cooking steps by `step_number` before constructing `RecipeCookingStep`s

### Failure modes

| Scenario | Behaviour |
| --- | --- |
| API key empty | Returns `FoodVisionResult(detectedIngredientNames: ["API Key Issue: ..."])` — surfaces a snackbar |
| Network failure | Caught, returned as `FoodVisionResult(detectedIngredientNames: ["API Error: ..."])` |
| Gemini returns malformed JSON | `FormatException` → snackbar with "Could not analyze this image" |
| Empty detection | Snackbar "No ingredients detected" + back to scan screen |

The UI **never crashes** because of Gemini failures — it always falls back gracefully.

---

## 12. Recipe matching algorithm

`RecipeMatcher.match(detected, catalogue)` returns a sorted `List<RecipeMatchResult>`.

### Algorithm

```
For each recipe in catalogue:
  If recipe has no ingredients listed → skip
  For each recipe ingredient:
    Normalise: lowercase + trim
    If exact match in detected set → count + continue
    Else for each detected ingredient:
      If d.contains(ingredient) or ingredient.contains(d) → count + break
  match_percent = round(100 * matched / total_ingredients)
Sort all results descending by match_percent
```

### Tolerance examples
- "Cherry Tomatoes" matches "tomatoes" via substring
- "Spinach" matches "Baby Spinach" via reverse substring
- Case-insensitive throughout

### Tests

`test/widget_test.dart` covers:
- Empty pantry → all 0%
- "Quinoa, Avocado, Spinach, Tomatoes" → top match is `Harvest Quinoa Bowl` (id 9)
- Results always sorted descending by match percent

---

## 13. Screen-by-screen reference

### 1. `OnboardingScreen` (`lib/screens/onboarding_screen.dart`)

4-page horizontal `PageView` introducing the app. Each slide has:
- Step label ("STEP 01")
- Title + body description
- A hero image with an animated "scan line" + glass info chip overlay
- Animated dot indicator at the bottom

"Skip" jumps to the last slide. "Let's Go" pushes `LoginScreen`. Onboarding only shows when the user is **not** authenticated (handled by `AuthGate`).

### 2. `LoginScreen` (`lib/screens/login_screen.dart`)

Glass-card style email/password form. Behaviours:
- Calls `AuthService.signIn(...)` on submit
- "Forgot?" → `AuthService.sendPasswordResetEmail(...)`
- "Don't have an account? Create one" → pushes `SignupScreen`
- Spinner displayed during submit; errors mapped via `AuthService.describeAuthError`

### 3. `SignupScreen` (`lib/screens/signup_screen.dart`)

Three-field form (display name optional, email, password 6+ chars). On success: replaces nav stack with `PersonalizeScreen`.

### 4. `PersonalizeScreen` (`lib/screens/personalize_screen.dart`)

Cuisine + diet selection. Constraints:
- Must pick **2+ cuisines** to enable Save
- Save writes to `UserPreferencesStore` → Firestore, then routes back through `AuthGate`
- Reusable: pushed from Profile to **edit** existing preferences (`navigateHomeOnSave: false`)

### 5. `HomeScreen` (`lib/screens/home_screen.dart`)

The 5-tab shell. Its own internal `_HomeTab` widget composes:
- Top bar with "Ingridio" wordmark + bell icon
- Hero recommendation card ("Savor the spices of Karachi") with "Start Cooking" CTA → `Chana Chaat`
- Diet chip pills (multi-select)
- Curated bento grid (Pakistani picks)
- Inventory snippet card (live count from `PantryManager`)
- Bottom glass nav + floating scan FAB

### 6. `ScanScreen` (`lib/screens/scan_screen.dart`)

Camera-heavy screen with extensive lifecycle management:
- Uses `camera` plugin on native, with a fallback path for web that tries multiple `ResolutionPreset` values
- Requests `Permission.camera` with `permission_handler`
- Animated scan-line overlay, corner brackets, pulsing detection dots
- Floating capture button → `CameraController.takePicture()`
- "Choose from gallery" → `ImagePicker.pickImage(source: gallery)`
- Captured image → `FoodDetectionService.analyzeCapture()` → shows loading dialog → routes to `ScanResultScreen` on success
- Close (X) button switches back to Home tab via `widget.onClose` callback
- Properly disposes camera when its tab becomes inactive

### 7. `ScanResultScreen` (`lib/screens/scan_result_screen.dart`)

Displays detected ingredients. User can:
- Remove false positives
- Add missing ingredients via text field
- Tap "Find Recipes with N ingredients →" → `RecipeMatchScreen`

### 8. `RecipeMatchScreen` (`lib/screens/recipe_match_screen.dart`)

Bento-grid layout of matched recipes:
- If `foodVisionResult` has Gemini-generated recipes, those are shown
- Otherwise falls back to `RecipeMatcher` against `MockData.mockRecipes`
- "Best match", "Quickest" + secondary cards
- Sort chips: by match %, by protein, by carbs
- Bottom glass nav for cross-screen navigation

### 9. `RecipeDetailScreen` (`lib/screens/recipe_detail_screen.dart`)

Full recipe detail:
- Hero image with gradient overlay + AI badge
- Stats bento (calories, time, difficulty)
- Serving adjuster (rescales `amountAtTwoServings`)
- Ingredients column showing what the user already has (matched against `detectedIngredients`)
- Steps + nutrition macros
- Save heart (writes to `SavedRecipesStore`)
- "Cook Now" → `CookingModeScreen`

### 10. `CookingModeScreen` (`lib/screens/cooking_mode_screen.dart`)

Guided step-by-step cooking:
- Swipe left/right to advance / go back
- `_InlineStepTimer` auto-detects durations via `step_timer_parse` regex ("20 mins", "1 hour", "30 sec")
- Rotating AI tip footer
- Completion overlay → star rating (writes to `RecipeRatingStore`) + "save to cooked" (writes to `CookedRecipesStore`) + back-to-home

### 11. `PantryScreen` (`lib/screens/pantry_screen.dart`)

Sectioned list of pantry items grouped by category:
- Fresh Produce / Spices / Grains / Dairy & Proteins / Other
- Each section has its own card style + icon mapping
- Live consumer of `PantryManager.instance`
- Search field filters across all sections
- "+" → bottom-sheet add form (`_AddIngredientSheet`)
- Long-press confirms removal
- Friendly empty state with "Add Ingredient" CTA when list is empty

### 12. `DiscoveryScreen` (`lib/screens/discovery_screen.dart`)

Browse mode:
- Search field filters via `Recipe.matchesSearch`
- Cuisine circles for quick cuisine filter
- "Trending" bento (1 large + 2 small)
- "Healthy" cards list

### 13. `ProfileScreen` (`lib/screens/profile_screen.dart`)

User dashboard:
- Monogram avatar (initials of display name on orange gradient)
- Display name + email
- Live stat tiles: Saved Recipes (from `SavedRecipesStore`), Cooked Recipes (from `CookedRecipesStore`)
- Preference rows for Cuisines / Diets — tap to edit via `PersonalizeScreen`
- Settings card: Notifications toggle, Language picker, **View Auth Token (JWT)** tile, Terms of Service
- Logout button → `AuthService.signOut()` + clear all stores + route through `AuthGate`

---

## 14. Design system

Located in `lib/logic/design_system.dart`.

### Colour palette

| Token | Hex | Usage |
| --- | --- | --- |
| `primary` | `#9D4300` | Brand orange (dark) |
| `primaryContainer` | `#F97316` | Brand orange (vibrant) |
| `secondary` | `#924C00` | Subdued accents |
| `background` | `#FFF8F5` | App background |
| `onSurface` | `#2F1400` | Primary text |
| `onSurfaceVariant` | `#584237` | Secondary text |
| `surfaceLowest` | `#FFFFFF` | Cards |
| `surfaceLow` | `#FFF1E9` | Subtle surfaces |
| `surfaceHigh` | `#FFE3D1` | Hover/pressed surfaces |
| `tertiary` | `#7C5800` | Tertiary actions |
| `tertiaryContainer` | `#C99000` | Badges |
| `outlineVariant` | `#E0C0B1` | Borders |

### Typography

- **Headings**: `Plus Jakarta Sans` (w700 / w800, tight letter-spacing)
- **Body**: `Be Vietnam Pro` (w400 / w500 / w600, 1.5 line height)
- All fonts loaded via `google_fonts` (no asset bundling)

### Spacing scale

`xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`

### Border radii

`sm=8, md=12, lg=16, xl=24`

### Components

- `AppleCard` — material-style rounded card with optional elevation
- `AppleButton` — three variants (primary/secondary/tertiary), three sizes (small/medium/large)
- `AppleSpacer` — typed `SizedBox`
- `SectionHeader` — header with optional subtitle + action

---

## 15. Build & run on Android

### Prerequisites

| Tool | Version |
| --- | --- |
| Flutter SDK | 3.x or later |
| Dart SDK | 3.x (bundled with Flutter) |
| Android Studio | Hedgehog or newer |
| Android SDK | API 34+ |
| Android NDK | 27.0.12077973 |
| JDK | 17 (bundled with Android Studio) |

### Setup

```bash
git clone https://github.com/saadhtiwana/Ingridio.git
cd Ingridio
flutter pub get
echo "GEMINI_API_KEY=your_actual_key" > assets/.env
# Place google-services.json into android/app/
flutter run
```

### Building a release APK

```bash
flutter build apk --release \
    --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Building an Android App Bundle (Play Store format)

```bash
flutter build appbundle --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

---

## 16. Build & run on Web (Cloud Run)

### Local web dev

```bash
flutter run -d chrome
```

### Production web build

```bash
./scripts/build_web.sh
# or
flutter build web --release
```

Output served from `build/web/`.

### Docker (multi-stage)

The `Dockerfile` does two stages:
1. **Build** — uses `ghcr.io/cirruslabs/flutter:3.41.0` to compile the web bundle with `--dart-define=GEMINI_API_KEY=...`
2. **Serve** — copies build output into `nginx:alpine` listening on port 8080

```bash
docker build --build-arg GEMINI_API_KEY="$GEMINI_API_KEY" -t ingridio .
docker run -p 8080:8080 ingridio
```

### Google Cloud Build pipeline (`cloudbuild.yaml`)

Three steps, with `GEMINI_API_KEY` pulled from Google Secret Manager:
1. `docker build` (with `--build-arg`)
2. `docker push` to GCR
3. `gcloud run deploy ingridio --region europe-west1 --allow-unauthenticated`

Trigger by pushing to the linked branch. Result: a public Cloud Run URL serving the latest build.

---

## 17. Environment variables & secrets

### `assets/.env` (loaded at app startup by `flutter_dotenv`)

```
GEMINI_API_KEY=your_actual_gemini_key
```

Get a Gemini key at [aistudio.google.com](https://aistudio.google.com).

### `--dart-define` (passed at compile time)

Same `GEMINI_API_KEY` can be set via `--dart-define=GEMINI_API_KEY=...` for CI builds. The dart-define takes precedence over the `.env` file at runtime.

### Files that contain secrets

| File | Gitignored? | Notes |
| --- | --- | --- |
| `assets/.env` | ✅ Yes | Contains Gemini API key |
| `android/app/google-services.json` | ❌ No | Contains Firebase config (project ID, API key for Firebase SDK). **Safe to commit for demos** — Firebase access is gated by security rules, not by hiding this file. |

---

## 18. Testing

```bash
flutter test
```

7 unit tests in `test/widget_test.dart` covering:
- `RecipeMatcher` (empty pantry, substring matching, descending sort)
- `step_timer_parse` (minutes, hours, seconds, no-duration, keyword detection)

```
00:00 +7: All tests passed!
```

The `flutter analyze` baseline is **0 errors**, with only pre-existing info-level lints (`deprecated_member_use` on `withOpacity` calls — Flutter's recent migration to `withValues`).

---

## 19. Demo script for the lab evaluation

A 2-minute live walk-through that hits every required feature.

| # | Action | Demonstrates |
| --- | --- | --- |
| 1 | Open the app on the emulator → tap "Skip" through onboarding | UI polish, onboarding flow |
| 2 | Tap "Don't have an account? Create one" → fill name/email/password → Create account | **Firebase Authentication** signup |
| 3 | On Personalize screen → pick 2+ cuisines → Save | Preference data flow |
| 4 | In browser: Firebase Console → **Authentication → Users** | Auth user appears |
| 5 | In browser: Firebase Console → **Firestore → users/{uid}** | Preferences doc + pantry sub-collection populated |
| 6 | In app: open any recipe → tap heart icon to save | Live Firestore write |
| 7 | Refresh Firestore → `savedRecipes` sub-collection has new entry | Real-time persistence |
| 8 | Profile → "View Auth Token (JWT)" → Copy | **JWT-based authentication** |
| 9 | Paste token into jwt.io | Decoded payload shows `iss: securetoken.google.com/...`, `email`, `exp`, etc. |
| 10 | Profile → Logout | Auth state clears |
| 11 | Login again with same credentials | Preferences + saves persist across sessions |
| 12 | Tap orange scan FAB → capture or pick from gallery | **Gemini AI vision** detection |
| 13 | Detected ingredients → Find Recipes → open detail → Cook Now | Full happy path |

---

## 20. Known limitations & future work

### Current limitations
- `CookedRecipesStore` and `RecipeRatingStore` are **in-memory only** — they don't persist across app launches. Could be migrated to Firestore in <30 min following the pattern of `SavedRecipesStore`.
- Firestore rules are in **test mode** for the demo — must be tightened before any production use.
- No password complexity enforcement beyond Firebase's "6+ chars" minimum.
- No email verification flow.
- No multi-device sync conflict resolution (last-write-wins).
- The `cookTime` field on `Recipe` is a free-form string, not parsed — sort-by-time on Discovery falls back to other heuristics.
- No offline mode beyond Firestore's built-in transient cache.

### Planned / nice-to-have
- Google Sign-In as a secondary auth provider
- Firebase Crashlytics for production error tracking
- Image upload to Firebase Storage so scanned photos are revisitable
- Push notifications via FCM for daily recipe suggestions
- Voice control in cooking mode
- Server-side recipe catalogue (currently fully client-side from `MockData`)
- True ML on-device detection via TensorFlow Lite YOLO model

---

## 21. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Build fails: "File google-services.json is missing" | File missing from `android/app/` | Re-download from Firebase Console and place at exact path |
| Build hangs at "Preparing Install NDK" | Corrupted NDK directory | `rm -rf ~/Library/Android/sdk/ndk/27.0.12077973` and let sdkmanager re-download (or install manually via `sdkmanager --install "ndk;27.0.12077973"`) |
| Sign-up fails with "operation-not-allowed" | Email/Password auth not enabled in Firebase Console | Console → Authentication → Sign-in method → Email/Password → Enable |
| Sign-up fails with PERMISSION_DENIED | Firestore rules in production mode | Console → Firestore → Rules → set to test mode or implement proper rules |
| Scanner returns "API Key Issue" | `GEMINI_API_KEY` empty or invalid | Verify `assets/.env`, get a fresh key from aistudio.google.com |
| "Email or password is incorrect" on new account | Trying to sign in before signing up | Tap "Don't have an account? Create one" |
| Profile screen shows wrong avatar | Old hardcoded image still cached | Was hardcoded `profile.jpg` — replaced with monogram in current version. Pull latest. |
| Scanner close (X) button does nothing | Was a bug in early versions (tab routing) | Fixed in current version — now calls `onClose` callback that switches tab |
| Pre-existing `withOpacity` deprecation warnings | Flutter 3.27+ migration to `withValues` | Cosmetic; will be cleaned in a future pass. |

---

## 22. Contributors & license

### Contributors
- [saadhtiwana](https://github.com/saadhtiwana) — original product concept, UI design
- [abdullahxdev](https://github.com/abdullahxdev) — Firebase integration, JWT auth, Firestore persistence

### License
MIT License — see [LICENSE](LICENSE).

---

*Last updated: 2026-05-21*
