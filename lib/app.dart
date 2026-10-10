import 'package:flutter/material.dart';

import 'features/welcome/presentation/welcome_screen.dart';

class FoodSaverApp extends StatelessWidget {
  const FoodSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Saver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFFFC107),
          surface: const Color(0xFFF5F9F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F9F3),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class MyApp extends FoodSaverApp {
  const MyApp({super.key}) : super();
}
