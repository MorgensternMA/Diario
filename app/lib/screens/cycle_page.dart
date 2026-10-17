import 'package:flutter/material.dart';

import '../data/store.dart';
import '../common.dart';
import '../models.dart';
import 'day_page.dart';

typedef _CycleData = (CycleSummary, PeriodDay?);

/// Menstrual cycle overview: current status, predictions and history.
class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> with Loader<CyclePage, _CycleData> {
  @override
  Future<_CycleData> fetch() async {
    final (sum, day) = await (store.cycleSummary(), store.day(ymd(today()))).wait;
    return (sum, day.period);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi ciclo')),
      body: body((d) {
        final (sum, todayPeriod) = d;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _StatusCard(sum: sum),
            PeriodCard(key: ValueKey('cycle-${todayPeriod?.flow}'), date: ymd(today()), period: todayPeriod),
            if (sum.hasData) ...[
              SectionCard(
                title: 'Promedios',
                icon: Icons.insights,
                color: periodColor,
                child: Row(
                  children: [
                    _Stat(value: '${sum.avgCycle}', label: 'días de ciclo'),
                    _Stat(value: '${sum.avgPeriod}', label: 'días de período'),
                    _Stat(value: '${sum.cycles.length}', label: 'períodos registrados'),
                  ],
                ),
              ),
              SectionCard(
                title: 'Próximos',
                icon: Icons.upcoming,
                color: periodColor,
                child: Column(
                  children: [
                    for (final p in sum.predictions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.water_drop, color: periodColor),
                        title: Text('Período: ${shortDate(p.start)} – ${shortDate(p.end)}'),
                        subtitle: Text(
                          'Fértil: ${shortDate(p.fertileStart)} – ${shortDate(p.fertileEnd)} · '
                          'ovulación ~${shortDate(p.ovulation)}',
                        ),
                      ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Historial',
                icon: Icons.history,
                color: periodColor,
                child: Column(
                  children: [
                    for (final c in sum.cycles)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('${shortDate(c.start)} – ${shortDate(c.end)}'),
                        subtitle: Text('${c.periodLength} día${c.periodLength == 1 ? '' : 's'} de período'),
                        trailing: Text(c.cycleLength == 0 ? 'actual' : 'ciclo de ${c.cycleLength} días'),
                        onTap: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => DayPage(date: parseYmd(c.start)))),
                      ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Las predicciones son estimaciones según tu historial y no reemplazan un método anticonceptivo '
                'ni la consulta médica.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final CycleSummary sum;
  const _StatusCard({required this.sum});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String big;
    final String small;
    if (!sum.hasData) {
      big = 'Sin datos todavía';
      small = 'Registrá los días de tu período (abajo o desde el calendario) para ver predicciones.';
    } else if (sum.inPeriod) {
      big = 'Día ${sum.cycleDay} de tu período';
      small = 'Comenzó el ${shortDate(sum.lastStart)}';
    } else if (sum.daysUntilNext > 0) {
      big = sum.daysUntilNext == 1 ? 'Mañana podría venir' : 'Faltan ${sum.daysUntilNext} días';
      small = 'Próximo período estimado: ${shortDate(sum.nextStart)} · día ${sum.cycleDay} del ciclo';
    } else if (sum.daysUntilNext == 0) {
      big = 'Podría venir hoy';
      small = 'Día ${sum.cycleDay} del ciclo';
    } else {
      big = 'Atraso de ${-sum.daysUntilNext} día${sum.daysUntilNext == -1 ? '' : 's'}';
      small = 'Estimado para el ${shortDate(sum.nextStart)} · día ${sum.cycleDay} del ciclo';
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      color: periodColor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              big,
              style: theme.textTheme.headlineSmall?.copyWith(color: periodColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(small),
            if (sum.hasData && sum.avgCycle > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: (sum.cycleDay / sum.avgCycle).clamp(0.0, 1.0),
                  color: periodColor,
                  backgroundColor: periodColor.withValues(alpha: 0.15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
