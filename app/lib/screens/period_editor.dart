import 'package:flutter/material.dart';

import '../common.dart';
import '../data/store.dart';
import '../models.dart';

/// One-line description of where the cycle stands.
String cycleStatus(CycleSummary s, {bool short = false}) {
  if (!s.hasData) return short ? 'Registrá tu período para ver predicciones' : 'Sin datos todavía';
  if (s.inPeriod) return 'Día ${s.cycleDay} de tu período';
  final n = s.daysUntilNext;
  final day = 'Día ${s.cycleDay}';
  if (n > 1) return '$day · próximo período en $n días';
  if (n == 1) return '$day · podría venir mañana';
  if (n == 0) return '$day · podría venir hoy';
  return 'Atraso de ${-n} día${n == -1 ? '' : 's'}';
}

/// Flow and symptoms for a day; saves on every change.
class PeriodEditor extends StatefulWidget {
  final String date;
  final PeriodDay? period;

  /// Shows only the chosen symptoms until expanded, to keep "Hoy" short.
  final bool compact;
  const PeriodEditor({super.key, required this.date, this.period, this.compact = false});

  @override
  State<PeriodEditor> createState() => _PeriodEditorState();
}

class _PeriodEditorState extends State<PeriodEditor> {
  late int _flow = widget.period?.flow ?? 0;
  late List<String> _symptoms = [...?widget.period?.symptoms];

  Future<void> _save() => attempt(context, () async {
    if (_flow == 0) {
      await store.deletePeriod(widget.date);
    } else {
      await store.savePeriod(
        PeriodDay(date: widget.date, flow: _flow, symptoms: _symptoms, note: widget.period?.note ?? ''),
      );
    }
  });

  late bool _showAllSymptoms = !widget.compact;

  Widget _layout(List<Widget> chips) => Wrap(spacing: 6, runSpacing: 6, children: chips);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _layout([
          for (var f = 0; f < flowLabel.length; f++)
            ChoiceChip(
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // One outlined drop for spotting, then 1-3 filled drops.
                  for (var i = 0; i < (f <= 1 ? f : f - 1); i++)
                    Icon(f == 1 ? Icons.water_drop_outlined : Icons.water_drop_rounded, size: 13, color: periodColor),
                  if (f > 0) const SizedBox(width: 4),
                  Text(flowLabel[f]),
                ],
              ),
              selected: _flow == f,
              selectedColor: periodColor.withValues(alpha: 0.22),
              onSelected: (_) {
                setState(() => _flow = f);
                _save();
              },
            ),
        ]),
        if (_flow > 0) ...[
          const SizedBox(height: 14),
          Text('Síntomas', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (_showAllSymptoms)
            TagPicker(
              options: symptomOptions,
              selected: _symptoms,
              color: periodColor,
              onChanged: (v) {
                setState(() => _symptoms = v);
                _save();
              },
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final sym in _symptoms)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: periodColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(sym, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ActionChip(
                  avatar: Icon(_symptoms.isEmpty ? Icons.add_rounded : Icons.edit_rounded, size: 16),
                  label: Text(_symptoms.isEmpty ? 'Agregar' : 'Editar'),
                  onPressed: () => setState(() => _showAllSymptoms = true),
                ),
              ],
            ),
        ],
      ],
    );
  }
}
