import 'package:flutter/material.dart';
import '../../core/config/specialties.dart';
import '../../core/network/api_client.dart';
import '../../core/security/secure_session.dart';
import '../patients/patient_360_screen.dart';

class DoctorShell extends StatefulWidget {
  final VoidCallback onLock;
  const DoctorShell({super.key, required this.onLock});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _tabIndex = 0;
  SpecialtyMeta _activeSpecialty = kSpecialties.first;
  final _api = ApiClient();
  List<dynamic> _patients = [];
  List<dynamic> _appointments = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    try {
      final results = await Future.wait([_api.getPatients(), _api.getAppointments()]);
      if (mounted) {
        setState(() {
          _patients = results[0];
          _appointments = results[1];
        });
      }
    } catch (_) {
      // Mantiene datos cacheados si está offline
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      // Tab 0: Agenda de Hoy
      RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _appointments.length,
          itemBuilder: (_, i) {
            final a = Map<String, dynamic>.from(_appointments[i]);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.schedule)),
                title: Text(a['PatientName']?.toString() ?? 'Paciente'),
                subtitle: Text('${a['AppointmentTime']} · ${a['Reason']}'),
                trailing: Chip(label: Text(a['Stage']?.toString() ?? '')),
              ),
            );
          },
        ),
      ),
      // Tab 1: Pacientes
      RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _patients.length,
          itemBuilder: (_, i) {
            final p = Map<String, dynamic>.from(_patients[i]);
            final fullName = '${p['FirstName']} ${p['LastName']}';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(_activeSpecialty.colorHex).withValues(alpha: 0.12),
                  child: Text(fullName.isNotEmpty ? fullName[0] : 'P'),
                ),
                title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p['HistoryNumber']} · ${p['PrimarySpecialtyName']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Patient360Screen(
                      patientId: p['Id'].toString(),
                      patientName: fullName,
                      activeSpecialty: _activeSpecialty,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      // Tab 2: Copiloto IA Rápido
      const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Dictado Clínico con Copiloto Gemini AI\n(Conectado a POST /api/ai/process-consultation)',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      // Tab 3: Seguridad y Especialidad
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<SpecialtyMeta>(
                value: _activeSpecialty,
                decoration: const InputDecoration(
                  labelText: 'Especialidad Activa del Médico',
                  border: OutlineInputBorder(),
                ),
                items: kSpecialties
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _activeSpecialty = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Bloquear aplicación ahora'),
            onTap: widget.onLock,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE11D48)),
            title: const Text('Cerrar sesión segura', style: TextStyle(color: Color(0xFFE11D48))),
            onTap: () async {
              await SecureSession.clearSession();
              widget.onLock();
            },
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MediCare Doctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              _activeSpecialty.name,
              style: TextStyle(fontSize: 11, color: Color(_activeSpecialty.colorHex)),
            ),
          ],
        ),
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Hoy'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Pacientes'),
          NavigationDestination(icon: Icon(Icons.mic_none), label: 'Consulta IA'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Seguridad'),
        ],
      ),
    );
  }
}

