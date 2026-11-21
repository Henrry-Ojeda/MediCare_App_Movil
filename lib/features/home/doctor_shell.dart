import 'package:flutter/material.dart';
import '../../core/config/specialties.dart';
import '../../core/network/api_client.dart';
import '../../core/security/secure_session.dart';
import '../agenda/agenda_screen.dart';
import '../consultation/consultation_screen.dart';
import '../patients/patient_360_screen.dart';
import '../patients/patient_form_screen.dart';

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
  final _patientSearchCtrl = TextEditingController();
  List<dynamic> _patients = [];
  List<dynamic> _appointments = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    super.dispose();
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

  void _openConsultation(Map<String, dynamic> patient, {String? appointmentId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationScreen(
          patient: patient,
          appointmentId: appointmentId,
          onCompleted: _refreshData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _patientSearchCtrl.text.trim().toLowerCase();
    final filteredPatients = query.isEmpty
        ? _patients
        : _patients.where((raw) {
            final p = Map<String, dynamic>.from(raw);
            final text =
                '${p['FirstName']} ${p['LastName']} ${p['HistoryNumber']} ${p['GuardianName']} ${p['GuardianWhatsapp']}'
                    .toLowerCase();
            return text.contains(query);
          }).toList();

    final pages = [
      // Tab 0: Agenda configurable + Histórico
      AgendaScreen(
        appointments: _appointments,
        patients: _patients,
        onRefresh: _refreshData,
        onStartConsultationFromApt: (apt) {
          final patId = (apt['PatientId'] ?? '').toString();
          final found = _patients.firstWhere(
            (raw) => Map<String, dynamic>.from(raw)['Id'].toString() == patId,
            orElse: () => {
              'Id': patId,
              'FirstName': apt['PatientName'] ?? 'Paciente',
              'LastName': '',
              'BirthDate': apt['PatientBirthDate'] ?? '2022-01-01',
              'Sex': 'M',
            },
          );
          _openConsultation(
            Map<String, dynamic>.from(found),
            appointmentId: apt['Id']?.toString(),
          );
        },
      ),
      // Tab 1: Pacientes (Búsqueda + Crear + Historial / Consulta)
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _patientSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por niño, historia o representante...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PatientFormScreen()),
                    );
                    await _refreshData();
                    if (result is Map && result['patient'] != null && mounted) {
                      final pat = Map<String, dynamic>.from(result['patient']);
                      if (result['startConsultation'] == true) {
                        _openConsultation(pat);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Patient360Screen(
                              patientId: pat['Id'].toString(),
                              patientName: '${pat['FirstName']} ${pat['LastName']}',
                              activeSpecialty: _activeSpecialty,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: filteredPatients.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No se encontraron pacientes.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredPatients.length,
                      itemBuilder: (_, i) {
                        final p = Map<String, dynamic>.from(filteredPatients[i]);
                        final fullName = '${p['FirstName']} ${p['LastName']}'.trim();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Color(_activeSpecialty.colorHex).withValues(alpha: 0.12),
                              child: Text(fullName.isNotEmpty ? fullName[0] : 'P'),
                            ),
                            title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${p['HistoryNumber'] ?? ''} · ${p['PrimarySpecialtyName'] ?? 'Pediatría'}'),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.medical_services_outlined, color: Color(0xFF0284C7)),
                                  tooltip: 'Iniciar Consulta',
                                  onPressed: () => _openConsultation(p),
                                ),
                              ],
                            ),
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
          ),
        ],
      ),
      // Tab 2: Ajustes y Seguridad
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
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color(_activeSpecialty.colorHex),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('MediCare · ${_activeSpecialty.name}', style: const TextStyle(fontSize: 17)),
          ],
        ),
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Pacientes'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}
