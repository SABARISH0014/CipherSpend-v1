import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/startup_screen.dart'; // Imports the file
import 'services/ai_service.dart';
import 'utils/constants.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load the AI Model 
  // We do this BEFORE runApp so the AI is ready as soon as the app opens
  await AIService().loadModel();

  // 3. Lock orientation to Portrait for better UI stability
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CipherSpend',
      debugShowCheckedModeBanner: false,

      theme: ThemeData.dark().copyWith(
        primaryColor: Constants.colorPrimary,
        scaffoldBackgroundColor: Constants.colorBackground,

        // AppBar Styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Sleek transparent app bar
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        // Button Styling
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Constants.colorPrimary,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Smoother corners
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        // Input Field Styling
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Constants.colorSurface,
          labelStyle: const TextStyle(color: Colors.grey),
          hintStyle: const TextStyle(color: Colors.white24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Constants.colorPrimary),
          ),
        ),

        // Color Scheme
        colorScheme: const ColorScheme.dark().copyWith(
          primary: Constants.colorPrimary,
          secondary: Constants.colorPrimary,
          surface: Constants.colorSurface,
          error: Constants.colorError,
        ),
      ),

      // Security Root: Booting into StartupScreen
      home: const StartupScreen(), 
    );
  }
}