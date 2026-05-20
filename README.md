<div align="center">

# 🥘 Ingridio

### *Snap your fridge. Cook what's already there.*

**An AI-powered recipe assistant that turns the ingredients you have on hand into recipes you can actually make — powered by Google Gemini vision and Firebase.**

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth_%2B_Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini](https://img.shields.io/badge/Gemini_2.0_Flash-Vision_AI-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)

[![Cloud Run](https://img.shields.io/badge/Google_Cloud_Run-Deployed-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)](https://cloud.google.com/run)
[![JWT](https://img.shields.io/badge/Auth-JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white)](https://jwt.io)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android_%7C_Web-3DDC84?style=for-the-badge&logo=android&logoColor=white)](#)

<br/>

[**Demo Flow**](#-demo-flow) • [**Features**](#-key-features) • [**Architecture**](#-architecture) • [**Quick Start**](#-quick-start) • [**Documentation**](DOCUMENTATION.md)

</div>

---

## 🎯 Why Ingridio?

You stare into your fridge. You have *stuff*. You don't know what to make. You scroll Pinterest for 20 minutes, give up, and order takeout.

**Ingridio fixes that loop.** Open the camera, point at your ingredients, and within seconds you have:

- A precise list of what was detected
- A ranked feed of recipes you can actually cook — sorted by **how much of the dish you already own**
- A guided cooking mode that walks you through each step with auto-detected timers

No more "I have 90% of the ingredients" frustration. Ingridio tells you upfront.

---

## ✨ Key Features

<table>
<tr>
<td width="50%" valign="top">

### 🔍 **AI Vision Detection**
Snap your fridge or pantry — Google Gemini 2.0 Flash identifies every visible ingredient and suggests recipes that fit.

### 🍳 **Smart Recipe Matching**
Substring-tolerant matcher ranks recipes by how much of the dish you already own. No surprise "missing ingredients" mid-recipe.

### 👨‍🍳 **Guided Cooking Mode**
Step-by-step instructions with **auto-detected inline timers** ("Simmer for 20 mins" → tap to start a 20-min timer right there).

### 🌶️ **South-Asian + Global Catalogue**
Pakistani biryani, kebabs, nihari alongside Italian pasta, Mediterranean bowls, and healthy meal-prep classics.

</td>
<td width="50%" valign="top">

### 🔐 **Firebase Authentication**
Email/password signup with **JWT-based ID tokens** (RSA-signed, verifiable on jwt.io). Persistent sessions across app launches.

### ☁️ **Real-Time Cloud Sync**
Saved recipes, pantry items, and preferences sync to Cloud Firestore. Log out on one device, log back in elsewhere — everything's still there.

### 🌍 **Multi-Language Ready**
English (US), Urdu, and Arabic support baked into the preferences.

### 🎨 **Modern Material 3 Design**
Glass-morphism HUDs, bento-grid layouts, warm orange palette, Plus Jakarta Sans + Be Vietnam Pro typography — built for the eye.

</td>
</tr>
</table>

---

## 📱 Demo Flow

<div align="center">

| 1. Onboarding | 2. Sign Up | 3. Scan | 4. Match | 5. Cook |
|:---:|:---:|:---:|:---:|:---:|
| Beautiful 4-page intro | Firebase email/password | Camera + Gemini vision | Ranked by match % | Guided steps + timers |
| <img src="https://github.com/user-attachments/assets/2e9f7d31-bd3f-45c8-9eca-1e921dfbe968" width="160" /> | 🔐 Email + JWT | <img src="https://github.com/user-attachments/assets/d098480c-7f6e-4cd8-8fdd-adf4c6d698ab" width="160" /> | <img src="https://github.com/user-attachments/assets/eba105fe-98b2-4b40-aa95-af3f5545764d" width="160" /> | <img src="https://github.com/user-attachments/assets/d3d7d249-9bf8-4e64-891b-67d1cd4c34a5" width="160" /> |

</div>

---

## 🧩 Architecture

```
                    ┌────────────────────────────┐
                    │       Flutter App           │
                    │  (Android · Web target)     │
                    └────┬─────────────────┬──────┘
                         │                 │
                ┌────────┘                 └────────┐
                ▼                                   ▼
     ┌─────────────────────┐              ┌─────────────────────┐
     │   GeminiService     │              │  Firebase Services  │
     │  google_generative  │              │ ─────────────────── │
     │       _ai           │              │  Auth (JWT tokens)  │
     │                     │              │  Firestore (NoSQL)  │
     │ Vision → JSON       │              │                     │
     │ Ingredients +       │              │  users/{uid}/       │
     │ Recipe suggestions  │              │    ├ pantry/        │
     └─────────┬───────────┘              │    └ savedRecipes/  │
               │                          └─────────────────────┘
               ▼                                     ▲
       ┌───────────────┐                             │
       │ RecipeMatcher │                             │
       │  (% match)    │                             │
       └───────┬───────┘                             │
               │                                     │
               ▼                                     │
     ┌─────────────────────────────────────┐         │
     │   In-app State Stores (singletons)  │         │
     │  ─────────────────────────────────  │ ────────┘
     │   PantryManager · SavedRecipesStore │
     │   CookedRecipesStore · RatingStore  │
     │   UserPreferencesStore              │
     └─────────────────────────────────────┘
```

**Zero backend code shipped by us.** Firebase handles persistence + auth. Gemini handles vision. The Flutter app is the only thing we maintain.

---

## 🏗️ Tech Stack

<table>
<tr>
<td width="33%" valign="top">

#### 📱 Mobile
- **Flutter** 3.x
- **Dart** 3.x
- Material 3 + custom design system
- `google_fonts` for typography

</td>
<td width="33%" valign="top">

#### 🧠 AI
- **Google Gemini 2.0 Flash**
- `google_generative_ai` SDK
- Vision-to-JSON pipeline
- Graceful fallback on failures

</td>
<td width="33%" valign="top">

#### ☁️ Backend
- **Firebase Auth** (JWT ID tokens)
- **Cloud Firestore** (NoSQL, real-time)
- **Cloud Run** (Nginx Alpine container)
- **Cloud Build** (CI/CD)

</td>
</tr>
</table>

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.x+
- Android Studio (with Android SDK + emulator)
- A Firebase project (free tier works)
- A Google AI Studio Gemini API key — free tier OK

### Setup

```bash
# 1. Clone
git clone https://github.com/saadhtiwana/Ingridio.git
cd Ingridio

# 2. Install Flutter dependencies
flutter pub get

# 3. Add your Gemini API key (gitignored automatically)
echo "GEMINI_API_KEY=your_actual_key_here" > assets/.env

# 4. Drop your Firebase config (downloaded from Firebase Console)
# → android/app/google-services.json

# 5. Boot an Android emulator (or plug in a phone with USB debugging)
flutter emulators --launch <emulator_id>

# 6. Run!
flutter run
```

That's it. The app will sign you up, sync to Firestore, and you're cooking. See [DOCUMENTATION.md §15-17](DOCUMENTATION.md#15-build--run-on-android) for the full setup walk-through.

---

## 🔐 Firebase Setup (one-time, ~10 min)

<details>
<summary><b>Click to expand step-by-step</b></summary>

1. **Create Firebase project** at [console.firebase.google.com](https://console.firebase.google.com) — name it whatever you want.
2. **Add Android app** with package name `com.ingridio.ingridio`.
3. **Download `google-services.json`** → drop into `android/app/`.
4. **Enable Email/Password auth**: Build → Authentication → Sign-in method → Email/Password → Enable.
5. **Create Firestore database**: Build → Firestore Database → Create → **Start in test mode** → pick closest region.
6. **Run `flutter run`** — sign up, your data appears in Firestore Console in real time.

For production, tighten the Firestore rules:
```js
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

</details>

---

## 🎬 Demo Walk-through

| Step | What you do | What it proves |
|------|-------------|----------------|
| **1** | Sign up with email + password | Firebase Auth working — check **Authentication → Users** in console |
| **2** | Pick cuisines on Personalize → Save | Preferences write to Firestore — check **users/{uid}** doc |
| **3** | Save any recipe (heart icon) | Real-time Firestore write — check **savedRecipes** sub-collection |
| **4** | Profile → "View Auth Token (JWT)" → Copy → paste at [jwt.io](https://jwt.io) | **JWT auth** with decoded `iss`, `email`, `exp` etc. |
| **5** | Logout → log back in | Persistence across sessions |
| **6** | Tap scan FAB → take a photo of food | **Gemini AI** detection in action |

---

## 📂 Project Structure

```
lib/
├── data/          Mock pantry + curated recipe catalogue
├── logic/         Stores, matcher, design system, timer parser
├── models/        Recipe, Ingredient, UserPreferences, ...
├── screens/       13 screens — onboarding, auth, home, scan, cook, profile, ...
└── services/      AuthService (Firebase) · GeminiService · FoodDetectionService
```

See [DOCUMENTATION.md §4](DOCUMENTATION.md#4-repository-layout) for the complete tree.

---

## 🧪 Testing

```bash
flutter test
```

```
00:00 +7: All tests passed!
```

Unit tests cover the recipe matching algorithm and the step-timer regex parser.

---

## 📚 Full Documentation

For deep technical detail — every store, every screen, every Firestore document shape, build pipelines, security considerations — see:

### 👉 [**DOCUMENTATION.md**](DOCUMENTATION.md)

(22 sections, table-of-contents driven, fully indexed.)

---

## 👥 Contributors

<table>
<tr>
<td align="center">
<a href="https://github.com/saadhtiwana">
<img src="https://github.com/saadhtiwana.png" width="80" style="border-radius:50%"/><br/>
<sub><b>saadhtiwana</b></sub>
</a><br/>
<sub>Product concept · UI design</sub>
</td>
<td align="center">
<a href="https://github.com/abdullahxdev">
<img src="https://github.com/abdullahxdev.png" width="80" style="border-radius:50%"/><br/>
<sub><b>abdullahxdev</b></sub>
</a><br/>
<sub>Firebase integration · JWT auth · Firestore</sub>
</td>
</tr>
</table>

---

## 📜 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with 🧡 in Flutter + Firebase**

*If you found this useful, drop a ⭐ on the repo.*

</div>
