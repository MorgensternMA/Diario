import 'package:flutter/material.dart';

import '../common.dart';
import '../data/store.dart';
import '../models.dart';
import '../theme.dart';

String _now() {
  final t = TimeOfDay.now();
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Medicines taken on a day.
class MedsCard extends StatelessWidget {
  final String date;
  final List<MedEntry> meds;
  const MedsCard({super.key, required this.date, required this.meds});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Remedios',
      icon: Icons.medication_rounded,
      color: Palette.cycle,
      trailing: IconButton(
        tooltip: 'Anotar remedio',
        onPressed: () => showMedSheet(context, date: date),
        icon: const Icon(Icons.add_rounded),
      ),
      child: meds.isEmpty
          ? const EmptyHint('Si tomás algo, anotalo: ayuda a entender tus ciclos.')
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in meds)
                  InputChip(
                    avatar: const Icon(Icons.medication_rounded, size: 16, color: Palette.cycle),
                    label: Text([m.name, if (m.dose.isNotEmpty) m.dose, if (m.time.isNotEmpty) m.time].join(' · ')),
                    onPressed: () => showMedSheet(context, date: date, med: m),
                    onDeleted: () => attempt(context, () => store.deleteMed(m.id)),
                  ),
              ],
            ),
    );
  }
}

Future<void> showMedSheet(BuildContext context, {required String date, MedEntry? med}) async {
  final frequent = await store.frequentMeds();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MedSheet(date: date, med: med, frequent: frequent),
  );
}

class _MedSheet extends StatefulWidget {
  final String date;
  final MedEntry? med;
  final List<MedEntry> frequent;
  const _MedSheet({required this.date, this.med, required this.frequent});

  @override
  State<_MedSheet> createState() => _MedSheetState();
}

class _MedSheetState extends State<_MedSheet> {
  late final _name = TextEditingController(text: widget.med?.name);
  late final _dose = TextEditingController(text: widget.med?.dose);
  late String _time = widget.med?.time ?? _now();

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: _time.isEmpty ? TimeOfDay.now() : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (t != null) {
      setState(() => _time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    final ok = await attempt(
      context,
      () => store.saveMed(
        MedEntry(id: widget.med?.id ?? 0, date: widget.date, name: _name.text, dose: _dose.text, time: _time),
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.med == null ? 'Anotar remedio' : 'Editar remedio',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            if (widget.med == null && widget.frequent.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in widget.frequent)
                    ActionChip(
                      label: Text(f.dose.isEmpty ? f.name : '${f.name} · ${f.dose}'),
                      onPressed: () => setState(() {
                        _name.text = f.name;
                        _dose.text = f.dose;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _name,
              autofocus: widget.med == null && widget.frequent.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Nombre (ej: Ibuprofeno)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dose,
                    decoration: const InputDecoration(hintText: 'Dosis (ej: 400 mg)'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(_time.isEmpty ? 'Hora' : _time),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Guardar')),
            ),
          ],
        ),
      ),
    );
  }
}
