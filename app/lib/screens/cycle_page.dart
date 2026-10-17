import 'package:flutter/material.dart';

import '../common.dart';
import '../data/insights.dart';
import '../data/store.dart';
import '../models.dart';
import '../theme.dart';
import 'day_page.dart';
import 'forecast_chart.dart';
import 'period_editor.dart';

typedef _CycleData = (CycleSummary, PeriodDay?, CycleInsights);

/// Cycle overview: status, what past cycles taught, the coming days,
/// predictions and history.
class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> with Loader<CyclePage, _CycleData> {
  @override
  Future<_CycleData> fetch() async {
    final (sum, day, insights) = await (store.cycleSummary(), store.day(ymd(today())), store.cycleInsights()).wait;
    return (sum, day.period, insights);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ciclo')),
      body: body((d) {
        final (sum, todayPeriod, insights) = d;
        final muted = Tokens.of(context).muted;
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _StatusCard(sum: sum),
            SectionCard(
              title: 'Cómo vas a estar',
              subtitle: 'Próximas 5 semanas, según tus ciclos',
              icon: Icons.show_chart_rounded,
              color: Palette.agenda,
              child: insights.hasCurves
                  ? ForecastChart(insights: insights, cycle: sum)
                  : _ChartPending(insights: insights, hasPeriods: sum.hasData),
            ),
            SectionCard(
              title: 'Hoy',
              icon: Icons.water_drop_rounded,
              color: periodColor,
              child: PeriodEditor(key: ValueKey('cycle-${todayPeriod?.flow}'), date: ymd(today()), period: todayPeriod),
            ),
            _LearnedCard(insights: insights, hasPeriods: sum.hasData),
            if (insights.patterns.isNotEmpty) _ComingCard(insights: insights),
            if (sum.hasData) ...[
              SectionCard(
                title: 'Próximos períodos',
                icon: Icons.upcoming_rounded,
                color: Palette.cycle,
                child: Column(
                  children: [
                    for (final p in sum.predictions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${shortDate(p.start)} – ${shortDate(p.end)}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              'fértil ${shortDate(p.fertileStart)} – ${shortDate(p.fertileEnd)}',
                              style: TextStyle(color: muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Historial',
                subtitle: 'Ciclo promedio de ${sum.avgCycle} días · período de ${sum.avgPeriod}',
                icon: Icons.history_rounded,
                color: Palette.cycle,
                child: Column(
                  children: [
                    for (final c in sum.cycles)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => DayPage(date: parseYmd(c.start)))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${shortDate(c.start)} – ${shortDate(c.end)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                c.cycleLength == 0 ? 'actual' : '${c.cycleLength} días',
                                style: TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Text(
                'Las predicciones son estimaciones según tu historial y no reemplazan un método anticonceptivo '
                'ni la consulta médica.',
                style: TextStyle(color: muted, fontSize: 12.5),
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
    final small = !sum.hasData
        ? 'Registrá los días de tu período para empezar.'
        : sum.inPeriod
        ? 'Comenzó el ${shortDate(sum.lastStart)}'
        : 'Próximo período estimado: ${shortDate(sum.nextStart)}';
    return SoftCard(
      color: Palette.cycle.withValues(alpha: 0.14),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cycleStatus(sum), style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(small),
          if (sum.hasData) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: (sum.cycleDay / sum.avgCycle).clamp(0.0, 1.0),
                color: periodColor,
                backgroundColor: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            Text('Día ${sum.cycleDay} de ~${sum.avgCycle}', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Recurring patterns found across past cycles.
class _LearnedCard extends StatelessWidget {
  final CycleInsights insights;
  final bool hasPeriods;
  const _LearnedCard({required this.insights, required this.hasPeriods});

  @override
  Widget build(BuildContext context) {
    final muted = Tokens.of(context).muted;
    final Widget child;
    if (insights.patterns.isEmpty) {
      final progress = hasPeriods
          ? '\n\nHasta ahora: ${insights.daysLogged} días registrados en ${insights.cyclesWithData} '
                'ciclo${insights.cyclesWithData == 1 ? '' : 's'}.'
          : '';
      child = Text(
        'Anotá cada día en "Hoy" tu energía, ganas, hambre y los remedios que tomes. '
        'Cuando algo se repita en al menos 2 ciclos va a aparecer acá, y vas a ver un aviso en "Hoy" '
        'antes de esos días. Es un cálculo con tus propios registros, hecho en el celular: '
        'cuantos más ciclos anotes, más preciso.$progress',
        style: TextStyle(color: muted, height: 1.4),
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in insights.patterns)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      p.days[0].toUpperCase() + p.days.substring(1),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(child: Text(p.medicine != null ? 'solés tomar ${p.label}' : p.label)),
                  Text('${p.cycles} ciclos', style: TextStyle(color: muted, fontSize: 12.5)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Calculado en el celular con ${insights.daysLogged} días de ${insights.cyclesWithData} ciclos. '
            'Se afina con cada ciclo.',
            style: TextStyle(color: muted, fontSize: 12.5),
          ),
        ],
      );
    }
    return SectionCard(
      title: 'Tus patrones',
      subtitle: 'Lo que se repite en tus ciclos',
      icon: Icons.insights_rounded,
      color: Palette.agenda,
      child: child,
    );
  }
}

/// The next weeks, grouped into runs of days with the same forecast.
class _ComingCard extends StatelessWidget {
  final CycleInsights insights;
  const _ComingCard({required this.insights});

  String _describe(DayForecast f) =>
      joinEs([for (final sig in f.signals) sig.label, for (final med in f.medicines) 'quizás $med']);

  @override
  Widget build(BuildContext context) {
    final runs = <(String, String, String)>[]; // from, to, text
    for (final f in insights.upcoming) {
      if (f.isEmpty) continue;
      final text = _describe(f);
      final prev = runs.isEmpty ? null : runs.last;
      final contiguous = prev != null && parseYmd(f.date).difference(parseYmd(prev.$2)).inDays == 1;
      if (contiguous && prev.$3 == text) {
        runs[runs.length - 1] = (prev.$1, f.date, text);
      } else {
        runs.add((f.date, f.date, text));
      }
    }
    if (runs.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Lo que viene',
      subtitle: 'Próximas 5 semanas',
      icon: Icons.wb_twilight_rounded,
      color: Palette.food,
      child: Column(
        children: [
          for (final r in runs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      r.$1 == r.$2 ? relativeShort(r.$1) : '${relativeShort(r.$1)} – ${shortDate(r.$2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(child: Text(r.$3)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Hoy", "Mañana" or "16 oct".
String relativeShort(String date) {
  final d = parseYmd(date).difference(today()).inDays;
  return d == 0 ? 'Hoy' : (d == 1 ? 'Mañana' : shortDate(date));
}

/// Shown until there's enough history to draw the forecast.
class _ChartPending extends StatelessWidget {
  final CycleInsights insights;
  final bool hasPeriods;
  const _ChartPending({required this.insights, required this.hasPeriods});

  @override
  Widget build(BuildContext context) {
    final muted = Tokens.of(context).muted;
    final cycles = insights.cyclesWithData.clamp(0, 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acá vas a ver un gráfico con tus picos y bajones de energía, ganas, ánimo y hambre para las '
          'próximas semanas. Para dibujarlo necesito al menos 2 ciclos con registros: anotá tu período y, '
          'cada día en "Hoy", cómo estás de energía, ganas y hambre.',
          style: TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < cycles ? Palette.agenda : Tokens.of(context).line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (i == 0) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hasPeriods
              ? '${insights.cyclesWithData} de 2 ciclos · ${insights.daysLogged} días registrados'
              : 'Empezá registrando tu período',
          style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
