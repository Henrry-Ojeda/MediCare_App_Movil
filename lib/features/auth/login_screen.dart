import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/security/secure_session.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  bool _hasSavedSession = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometricSession();
  }

  Future<void> _checkBiometricSession() async {
    final token = await SecureSession.getToken();
    final bioEnabled = await SecureSession.isBiometricEnabled();
    if (mounted && token != null && token.isNotEmpty) {
      setState(() => _hasSavedSession = true);
      if (bioEnabled) {
        await _unlockWithBiometrics();
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final ok = await SecureSession.authenticateWithBiometrics();
    if (ok && mounted) {
      widget.onAuthenticated();
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.login(_emailCtrl.text.trim(), _passCtrl.text);
      final user = Map<String, dynamic>.from(res['user']);
      await SecureSession.saveSession(
        token: res['token'] as String,
        doctorName: user['name'] as String? ?? 'Médico',
        email: user['email'] as String? ?? _emailCtrl.text.trim(),
      );
      await SecureSession.setBiometricEnabled(true);
      if (mounted) widget.onAuthenticated();
    } catch (e) {
      setState(() => _error = 'Credenciales inválidas o sin conexión al servidor.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.verified_user_rounded, size: 56, color: Color(0xFF0284C7)),
                const SizedBox(height: 16),
                const Text(
                  'MediCare Doctor',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Acceso clínico protegido con cifrado Keystore y biometría',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),
                if (_hasSavedSession) ...[
                  FilledButton.icon(
                    onPressed: _unlockWithBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Desbloquear con Huella / Face ID'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo institucional',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Ingresar de forma segura', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

