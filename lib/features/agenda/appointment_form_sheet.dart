import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/security/secure_session.dart';
import '../../core/utils/pediatric_calculations.dart';
import '../patients/patient_form_screen.dart';

class AppointmentFormSheet extends StatefulWidget {
  final List<dynamic> patients;
  final List<dynamic> existingAppointments;
  final String? initialDate;
  final String? initialTime;
  final int slotIntervalMinutes;
  final List<int> workingDays;
  final VoidCallback onSaved;

  const AppointmentFormSheet({
    super.key,
    required this.patients,
    required this.existingAppointments,
    this.initialDate,
    this.initialTime,
    this.slotIntervalMinutes = 30,
    this.workingDays = const [1, 2, 3, 4, 5, 6],
    required this.onSaved,
  });

  @override
  State<AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<AppointmentFormSheet> {
  final _api = ApiClient();
  final _searchCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController(text: 'Control de niño sano y revisión pediátrica.');

  Map<String, dynamic>? _selectedPatient;
  late String _date;
  late String _time;
  late List<String> _slots;
  String _type = 'control';
  bool _sendWhatsappConfirm = true;
  bool _saving = false;

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _slots = generateTimeSlots(widget.slotIntervalMinutes);
    _date = widget.initialDate ?? _todayIso();
    if (widget.initialTime != null && !isSlotInPast(_date, widget.initialTime!)) {
      _time = widget.initialTime!;
    } else {
      _time = _slots.firstWhere((s) => !isSlotInPast(_date, s), orElse: () => _slots.first);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _whatsappCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_date) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year, now.month, now.day)) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      final nextDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _date = nextDate;
        if (isSlotInPast(_date, _time)) {
          _time = _slots.firstWhere((s) => !isSlotInPast(_date, s), orElse: () => _slots.first);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedPatient == null || isSlotInPast(_date, _time)) return;
    final requiresWa = isMoreThan24HoursAhead(_date, _time);
    final wa = _whatsappCtrl.text.trim();
    if (requiresWa && wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el WhatsApp para confirmar citas con más de 24h.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final doctorName = (await SecureSession.getDoctorName()) ?? 'Pediatra';
      final patName =
          '${_selectedPatient!['FirstName'] ?? ''} ${_selectedPatient!['LastName'] ?? ''}'.trim();

      await _api.createAppointment({
        'patientId': _selectedPatient!['Id'].toString(),
        'appointmentDate': _date,
        'appointmentTime': _time,
        'durationMinutes': widget.slotIntervalMinutes,
        'type': _type,
        'reason': _reasonCtrl.text.trim(),
        'stage': 'programado',
      });

      if (requiresWa && _sendWhatsappConfirm && wa.isNotEmpty) {
        final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
        final msg = Uri.encodeComponent(
          'Hola, le confirmamos la cita pediátrica de $patName con $doctorName para el día $_date a las $_time. Por favor confirmar asistencia.',
        );
        final uri = Uri.parse('https://wa.me/$digits?text=$msg');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agendar cita: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filteredPatients = (q.isEmpty
            ? widget.patients
            : widget.patients.where((p) {
                final m = Map<String, dynamic>.from(p);
                final text =
                    '${m['FirstName']} ${m['LastName']} ${m['HistoryNumber']} ${m['GuardianName']} ${m['GuardianWhatsapp']}'
                        .toLowerCase();
                return text.contains(q);
              }).toList())
        .take(6)
        .toList();

    final occupiedSlots = widget.existingAppointments
        .where((a) {
          final m = Map<String, dynamic>.from(a);
          final d = (m['AppointmentDate'] ?? m['Date'] ?? '').toString().split('T').first;
          return d == _date;
        })
        .map((a) => (Map<String, dynamic>.from(a)['AppointmentTime'] ?? '').toString())
        .toSet();

    final requiresWa = isMoreThan24HoursAhead(_date, _time);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Agendar Cita Pediátrica',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PatientFormScreen()),
                    );
                    if (result is Map && result['patient'] != null) {
                      final pat = Map<String, dynamic>.from(result['patient']);
                      setState(() {
                        _selectedPatient = pat;
                        _whatsappCtrl.text = (pat['GuardianWhatsapp'] ?? '').toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Nuevo Paciente'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedPatient != null)
              Card(
                color: const Color(0xFFF0F9FF),
                child: ListTile(
                  title: Text(
                    '${_selectedPatient!['FirstName']} ${_selectedPatient!['LastName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text('${_selectedPatient!['HistoryNumber']}'),
                  trailing: TextButton(
                    onPressed: () => setState(() => _selectedPatient = null),
                    child: const Text('Cambiar'),
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar paciente por nombre, N° historia o representante...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              ...filteredPatients.map((p) {
                final m = Map<String, dynamic>.from(p);
                return ListTile(
                  dense: true,
                  title: Text('${m['FirstName']} ${m['LastName']}'),
                  subtitle: Text('${m['HistoryNumber']} · Rep: ${m['GuardianName'] ?? ''}'),
                  onTap: () {
                    setState(() {
                      _selectedPatient = m;
                      _whatsappCtrl.text = (m['GuardianWhatsapp'] ?? '').toString();
                    });
                  },
                );
              }),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(_date),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'control', child: Text('Control Niño Sano')),
                      DropdownMenuItem(value: 'urgencia', child: Text('Urgencia')),
                      DropdownMenuItem(value: 'vacunacion', child: Text('Vacunación')),
                      DropdownMenuItem(value: 'primera_vez', child: Text('Primera Vez')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'control'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Horario disponible (cada ${widget.slotIntervalMinutes} min)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _slots.map((slot) {
                final isPast = isSlotInPast(_date, slot);
                final isOccupied = occupiedSlots.contains(slot);
                final isSelected = _time == slot && !isPast;
                return ChoiceChip(
                  label: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 11,
                      decoration: isPast ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: isPast ? null : (_) => setState(() => _time = slot),
                  backgroundColor: isOccupied ? const Color(0xFFFEF3C7) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: requiresWa
                    ? 'WhatsApp de confirmación * (>24h)'
                    : 'WhatsApp de contacto (opcional)',
                prefixIcon: const Icon(Icons.chat_outlined, color: Color(0xFF059669)),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (requiresWa)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendWhatsappConfirm,
                onChanged: (v) => setState(() => _sendWhatsappConfirm = v ?? true),
                title: const Text(
                  'Enviar confirmación por WhatsApp al guardar (>24h)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: (_saving || _selectedPatient == null || isSlotInPast(_date, _time))
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_saving ? 'Guardando...' : 'Guardar Cita'),
            ),
          ],
        ),
      ),
    );
  }
}
