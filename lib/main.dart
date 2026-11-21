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
    return MaterialApp(
      title: 'MediCare Doctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0284C7),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: _unlocked
          ? DoctorShell(onLock: () => setState(() => _unlocked = false))
          : LoginScreen(onAuthenticated: () => setState(() => _unlocked = true)),
    );
  }
}

