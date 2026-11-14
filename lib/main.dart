import 'package:ecocash_sekolah/Auth/login.dart';
import 'package:ecocash_sekolah/core/api_client.dart';
import 'package:ecocash_sekolah/landingpage.dart';
import 'package:flutter/material.dart';

/// Needed so a 401 from any screen can return to the login page without every
/// screen keeping a reference to a navigator.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  ApiClient.onUnauthorized = _openLogin;
  runApp(const MainApp());
}

void _openLogin() {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EcoCash Kids',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const SplashLandingPage(),
    );
  }
}
