import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/config/specialties.dart';
import '../../core/network/api_client.dart';
import '../../core/security/secure_session.dart';
import '../consultation/consultation_screen.dart';

class Patient360Screen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final SpecialtyMeta activeSpecialty;

  const Patient360Screen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.activeSpecialty,
  });

  @override
  State<Patient360Screen> createState() => _Patient360ScreenState();
}

class _Patient360ScreenState extends State<Patient360Screen> {
  final _api = ApiClient();
  bool _loading = true;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _permissions = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getPatient360(
          widget.patientId,
          viewerSpecialtyId: widget.activeSpecialty.id,
        ),
        _api.listDiagnosisPermissions(patientId: widget.patientId).catchError((_) => <Map<String, dynamic>>[]),
        SecureSession.getUserId(),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>;
          _permissions = results[1] as List<Map<String, dynamic>>;
          _currentUserId = results[2] as String?;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestDiagnosisAccess(String consultationId, String? authorDoctorId) async {
    try {
      await _api.requestDiagnosisPermission(
        patientId: widget.patientId,
        consultationId: consultationId,
        authorDoctorUserId: authorDoctorId,
        reason: 'Solicitud desde app móvil para continuidad asistencial',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de permiso enviada al médico tratante.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo solicitar permiso: $e')),
        );
      }
    }
  }

  Future<void> _openReferralSheet() async {
    SpecialtyMeta target = kSpecialties.firstWhere((s) => s.id != widget.activeSpecialty.id);
    final reasonCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          top: false,
          child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Referir y Dar Permiso de Diagnóstico',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'El especialista podrá ver tus diagnósticos. Los exámenes realizados ya son visibles sin permiso.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<SpecialtyMeta>(
                value: target,
                items: kSpecialties
                    .where((s) => s.id != widget.activeSpecialty.id)
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => target = val);
                },
                decoration: const InputDecoration(
                  labelText: 'Especialista destino',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo de referencia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await _api.grantDiagnosisPermission(
                    patientId: widget.patientId,
                    grantedBySpecialtyId: widget.activeSpecialty.id,
                    targetSpecialtyId: target.id,
                    reason: reasonCtrl.text.trim().isEmpty
                        ? 'Referencia desde ${widget.activeSpecialty.name}'
                        : reasonCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                child: const Text('Otorgar Permiso'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consultations = (_data?['consultations'] as List<dynamic>?) ?? [];
    final studies = (_data?['studies'] as List<dynamic>?) ?? [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              onPressed: _openReferralSheet,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Referir y dar permiso de diagnóstico',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'Diagnósticos'),
              Tab(icon: Icon(Icons.science_outlined), text: 'Exámenes (Libre)'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: consultations.length,
                    itemBuilder: (_, i) {
                      final c = Map<String, dynamic>.from(consultations[i]);
                      final consId = (c['Id'] ?? c['id'] ?? '').toString();
                      final authorId = (c['DoctorUserId'] ?? c['doctorUserId'] ?? '').toString();
                      final doctorName = (c['DoctorName'] ?? c['doctorName'] ?? 'Médico').toString();
                      final hasAccess = c['hasDiagnosisAccess'] == true || c['HasDiagnosisAccess'] == true;
                      final isOwn = _currentUserId != null && _currentUserId == authorId;
                      final rxList = (c['Prescriptions'] ?? c['prescriptions'] ?? []) as List<dynamic>;
                      final patientGuide = (c['PatientGuide'] ?? c['patientGuide'] ?? '').toString();
                      List<String> alarmSigns = [];
                      try {
                        final rawAlarms = c['AlarmSignsJson'] ?? c['alarmSignsJson'] ?? '[]';
                        final decoded = rawAlarms is String ? jsonDecode(rawAlarms) : rawAlarms;
                        if (decoded is List) {
                          alarmSigns = decoded.map((e) => e.toString()).toList();
                        }
                      } catch (_) {}

                      final pendingForCons = _permissions
                          .where((p) =>
                              (p['status']?.toString() ?? '') == 'PENDING' &&
                              (p['consultationId'] == null || p['consultationId']?.toString() == consId))
                          .toList();
                      final myPending = pendingForCons.any(
                        (p) => _currentUserId != null && p['targetDoctorUserId']?.toString() == _currentUserId,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    hasAccess ? Icons.medical_information_outlined : Icons.lock_outline,
                                    color: hasAccess ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      hasAccess
                                          ? '${c['Cie10Code']} — ${c['Cie10Name']}'
                                          : 'Diagnóstico Protegido (${c['SpecialtyName'] ?? 'Pediatría'})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Médico: $doctorName',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              if (hasAccess) ...[
                                Text('${c['Reason'] ?? ''}', style: const TextStyle(fontSize: 12)),
                                if ((c['PhysicalExamSummary'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Examen físico: ${c['PhysicalExamSummary']}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                                if (patientGuide.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Guía y Cuidados: $patientGuide',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                                  ),
                                ],
                                if (alarmSigns.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Signos de Alarma: ${alarmSigns.join(' · ')}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFBE123C)),
                                  ),
                                ],
                              ] else ...[
                                const Text(
                                  'Anamnesis, examen físico, diagnóstico CIE-10, guía de cuidados y signos de alarma privados.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                ),
                                const SizedBox(height: 8),
                                if (myPending)
                                  const Chip(
                                    label: Text('Solicitud pendiente de aprobación', style: TextStyle(fontSize: 11)),
                                    backgroundColor: Color(0xFFFEF3C7),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () => _requestDiagnosisAccess(consId, authorId),
                                    icon: const Icon(Icons.lock_open_outlined, size: 16),
                                    label: const Text('Solicitar permiso de diagnóstico', style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                              if (rxList.isNotEmpty) ...[
                                const Divider(height: 16),
                                const Text(
                                  'Récipe / Tratamiento indicado:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                ...rxList.map((rx) {
                                  final m = Map<String, dynamic>.from(rx as Map);
                                  return Text(
                                    '• ${m['MedicationName'] ?? m['medicationName']} — ${m['DosePerTake'] ?? m['dosePerTake']} c/${m['FrequencyHours'] ?? m['frequencyHours']}h x ${m['DurationDays'] ?? m['durationDays']}d',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                  );
                                }),
                              ],
                              if (isOwn && pendingForCons.isNotEmpty) ...[
                                const Divider(height: 16),
                                const Text(
                                  'Solicitudes pendientes:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                ),
                                const SizedBox(height: 6),
                                ...pendingForCons.map((req) => Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${req['targetDoctorName'] ?? 'Médico'}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            await _api.approveDiagnosisPermission(req['id'].toString());
                                            await _load();
                                          },
                                          child: const Text('Aprobar'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            await _api.rejectDiagnosisPermission(req['id'].toString());
                                            await _load();
                                          },
                                          child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    )),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: studies.length,
                    itemBuilder: (_, i) {
                      final s = Map<String, dynamic>.from(studies[i]);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined, color: Color(0xFF059669)),
                          title: Text(s['Title']?.toString() ?? 'Estudio',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${s['Category']} · ${s['Summary'] ?? ''}'),
                        ),
                      );
                    },
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final vitalsHistory = (_data?['vitalsHistory'] as List<dynamic>?) ?? [];
            final prevVitals = vitalsHistory.isNotEmpty
                ? Map<String, dynamic>.from(vitalsHistory.first as Map)
                : null;
            final pat = _data?['patient'] != null
                ? Map<String, dynamic>.from(_data!['patient'])
                : <String, dynamic>{
                    'Id': widget.patientId,
                    'FirstName': widget.patientName,
                    'LastName': '',
                  };
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConsultationScreen(
                  patient: pat,
                  previousVitals: prevVitals,
                  onCompleted: _load,
                ),
              ),
            );
          },
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.medical_services_outlined),
          label: const Text('Iniciar Consulta'),
        ),
      ),
    );
  }
}

