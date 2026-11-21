import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/pediatric_calculations.dart';
import 'appointment_form_sheet.dart';

class AgendaScreen extends StatefulWidget {
  final List<dynamic> appointments;
  final List<dynamic> patients;
  final int slotInterval;
  final List<int> workingDays;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic> appointment) onStartConsultationFromApt;

  const AgendaScreen({
    super.key,
    required this.appointments,
    required this.patients,
    this.slotInterval = 30,
    this.workingDays = const [1, 2, 3, 4, 5, 6],
    required this.onRefresh,
    required this.onStartConsultationFromApt,
  });

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _api = ApiClient();
  String _scope = 'calendario'; // calendario | proximas | historico
  late String _selectedDate;

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayIso();
  }

  void _openScheduleSheet({String? prefillDate, String? prefillTime}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        top: false,
        child: AppointmentFormSheet(
          patients: widget.patients,
          existingAppointments: widget.appointments,
          initialDate: prefillDate ?? _selectedDate,
          initialTime: prefillTime,
          slotIntervalMinutes: widget.slotInterval,
          workingDays: widget.workingDays,
          onSaved: widget.onRefresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayIso();
    final slots = generateTimeSlots(widget.slotInterval);

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
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'calendario',
                      label: Text('Calendario', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: 'proximas',
                      label: Text('Próximas', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: 'historico',
                      label: Text('Histórico', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) => setState(() => _scope = s.first),
                ),
              ),
              const SizedBox(width: 8),
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
