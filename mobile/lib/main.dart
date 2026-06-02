import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/permission_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const CampusDensityApp());
}

class CampusDensityApp extends StatefulWidget {
  const CampusDensityApp({super.key});

  static CampusDensityAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<CampusDensityAppState>();

  @override
  State<CampusDensityApp> createState() => CampusDensityAppState();
}

class CampusDensityAppState extends State<CampusDensityApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  bool get isDark => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kampüs Yoğunluk',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: const PermissionScreen(),
    );
  }
}
