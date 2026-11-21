import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/pediatric_calculations.dart';
import 'appointment_form_sheet.dart';

class AgendaScreen extends StatefulWidget {
  final List<dynamic> appointments;
  final List<dynamic> patients;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic> appointment) onStartConsultationFromApt;

  const AgendaScreen({
    super.key,
    required this.appointments,
    required this.patients,
    required this.onRefresh,
    required this.onStartConsultationFromApt,
  });

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _api = ApiClient();
  String _scope = 'calendario'; // calendario | proximas | historico
  int _slotInterval = 30;
  List<int> _workingDays = [1, 2, 3, 4, 5, 6];
  late String _selectedDate;

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayIso();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _slotInterval = prefs.getInt('medicare_agenda_interval') ?? 30;
      final savedDays = prefs.getStringList('medicare_agenda_days');
      if (savedDays != null && savedDays.isNotEmpty) {
        _workingDays = savedDays.map(int.parse).toList();
      }
    });
  }

  Future<void> _savePrefs(int interval, List<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('medicare_agenda_interval', interval);
    await prefs.setStringList('medicare_agenda_days', days.map((d) => '$d').toList());
    setState(() {
      _slotInterval = interval;
      _workingDays = days;
    });
  }

  void _openConfigSheet() {
    var tempInterval = _slotInterval;
    var tempDays = List<int>.from(_workingDays);
    const dayLabels = {1: 'Lun', 2: 'Mar', 3: 'Mié', 4: 'Jue', 5: 'Vie', 6: 'Sáb', 7: 'Dom'};

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configurar Calendario',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Duración por bloque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60].map((m) {
                  return ChoiceChip(
                    label: Text(m == 60 ? '1 hora' : '$m min'),
                    selected: tempInterval == m,
                    onSelected: (_) => setModalState(() => tempInterval = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text('Días que trabaja el doctor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: dayLabels.entries.map((entry) {
                  final active = tempDays.contains(entry.key);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: active,
                    onSelected: (sel) {
                      setModalState(() {
                        if (sel) {
                          tempDays.add(entry.key);
                        } else if (tempDays.length > 1) {
                          tempDays.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  _savePrefs(tempInterval, tempDays);
                  Navigator.pop(ctx);
                },
                child: const Text('Guardar Configuración'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScheduleSheet({String? prefillDate, String? prefillTime}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppointmentFormSheet(
        patients: widget.patients,
        existingAppointments: widget.appointments,
        initialDate: prefillDate ?? _selectedDate,
        initialTime: prefillTime,
        slotIntervalMinutes: _slotInterval,
        workingDays: _workingDays,
        onSaved: widget.onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayIso();
    final slots = generateTimeSlots(_slotInterval);

    final scopedAppointments = widget.appointments.where((raw) {
      final a = Map<String, dynamic>.from(raw);
      final d = (a['AppointmentDate'] ?? a['Date'] ?? '').toString().split('T').first;
      if (_scope == 'calendario') return d == _selectedDate;
      if (_scope == 'proximas') return d.compareTo(today) > 0;
      return d.compareTo(today) < 0;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'calendario', label: Text('Calendario', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'proximas', label: Text('Próximas', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'historico', label: Text('Histórico', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) => setState(() => _scope = s.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _openConfigSheet,
                icon: const Icon(Icons.tune, size: 18),
                tooltip: 'Configurar',
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: () => _openScheduleSheet(),
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Agendar Cita',
              ),
            ],
          ),
        ),
        if (_scope == 'calendario')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fecha: $_selectedDate',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(_selectedDate) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Cambiar fecha'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: _scope == 'calendario'
                ? ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: slots.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final slot = slots[idx];
                      final isPast = isSlotInPast(_selectedDate, slot);
                      final slotApts = scopedAppointments.where((raw) {
                        final a = Map<String, dynamic>.from(raw);
                        return (a['AppointmentTime'] ?? a['Time'] ?? '').toString() == slot;
                      }).toList();

                      if (slotApts.isEmpty) {
                        return ListTile(
                          dense: true,
                          leading: Text(
                            slot,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isPast ? Colors.grey : const Color(0xFF0284C7),
                            ),
                          ),
                          title: Text(
                            isPast ? 'Hora pasada' : '+ Agendar en $slot',
                            style: TextStyle(
                              fontSize: 12,
                              color: isPast ? Colors.grey : const Color(0xFF64748B),
                            ),
                          ),
                          onTap: isPast
                              ? null
                              : () => _openScheduleSheet(
                                    prefillDate: _selectedDate,
                                    prefillTime: slot,
                                  ),
                        );
                      }

                      return Column(
                        children: slotApts.map((raw) {
                          final a = Map<String, dynamic>.from(raw);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Text(slot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              title: Text(
                                (a['PatientName'] ?? 'Paciente').toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text('${a['Reason'] ?? ''} · ${a['Stage'] ?? ''}'),
                              trailing: FilledButton(
                                onPressed: () => widget.onStartConsultationFromApt(a),
                                child: const Text('Atender', style: TextStyle(fontSize: 11)),
                              ),
                              onLongPress: () async {
                                await _api.deleteAppointment(a['Id'].toString());
                                widget.onRefresh();
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: scopedAppointments.length,
                    itemBuilder: (_, i) {
                      final a = Map<String, dynamic>.from(scopedAppointments[i]);
                      final dateStr =
                          (a['AppointmentDate'] ?? a['Date'] ?? '').toString().split('T').first;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.event_note)),
                          title: Text((a['PatientName'] ?? 'Paciente').toString()),
                          subtitle: Text('$dateStr · ${a['AppointmentTime'] ?? a['Time']} · ${a['Reason'] ?? ''}'),
                          trailing: Chip(label: Text((a['Stage'] ?? '').toString())),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
