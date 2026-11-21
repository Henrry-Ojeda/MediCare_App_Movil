import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'features/auth/login_screen.dart';
import 'features/home/doctor_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediCareDoctorApp());
}

class MediCareDoctorApp extends StatefulWidget {
  const MediCareDoctorApp({super.key});

  @override
  State<MediCareDoctorApp> createState() => _MediCareDoctorAppState();
}

class _MediCareDoctorAppState extends State<MediCareDoctorApp> with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiClient.onUnauthorized = () {
      if (mounted) setState(() => _unlocked = false);
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Bloqueo automático tipo app bancaria cuando el médico minimiza la app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _unlocked) {
      setState(() => _unlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0284C7),
      primary: const Color(0xFF0284C7),
      secondary: const Color(0xFF0D9488),
      surface: const Color(0xFFF1F5F9),
    );

    return MaterialApp(
      title: 'MediCare Doctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFEFF6FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0369A1),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFDBEAFE)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE0F2FE),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF0369A1) : const Color(0xFF64748B),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            );
          }),
        ),
      ),
      home: _unlocked
          ? DoctorShell(onLock: () => setState(() => _unlocked = false))
          : LoginScreen(onAuthenticated: () => setState(() => _unlocked = true)),
    );
  }
}
