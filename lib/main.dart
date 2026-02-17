import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/verification_screen.dart';
import 'screens/dashboard_screen.dart';
import 'utils/constants.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized before async calls
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Check Shared Preferences to see if setup is done
  final prefs = await SharedPreferences.getInstance();
  final bool isSetupComplete =
      prefs.getBool(Constants.prefIsSetupComplete) ?? false;

  // 3. Launch the App
  runApp(MyApp(
      startScreen: isSetupComplete
          ? const DashboardScreen()
          : const VerificationScreen()));
}

class MyApp extends StatelessWidget {
  final Widget startScreen;

  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CipherSpend',
      debugShowCheckedModeBanner: false, // Hides the "Debug" banner

      // 4. Global Theme Configuration (Cyber/Dark Mode)
      theme: ThemeData.dark().copyWith(
        primaryColor: Constants.colorPrimary,
        scaffoldBackgroundColor: Constants.colorBackground,

        // AppBar Styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Constants.colorSurface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Button Styling
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Constants.colorPrimary,
            foregroundColor: Colors.black, // Text color on buttons
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Input Field Styling
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Constants.colorSurface,
          labelStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Constants.colorPrimary),
          ),
        ),

        // Color Scheme
        colorScheme: const ColorScheme.dark().copyWith(
          primary: Constants.colorPrimary,
          secondary: Constants.colorPrimary,
          surface: Constants.colorSurface,
        ),
      ),

      // 5. Route to correct screen
      home: startScreen,
    );
  }
}
