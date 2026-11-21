import 'package:flutter/material.dart';
import '../../core/config/specialties.dart';
import '../../core/network/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getPatient360(
        widget.patientId,
        viewerSpecialtyId: widget.activeSpecialty.id,
      );
      if (mounted) setState(() => _data = res);
    } finally {
      if (mounted) setState(() => _loading = false);
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
                      final hasAccess = c['hasDiagnosisAccess'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            hasAccess ? Icons.medical_information_outlined : Icons.lock_outline,
                            color: hasAccess ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                          ),
                          title: Text(
                            hasAccess
                                ? '${c['Cie10Code']} — ${c['Cie10Name']}'
                                : 'Diagnóstico Protegido (${c['SpecialtyName']})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            hasAccess
                                ? '${c['DoctorName']} · ${c['Reason']}'
                                : 'Requiere permiso del médico remitente. Revisa la pestaña Exámenes.',
                            style: const TextStyle(fontSize: 12),
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

