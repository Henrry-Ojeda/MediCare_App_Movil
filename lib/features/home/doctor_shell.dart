import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_version.dart';
import '../../core/config/specialties.dart';
import '../../core/network/api_client.dart';
import '../../core/security/secure_session.dart';
import '../../core/utils/pediatric_calculations.dart';
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
  String _doctorName = 'Médico';
  String _doctorEmail = '';
  bool _loading = false;
  bool _checkingUpdate = false;

  int _slotInterval = 30;
  List<int> _workingDays = [1, 2, 3, 4, 5, 6];
  String _recipeOrientation = 'vertical';
  final _recipeHeaderCtrl = TextEditingController(text: 'Consultorio Pediátrico MediCare');
  final _recipeFooterCtrl = TextEditingController(
    text: 'Control y seguimiento pediátrico · WhatsApp de emergencias',
  );
  bool _recipeShowOms = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSettings();
    _refreshData();
  }

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    _recipeHeaderCtrl.dispose();
    _recipeFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _slotInterval = prefs.getInt('medicare_agenda_interval') ?? 30;
      final savedDays = prefs.getStringList('medicare_agenda_days');
      if (savedDays != null && savedDays.isNotEmpty) {
        _workingDays = savedDays.map(int.parse).toList();
      }
      _recipeOrientation = prefs.getString('medicare_recipe_orientation') ?? 'vertical';
      final h = prefs.getString('medicare_recipe_header');
      if (h != null && h.isNotEmpty) _recipeHeaderCtrl.text = h;
      final f = prefs.getString('medicare_recipe_footer');
      if (f != null && f.isNotEmpty) _recipeFooterCtrl.text = f;
      _recipeShowOms = prefs.getBool('medicare_recipe_show_oms') ?? true;
    });
  }

  Future<void> _saveAgendaSettings(int interval, List<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('medicare_agenda_interval', interval);
    await prefs.setStringList('medicare_agenda_days', days.map((d) => '$d').toList());
    if (!mounted) return;
    setState(() {
      _slotInterval = interval;
      _workingDays = days;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuración de agenda guardada.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveRecipeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medicare_recipe_orientation', _recipeOrientation);
    await prefs.setString('medicare_recipe_header', _recipeHeaderCtrl.text.trim());
    await prefs.setString('medicare_recipe_footer', _recipeFooterCtrl.text.trim());
    await prefs.setBool('medicare_recipe_show_oms', _recipeShowOms);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Personalización de récipe guardada.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final info = await _api.checkAppUpdate();
      if (!mounted) return;
      final remoteVersion = (info['version'] ?? kAppVersion).toString();
      final remoteBuild = int.tryParse((info['buildNumber'] ?? '').toString()) ?? 0;
      final notes = (info['notes'] ?? '').toString();
      final downloadUrl = (info['apkUrl'] ?? info['downloadPageUrl'] ?? '').toString();

      final hasUpdate = isNewerAppVersion(
        remoteVersion: remoteVersion,
        remoteBuildNumber: remoteBuild,
      );

      if (!hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu app está actualizada (v$kAppVersion · Build $kAppBuildNumber).'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Nueva versión disponible: v$remoteVersion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Instalada: v$kAppVersion (Build $kAppBuildNumber)\nDisponible: v$remoteVersion (Build $remoteBuild)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(notes, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Más tarde'),
            ),
            if (downloadUrl.isNotEmpty)
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.tryParse(downloadUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Descargar APK'),
              ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo consultar actualizaciones. Verifica tu conexión.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _loadProfile() async {
    final name = await SecureSession.getDoctorName();
    final email = await SecureSession.getDoctorEmail();
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _doctorName = name;
        if (email != null && email.isNotEmpty) _doctorEmail = email;
      });
    }
  }

  Future<void> _refreshData() async {
    if (mounted) setState(() => _loading = true);
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
    } finally {
      if (mounted) setState(() => _loading = false);
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

  void _openPatient360(Map<String, dynamic> patient) {
    final fullName = '${patient['FirstName'] ?? ''} ${patient['LastName'] ?? ''}'.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Patient360Screen(
          patientId: patient['Id'].toString(),
          patientName: fullName.isEmpty ? 'Paciente' : fullName,
          activeSpecialty: _activeSpecialty,
        ),
      ),
    );
  }

  Future<void> _createPatientAndOptionallyConsult() async {
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
        _openPatient360(pat);
      }
    }
  }

  Future<void> _openQuickConsultationPicker() async {
    final searchCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final q = searchCtrl.text.trim().toLowerCase();
          final matches = q.isEmpty
              ? _patients
              : _patients.where((raw) {
                  final p = Map<String, dynamic>.from(raw);
                  return '${p['FirstName']} ${p['LastName']} ${p['HistoryNumber']} ${p['GuardianName']}'
                      .toLowerCase()
                      .contains(q);
                }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (_, scrollCtrl) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Iniciar Nueva Consulta',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _createPatientAndOptionallyConsult();
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Nuevo Paciente'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar paciente por nombre o historia...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF0F9FF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay pacientes que coincidan.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: matches.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final p = Map<String, dynamic>.from(matches[i]);
                              final fullName = '${p['FirstName'] ?? ''} ${p['LastName'] ?? ''}'.trim();
                              final ageLabel = calculateExactAgeLabel(
                                (p['BirthDate'] ?? '').toString(),
                              );
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE0F2FE),
                                  foregroundColor: const Color(0xFF0369A1),
                                  child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P'),
                                ),
                                title: Text(
                                  fullName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text('${p['HistoryNumber'] ?? 'Sin HC'} · $ageLabel'),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Color(0xFF0284C7),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _openConsultation(p);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _findPatientForApt(Map<String, dynamic> apt) {
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
    return Map<String, dynamic>.from(found);
  }

  Widget _buildDashboardTab() {
    final today = _todayIso();
    final todayApts = _appointments.where((raw) {
      final a = Map<String, dynamic>.from(raw);
      return (a['Date'] ?? a['AppointmentDate'] ?? '').toString().startsWith(today);
    }).toList();

    final completedToday = todayApts.where((raw) {
      final s = (Map<String, dynamic>.from(raw)['Status'] ?? '').toString().toLowerCase();
      return s.contains('atend') || s.contains('complet');
    }).length;

    final pendingToday = todayApts.length - completedToday;
    final recentPatients = _patients.take(6).toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header Clínico con gradiente vivo
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF0D9488)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.medical_information_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, $_doctorName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_activeSpecialty.name} · Historial Clínico Digital',
                            style: const TextStyle(
                              color: Color(0xFFE0F2FE),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _refreshData,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, color: Colors.white),
                      tooltip: 'Sincronizar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionHeroButton(
                        icon: Icons.medical_services_rounded,
                        label: 'Nueva Consulta',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0369A1),
                        onTap: _openQuickConsultationPicker,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionHeroButton(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Nuevo Paciente',
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        borderColor: Colors.white.withValues(alpha: 0.35),
                        onTap: _createPatientAndOptionallyConsult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grid KPIs clínicos con color vivo
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Historiales',
                        value: '${_patients.length}',
                        icon: Icons.folder_shared_rounded,
                        accentColor: const Color(0xFF0284C7),
                        bgTint: const Color(0xFFE0F2FE),
                        onTap: () => setState(() => _tabIndex = 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiCard(
                        title: 'Consultas Hoy',
                        value: '${todayApts.length}',
                        icon: Icons.event_available_rounded,
                        accentColor: const Color(0xFF0D9488),
                        bgTint: const Color(0xFFCCFBF1),
                        onTap: () => setState(() => _tabIndex = 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Atendidos Hoy',
                        value: '$completedToday',
                        icon: Icons.check_circle_rounded,
                        accentColor: const Color(0xFF059669),
                        bgTint: const Color(0xFFD1FAE5),
                        onTap: () => setState(() => _tabIndex = 2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiCard(
                        title: 'En Espera',
                        value: '$pendingToday',
                        icon: Icons.pending_actions_rounded,
                        accentColor: const Color(0xFFD97706),
                        bgTint: const Color(0xFFFEF3C7),
                        onTap: () => setState(() => _tabIndex = 2),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Atenciones de Hoy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _tabIndex = 2),
                      child: const Text('Ver Agenda'),
                    ),
                  ],
                ),
                if (todayApts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Sin citas programadas para hoy. Puedes iniciar una consulta directa desde "Nueva Consulta".',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...todayApts.take(4).map((raw) {
                    final apt = Map<String, dynamic>.from(raw);
                    final patient = _findPatientForApt(apt);
                    final time = (apt['Time'] ?? apt['SlotTime'] ?? '--:--').toString();
                    final status = (apt['Status'] ?? 'Pendiente').toString();
                    final isDone = status.toLowerCase().contains('atend') ||
                        status.toLowerCase().contains('complet');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDone ? const Color(0xFFD1FAE5) : const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: isDone
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (apt['PatientName'] ?? 'Paciente').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    (apt['Reason'] ?? 'Control Pediátrico').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _openPatient360(patient),
                              icon: const Icon(Icons.folder_shared_outlined, color: Color(0xFF6366F1)),
                              tooltip: 'Historial 360°',
                            ),
                            FilledButton(
                              onPressed: () => _openConsultation(
                                patient,
                                appointmentId: apt['Id']?.toString(),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Atender', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Historiales Clínicos Recientes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _tabIndex = 1),
                      child: const Text('Ver Todos'),
                    ),
                  ],
                ),
                if (recentPatients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Aún no hay pacientes registrados.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  ...recentPatients.map((raw) => _buildPatientClinicalCard(Map<String, dynamic>.from(raw))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientClinicalCard(Map<String, dynamic> p) {
    final fullName = '${p['FirstName'] ?? ''} ${p['LastName'] ?? ''}'.trim();
    final isFemale = (p['Sex'] ?? '').toString().toUpperCase() == 'F';
    final ageLabel = calculateExactAgeLabel((p['BirthDate'] ?? '').toString());
    final historyNumber = (p['HistoryNumber'] ?? 'Sin HC').toString();
    final guardian = (p['GuardianName'] ?? '').toString();
    final allergies = (p['Allergies'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openPatient360(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        isFemale ? const Color(0xFFFCE7F3) : const Color(0xFFE0F2FE),
                    foregroundColor:
                        isFemale ? const Color(0xFFBE185D) : const Color(0xFF0369A1),
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fullName.isEmpty ? 'Paciente' : fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                historyNumber,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientFormScreen(initialPatient: p),
                                  ),
                                );
                                await _refreshData();
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                              tooltip: 'Editar paciente',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$ageLabel${guardian.isNotEmpty ? ' · Rep: $guardian' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (allergies.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFBE123C)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Alergia: $allergies',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPatient360(p),
                      icon: const Icon(Icons.folder_shared_rounded, size: 17),
                      label: const Text('Historial 360°', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFFC7D2FE)),
                        backgroundColor: const Color(0xFFEEF2FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openConsultation(p),
                      icon: const Icon(Icons.medical_services_rounded, size: 17),
                      label: const Text('Consultar', style: TextStyle(fontSize: 12.5)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsHistoryTab(List<dynamic> filteredPatients) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _patientSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar por niño, historia o representante...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0284C7)),
                    filled: true,
                    fillColor: const Color(0xFFF0F9FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _createPatientAndOptionallyConsult,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
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
                      Center(
                        child: Text(
                          'No se encontraron pacientes.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPatients.length,
                    itemBuilder: (_, i) => _buildPatientClinicalCard(
                      Map<String, dynamic>.from(filteredPatients[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    const dayLabels = {1: 'Lun', 2: 'Mar', 3: 'Mié', 4: 'Jue', 5: 'Vie', 6: 'Sáb', 7: 'Dom'};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0369A1), Color(0xFF0D9488)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _doctorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_doctorEmail.isNotEmpty)
                      Text(
                        _doctorEmail,
                        style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 12.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Configuración de Agenda',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Duración por bloque',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [15, 30, 45, 60].map((m) {
                    return ChoiceChip(
                      label: Text(m == 60 ? '1 hora' : '$m min'),
                      selected: _slotInterval == m,
                      onSelected: (_) => _saveAgendaSettings(m, _workingDays),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Días que trabaja el doctor',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: dayLabels.entries.map((entry) {
                    final active = _workingDays.contains(entry.key);
                    return FilterChip(
                      label: Text(entry.value),
                      selected: active,
                      onSelected: (sel) {
                        final next = List<int>.from(_workingDays);
                        if (sel) {
                          if (!next.contains(entry.key)) next.add(entry.key);
                        } else if (next.length > 1) {
                          next.remove(entry.key);
                        }
                        _saveAgendaSettings(_slotInterval, next);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description_rounded, color: Color(0xFF0D9488), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Personalizar Récipe',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Orientación del récipe',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Vertical (Carta/A5)'),
                      selected: _recipeOrientation == 'vertical',
                      onSelected: (_) => setState(() => _recipeOrientation = 'vertical'),
                    ),
                    ChoiceChip(
                      label: const Text('Horizontal (Media hoja)'),
                      selected: _recipeOrientation == 'horizontal',
                      onSelected: (_) => setState(() => _recipeOrientation = 'horizontal'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recipeHeaderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Encabezado del consultorio',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipeFooterCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pie de página / Nota al representante',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar peso, talla y percentil OMS', style: TextStyle(fontSize: 13)),
                  value: _recipeShowOms,
                  onChanged: (v) => setState(() => _recipeShowOms = v),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: _saveRecipeSettings,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Guardar Récipe'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: Color(0xFF0284C7)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Versión de la App',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'v$kAppVersion (Build $kAppBuildNumber)',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _checkingUpdate ? null : _checkForUpdates,
                  icon: _checkingUpdate
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Buscar', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Color(0xFF0284C7)),
                title: const Text('Bloquear aplicación ahora'),
                onTap: widget.onLock,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFE11D48)),
                title: const Text(
                  'Cerrar sesión segura',
                  style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  await SecureSession.clearSession();
                  widget.onLock();
                },
              ),
            ],
          ),
        ),
      ],
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
      _buildDashboardTab(),
      _buildPatientsHistoryTab(filteredPatients),
      AgendaScreen(
        appointments: _appointments,
        patients: _patients,
        slotInterval: _slotInterval,
        workingDays: _workingDays,
        onRefresh: _refreshData,
        onStartConsultationFromApt: (apt) => _openConsultation(
          _findPatientForApt(apt),
          appointmentId: apt['Id']?.toString(),
        ),
      ),
      _buildSettingsTab(),
    ];

    const titles = [
      'MediCare · Clínica Pediátrica',
      'Historiales Clínicos',
      'Agenda Médica',
      'Configuración',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF5EEAD4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              titles[_tabIndex],
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared_outlined),
            selectedIcon: Icon(Icons.folder_shared_rounded),
            label: 'Historiales',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Config.',
          ),
        ],
      ),
    );
  }
}

class _ActionHeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionHeroButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: borderColor != null ? Border.all(color: borderColor!) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgTint;
  final VoidCallback onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgTint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
