import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/pediatric_calculations.dart';

class ConsultationScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final String? appointmentId;
  final VoidCallback onCompleted;

  const ConsultationScreen({
    super.key,
    required this.patient,
    this.appointmentId,
    required this.onCompleted,
  });

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _api = ApiClient();

  final _weightCtrl = TextEditingController(text: '12.0');
  final _heightCtrl = TextEditingController(text: '85.0');
  final _headCtrl = TextEditingController(text: '46.5');
  final _tempCtrl = TextEditingController(text: '36.8');
  final _hrCtrl = TextEditingController(text: '105');
  final _rrCtrl = TextEditingController(text: '24');
  final _spo2Ctrl = TextEditingController(text: '98');
  final _reasonCtrl = TextEditingController();
  final _examCtrl = TextEditingController();
  final _priorMedCtrl = TextEditingController();
  final _feedingCtrl = TextEditingController();
  final _neuroCtrl = TextEditingController();
  final _skinCtrl = TextEditingController();
  final _guideCtrl = TextEditingController();

  String _cie10Code = 'Z00.1';
  String _cie10Name = 'Control de salud de rutina del niño';
  bool _includeRecipe = false;
  final List<Map<String, String>> _prescriptions = [];
  bool _saving = false;

  // Preferencias de campos visibles por médico
  bool _showRr = true;
  bool _showHead = true;
  bool _showSpo2 = true;
  bool _showPriorMed = true;
  bool _showFeedingNeuro = false;
  bool _showSkin = false;

  String? _activeAppointmentId;

  @override
  void initState() {
    super.initState();
    _activeAppointmentId = widget.appointmentId;
    _loadFieldPrefs();
    _ensureWalkInAppointment();
  }

  Future<void> _loadFieldPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showRr = prefs.getBool('med_field_rr') ?? true;
      _showHead = prefs.getBool('med_field_head') ?? true;
      _showSpo2 = prefs.getBool('med_field_spo2') ?? true;
      _showPriorMed = prefs.getBool('med_field_prior_med') ?? true;
      _showFeedingNeuro = prefs.getBool('med_field_feeding') ?? false;
      _showSkin = prefs.getBool('med_field_skin') ?? false;
    });
  }

  Future<void> _saveFieldPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('med_field_rr', _showRr);
    await prefs.setBool('med_field_head', _showHead);
    await prefs.setBool('med_field_spo2', _showSpo2);
    await prefs.setBool('med_field_prior_med', _showPriorMed);
    await prefs.setBool('med_field_feeding', _showFeedingNeuro);
    await prefs.setBool('med_field_skin', _showSkin);
  }

  Future<void> _ensureWalkInAppointment() async {
    if (_activeAppointmentId != null && _activeAppointmentId!.isNotEmpty) {
      try {
        await _api.updateAppointmentStage(_activeAppointmentId!, 'en_consulta');
      } catch (_) {}
      return;
    }

    try {
      final now = DateTime.now();
      final todayIso =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final h12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final period = now.hour >= 12 ? 'PM' : 'AM';
      final timeLabel =
          '${h12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $period';

      final created = await _api.createAppointment({
        'patientId': widget.patient['Id'].toString(),
        'appointmentDate': todayIso,
        'appointmentTime': timeLabel,
        'durationMinutes': 30,
        'type': 'control',
        'reason': 'Consulta directa en consultorio (sin cita previa)',
        'stage': 'en_consulta',
      });
      if (mounted) {
        setState(() {
          _activeAppointmentId = (created['id'] ?? created['Id'])?.toString();
        });
      }
    } catch (_) {
      // Si falla offline, la consulta igual puede completarse
    }
  }

  void _openFieldCustomizer() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Personalizar Campos Visibles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Frecuencia Respiratoria (FR)'),
              value: _showRr,
              onChanged: (v) {
                setModalState(() => _showRr = v);
                setState(() => _showRr = v);
                _saveFieldPrefs();
              },
            ),
            SwitchListTile(
              title: const Text('Perímetro Cefálico (PC)'),
              value: _showHead,
              onChanged: (v) {
                setModalState(() => _showHead = v);
                setState(() => _showHead = v);
                _saveFieldPrefs();
              },
            ),
            SwitchListTile(
              title: const Text('Saturación SpO₂'),
              value: _showSpo2,
              onChanged: (v) {
                setModalState(() => _showSpo2 = v);
                setState(() => _showSpo2 = v);
                _saveFieldPrefs();
              },
            ),
            SwitchListTile(
              title: const Text('Medicación previa en casa'),
              value: _showPriorMed,
              onChanged: (v) {
                setModalState(() => _showPriorMed = v);
                setState(() => _showPriorMed = v);
                _saveFieldPrefs();
              },
            ),
            SwitchListTile(
              title: const Text('Alimentación y Neurodesarrollo'),
              value: _showFeedingNeuro,
              onChanged: (v) {
                setModalState(() => _showFeedingNeuro = v);
                setState(() => _showFeedingNeuro = v);
                _saveFieldPrefs();
              },
            ),
            SwitchListTile(
              title: const Text('Piel y Fontanela'),
              value: _showSkin,
              onChanged: (v) {
                setModalState(() => _showSkin = v);
                setState(() => _showSkin = v);
                _saveFieldPrefs();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addAcetaminophenByWeight() {
    final weight = double.tryParse(_weightCtrl.text) ?? 10.0;
    final mgPerTake = ((60 * weight) / 4).round();
    final mlPerTake = (mgPerTake / 24.0).toStringAsFixed(1);
    setState(() {
      _prescriptions.add({
        'medicationName': 'Acetaminofén / Paracetamol',
        'presentation': 'Jarabe 120 mg / 5 ml',
        'dosePerTake': '$mlPerTake ml ($mgPerTake mg)',
        'frequencyHours': '6',
        'durationDays': '3',
        'specialInstructions': 'Administrar en caso de fiebre > 38°C o dolor.',
      });
    });
  }

  Future<void> _finalizeConsultation() async {
    setState(() => _saving = true);
    try {
      final weight = double.tryParse(_weightCtrl.text) ?? 0;
      final height = double.tryParse(_heightCtrl.text) ?? 0;
      final head = double.tryParse(_headCtrl.text) ?? 0;
      final temp = double.tryParse(_tempCtrl.text) ?? 0;
      final hr = int.tryParse(_hrCtrl.text) ?? 0;
      final rr = int.tryParse(_rrCtrl.text) ?? 0;
      final spo2 = int.tryParse(_spo2Ctrl.text) ?? 0;

      final examExtras = <String>[
        if (_examCtrl.text.trim().isNotEmpty) _examCtrl.text.trim(),
        if (_skinCtrl.text.trim().isNotEmpty) 'Piel/Fontanela: ${_skinCtrl.text.trim()}',
        if (_priorMedCtrl.text.trim().isNotEmpty) 'Med. previa: ${_priorMedCtrl.text.trim()}',
        if (_feedingCtrl.text.trim().isNotEmpty) 'Alimentación: ${_feedingCtrl.text.trim()}',
        if (_neuroCtrl.text.trim().isNotEmpty) 'Neurodesarrollo: ${_neuroCtrl.text.trim()}',
      ].join(' | ');

      await _api.completeConsultation({
        'patientId': widget.patient['Id'].toString(),
        if (_activeAppointmentId != null) 'appointmentId': _activeAppointmentId,
        'specialtyId': 1,
        'cie10Code': _cie10Code,
        'cie10Name': _cie10Name,
        'reason': _reasonCtrl.text.trim().isEmpty
            ? 'Control pediátrico integral'
            : _reasonCtrl.text.trim(),
        'physicalExamSummary': examExtras,
        'parentGuide': _guideCtrl.text.trim(),
        'alarmSigns': <String>[],
        'prescriptions': _includeRecipe ? _prescriptions : <Map<String, String>>[],
        'vitals': {
          'weightKg': weight,
          'heightCm': height,
          'headCircumferenceCm': head,
          'temperatureC': temp,
          'heartRateBpm': hr,
          'respiratoryRateRpm': rr,
          'spo2Percent': spo2,
          'systolicBp': 0,
          'diastolicBp': 0,
        },
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta guardada y cita completada en historial.')),
      );
      widget.onCompleted();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar consulta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _headCtrl.dispose();
    _tempCtrl.dispose();
    _hrCtrl.dispose();
    _rrCtrl.dispose();
    _spo2Ctrl.dispose();
    _reasonCtrl.dispose();
    _examCtrl.dispose();
    _priorMedCtrl.dispose();
    _feedingCtrl.dispose();
    _neuroCtrl.dispose();
    _skinCtrl.dispose();
    _guideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patName = '${widget.patient['FirstName'] ?? ''} ${widget.patient['LastName'] ?? ''}'.trim();
    final birthDate = (widget.patient['BirthDate'] ?? '').toString();
    final sex = (widget.patient['Sex'] ?? 'M').toString();
    final ageMonths = calculateAgeInMonths(birthDate);

    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text) ?? 0;
    final head = double.tryParse(_headCtrl.text);
    final oms = evaluateOmsStatus(
      weightKg: weight,
      heightCm: height,
      ageMonths: ageMonths,
      sex: sex,
      headCircumferenceCm: head,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Consulta · $patName', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: _openFieldCustomizer,
            icon: const Icon(Icons.tune),
            tooltip: 'Elegir campos visibles',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Antropometría y Signos Vitales',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Chip(label: Text('IMC ${oms.bmi}')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Peso (kg)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _heightCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Talla (cm)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _tempCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Temp (°C)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hrCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'FC (lpm)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_showRr) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _rrCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'FR (rpm)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                      if (_showSpo2) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _spo2Ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'SpO₂ (%)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                      if (_showHead) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _headCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'PC (cm)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'OMS ($ageMonths m): ${oms.statusLabel} · Peso ${oms.weightPercentile} · Talla ${oms.heightPercentile}${oms.headStatusLabel != null ? ' · ${oms.headStatusLabel}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_showPriorMed || _showFeedingNeuro || _showSkin)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    if (_showPriorMed)
                      TextField(
                        controller: _priorMedCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Medicación previa en casa',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    if (_showSkin) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _skinCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Piel y Fontanela',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    if (_showFeedingNeuro) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _feedingCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Alimentación / Nutrición actual',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _neuroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hitos de Neurodesarrollo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de Consulta / Síntomas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _examCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Examen Físico',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _cie10Code,
                    decoration: const InputDecoration(
                      labelText: 'Diagnóstico CIE-10',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Z00.1', child: Text('Z00.1 — Control Niño Sano')),
                      DropdownMenuItem(value: 'J00', child: Text('J00 — Rinofaringitis Aguda')),
                      DropdownMenuItem(value: 'J03.9', child: Text('J03.9 — Faringoamigdalitis')),
                      DropdownMenuItem(value: 'A09', child: Text('A09 — Gastroenteritis')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _cie10Code = v ?? 'Z00.1';
                        _cie10Name = v == 'J00'
                            ? 'Rinofaringitis Aguda'
                            : v == 'J03.9'
                                ? 'Faringoamigdalitis'
                                : v == 'A09'
                                    ? 'Gastroenteritis'
                                    : 'Control de salud de rutina del niño';
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    '¿Requiere récipe en esta consulta?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text('Actívalo solo si necesitas prescribir medicamentos'),
                  value: _includeRecipe,
                  onChanged: (v) => setState(() => _includeRecipe = v),
                ),
                if (_includeRecipe) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _addAcetaminophenByWeight,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Calcular y Agregar Acetaminofén por Peso'),
                        ),
                        const SizedBox(height: 8),
                        ..._prescriptions.map(
                          (rx) => ListTile(
                            dense: true,
                            title: Text(rx['medicationName'] ?? ''),
                            subtitle: Text('${rx['dosePerTake']} · c/${rx['frequencyHours']}h · ${rx['durationDays']}d'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _finalizeConsultation,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Guardando...' : 'Finalizar Consulta'),
          ),
        ],
      ),
    );
  }
}
