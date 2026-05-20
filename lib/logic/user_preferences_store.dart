import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ingridio/models/user_preferences.dart';

/// Static-accessor wrapper kept for backwards-compatibility with existing
/// screens. Reads/writes a single Firestore doc at `users/{uid}`.
class UserPreferencesStore {
  static UserPreferences? current;
  static bool notificationsEnabled = true;
  static String selectedLanguage = 'English (US)';

  /// Loads this user's preferences doc into the static fields.
  /// Called by AuthGate on sign-in.
  static Future<void> loadForCurrentUser() async {
    current = null;
    notificationsEnabled = true;
    selectedLanguage = 'English (US)';

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid)
          .get();
      final Map<String, dynamic>? data = snap.data();
      if (data == null) {
        // Seed with the Firebase Auth display name if available.
        current = UserPreferences(
          displayName: user.displayName,
          selectedCuisines: const <String>[],
          selectedDiets: const <String>[],
        );
        return;
      }
      current = UserPreferences(
        displayName:
            (data['displayName'] as String?) ?? user.displayName,
        selectedCuisines:
            List<String>.from((data['selectedCuisines'] as List<dynamic>?) ?? <dynamic>[]),
        selectedDiets:
            List<String>.from((data['selectedDiets'] as List<dynamic>?) ?? <dynamic>[]),
      );
      notificationsEnabled = (data['notificationsEnabled'] as bool?) ?? true;
      selectedLanguage =
          (data['selectedLanguage'] as String?) ?? 'English (US)';
    } on Object {
      // Keep defaults on error.
    }
  }

  static Future<void> save(UserPreferences preferences) async {
    current = preferences;
    await _writeToFirestore();
  }

  static Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    await _writeToFirestore();
  }

  static Future<void> setLanguage(String value) async {
    selectedLanguage = value;
    await _writeToFirestore();
  }

  /// Clears local state. Firestore data is preserved across sign-outs.
  static void reset() {
    current = null;
    notificationsEnabled = true;
    selectedLanguage = 'English (US)';
  }

  static Future<void> _writeToFirestore() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(<String, dynamic>{
        'displayName': current?.displayName,
        'selectedCuisines': current?.selectedCuisines ?? <String>[],
        'selectedDiets': current?.selectedDiets ?? <String>[],
        'notificationsEnabled': notificationsEnabled,
        'selectedLanguage': selectedLanguage,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on Object {
      // Best-effort.
    }
  }
}
