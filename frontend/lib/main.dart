import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';

void main() {
  runApp(const DemandTwinApp());
}

class DemandTwinApp extends StatelessWidget {
  const DemandTwinApp({super.key});

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF176F5E);
    return MaterialApp(
      title: 'DemandTwin AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7F9),
        colorScheme: const ColorScheme.light(
          primary: mint,
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFC9433D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF182333),
          surfaceTintColor: Color(0xFFFFFFFF),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFDCE2E9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFDCE2E9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: mint),
          ),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}
