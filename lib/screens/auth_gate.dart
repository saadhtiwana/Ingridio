import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ingridio/logic/pantry_manager.dart';
import 'package:ingridio/logic/saved_recipes_store.dart';
import 'package:ingridio/logic/user_preferences_store.dart';
import 'package:ingridio/screens/home_screen.dart';
import 'package:ingridio/screens/onboarding_screen.dart';
import 'package:ingridio/services/auth_service.dart';

/// Decides what the user sees on launch:
///  - Signed in  → loads per-user data from Firestore, then HomeScreen.
///  - Signed out → OnboardingScreen (which flows into LoginScreen).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static const Color _background = Color(0xFFFFF8F5);
  static const Color _primaryContainer = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        final User? user = snapshot.data;
        if (user == null) {
          return const OnboardingScreen();
        }
        return _BootstrapGate(uid: user.uid);
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AuthGate._background,
      body: Center(
        child: CircularProgressIndicator(
          color: AuthGate._primaryContainer,
        ),
      ),
    );
  }
}

/// Loads the per-user pantry, saved recipes, and preferences from Firestore
/// before handing off to HomeScreen.
class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate({required this.uid});

  final String uid;

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late Future<void> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _load();
  }

  @override
  void didUpdateWidget(_BootstrapGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _bootstrap = _load();
    }
  }

  Future<void> _load() async {
    await Future.wait<void>(<Future<void>>[
      UserPreferencesStore.loadForCurrentUser(),
      SavedRecipesStore.instance.loadForCurrentUser(),
      PantryManager.instance.loadForCurrentUser(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }
        return const HomeScreen();
      },
    );
  }
}
