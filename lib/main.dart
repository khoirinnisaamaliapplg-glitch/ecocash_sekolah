import 'package:ecocash_sekolah/landingpage.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoCash',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green, // Tema hijau untuk EcoCash
      ),
      home: const SplashLandingPage(),
    );
  }
}
