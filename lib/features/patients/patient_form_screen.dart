import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/pediatric_calculations.dart';

class PatientFormScreen extends StatefulWidget {
  final bool compact;
  final Map<String, dynamic>? initialPatient;
  final void Function(Map<String, dynamic> createdPatient, bool startConsultation)? onCreated;

  const PatientFormScreen({
    super.key,
    this.compact = false,
    this.initialPatient,
    this.onCreated,
  });

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _guardianNameCtrl = TextEditingController();
  final _guardianDocCtrl = TextEditingController();
  final _guardianWhatsappCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();

  String _sex = 'M';
  String _birthDate = '2024-03-15';
  String _bloodType = 'O+';
  String _guardianRelation = 'Madre';
  int _gestationalWeeks = 39;
  double _birthWeightKg = 3.2;
  bool _saving = false;

  bool get _isEditing => widget.initialPatient != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPatient;
    if (p != null) {
      _firstNameCtrl.text = (p['FirstName'] ?? '').toString();
      _lastNameCtrl.text = (p['LastName'] ?? '').toString();
      _guardianNameCtrl.text = (p['GuardianName'] ?? '').toString();
      _guardianDocCtrl.text = (p['GuardianIdDocument'] ?? p['IdDocument'] ?? '').toString();
      _guardianWhatsappCtrl.text = (p['GuardianWhatsapp'] ?? '').toString();
      _allergiesCtrl.text = (p['Allergies'] ?? '').toString();
      final rawSex = (p['Sex'] ?? 'M').toString().toUpperCase();
      if (rawSex == 'M' || rawSex == 'F') _sex = rawSex;
      final rawBirth = (p['BirthDate'] ?? '').toString().split('T').first;
      if (rawBirth.length >= 10) _birthDate = rawBirth;
      final rawBlood = (p['BloodType'] ?? '').toString();
      if (rawBlood.isNotEmpty) _bloodType = rawBlood;
      final rawRel = (p['GuardianRelation'] ?? '').toString();
      if (['Madre', 'Padre', 'Representante Legal'].contains(rawRel)) {
        _guardianRelation = rawRel;
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _guardianNameCtrl.dispose();
    _guardianDocCtrl.dispose();
    _guardianWhatsappCtrl.dispose();
    _allergiesCtrl.dispose();
    _chronicCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final initial = DateTime.tryParse(_birthDate) ?? DateTime(2024, 3, 15);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2005),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit(bool startConsultation) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final first = _firstNameCtrl.text.trim();
      final last = _lastNameCtrl.text.trim().isEmpty ? 'Paciente' : _lastNameCtrl.text.trim();
      final payload = {
        'firstName': first,
        'lastName': last,
        'sex': _sex,
        'birthDate': _birthDate,
        'idDocument': _guardianDocCtrl.text.trim().isEmpty ? null : _guardianDocCtrl.text.trim(),
        'bloodType': _bloodType,
        'primarySpecialtyId': 1,
        'criticalAllergies':
            _allergiesCtrl.text.trim().isEmpty ? <String>[] : [_allergiesCtrl.text.trim()],
        'chronicConditions':
            _chronicCtrl.text.trim().isEmpty ? <String>[] : [_chronicCtrl.text.trim()],
        'previousHospitalizations': 'Sin hospitalizaciones previas',
        'guardianName': _guardianNameCtrl.text.trim().isEmpty
            ? '$first $last'
            : _guardianNameCtrl.text.trim(),
        'guardianRelation': _guardianRelation,
        'guardianIdDocument': _guardianDocCtrl.text.trim(),
        'guardianOccupation': '',
        'guardianWhatsapp': _guardianWhatsappCtrl.text.trim(),
        'guardianEmail': '',
        'specialtyData': {
          'gestationalWeeks': _gestationalWeeks,
          'birthWeightKg': _birthWeightKg,
        },
      };

      final res = _isEditing
          ? await _api.updatePatient(widget.initialPatient!['Id'].toString(), payload)
          : await _api.createPatient(payload);
      final created = <String, dynamic>{
        'Id': res['id'] ?? res['Id'] ?? widget.initialPatient?['Id'] ?? 'pat-${DateTime.now().millisecondsSinceEpoch}',
        'HistoryNumber': res['historyNumber'] ?? res['HistoryNumber'] ?? widget.initialPatient?['HistoryNumber'] ?? 'HC-NUEVO',
        'FirstName': first,
        'LastName': last,
        'Sex': _sex,
        'BirthDate': _birthDate,
        'PrimarySpecialtyName': 'Pediatría',
        'GuardianName': payload['guardianName'],
        'GuardianWhatsapp': payload['guardianWhatsapp'],
      };

      if (!mounted) return;
      if (widget.onCreated != null) {
        widget.onCreated!(created, startConsultation);
      } else {
        Navigator.pop(context, {'patient': created, 'startConsultation': _isEditing ? false : startConsultation});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar paciente: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formBody = Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: widget.compact,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Datos Esenciales del Paciente',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(
                  calculateExactAgeLabel(_birthDate),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _firstNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombres *',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Apellidos *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (!widget.compact && (v == null || v.trim().isEmpty)) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickBirthDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha Nacimiento',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_birthDate),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: const InputDecoration(
                    labelText: 'Sexo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Masculino')),
                    DropdownMenuItem(value: 'F', child: Text('Femenino')),
                  ],
                  onChanged: (v) => setState(() => _sex = v ?? 'M'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _guardianNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Representante *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (!widget.compact && (v == null || v.trim().isEmpty)) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _guardianDocCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cédula / Doc.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _guardianRelation,
                  decoration: const InputDecoration(
                    labelText: 'Parentesco',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Madre', child: Text('Madre')),
                    DropdownMenuItem(value: 'Padre', child: Text('Padre')),
                    DropdownMenuItem(value: 'Representante Legal', child: Text('Representante')),
                  ],
                  onChanged: (v) => setState(() => _guardianRelation = v ?? 'Madre'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _guardianWhatsappCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Representante',
              hintText: '+584141234567',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.chat_outlined),
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text(
              'Datos opcionales (Alergias, Sangre, Perinatales)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            childrenPadding: const EdgeInsets.only(top: 8, bottom: 12),
            children: [
              DropdownButtonFormField<String>(
                value: _bloodType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Sangre',
                  border: OutlineInputBorder(),
                ),
                items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']
                    .map((bt) => DropdownMenuItem(value: bt, child: Text(bt)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodType = v ?? 'O+'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _allergiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alergias Críticas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _chronicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Condiciones Crónicas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_gestationalWeeks',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sem. Gestación',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _gestationalWeeks = int.tryParse(v) ?? 39,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_birthWeightKg',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Peso Nacer (kg)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _birthWeightKg = double.tryParse(v) ?? 3.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!widget.compact && !_isEditing) ...[
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _submit(false),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Guardar y Ver Historial'),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: _saving ? null : () => _submit(!_isEditing),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(_isEditing ? Icons.save_rounded : Icons.medical_services_outlined),
            label: Text(
              _saving
                  ? 'Guardando...'
                  : _isEditing
                      ? 'Guardar Cambios'
                      : 'Guardar e Iniciar Consulta',
            ),
          ),
        ],
      ),
    );

    if (widget.compact) return formBody;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar Paciente' : 'Nuevo Paciente Pediátrico')),
      body: formBody,
    );
  }
}
