import 'package:flutter/material.dart';
import 'screens/permission_screen.dart';

void main() {
  runApp(const CampusDensityApp());
}

class CampusDensityApp extends StatelessWidget {
  const CampusDensityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kampüs Yoğunluk Sistemi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF146C94),
        ),
        useMaterial3: true,
      ),
      home: const PermissionScreen(),
    );
  }
}