import 'package:flutter/material.dart';

import '../common.dart';
import '../data/cycles.dart';
import '../data/insights.dart';
import '../models.dart';
import '../theme.dart';

/// Series colors, validated for color-vision deficiency and contrast against
/// the card surface in each mode (amber, violet, rose, blue in this order).
Color metricColor(BuildContext context, Metric m) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (m) {
    Metric.energy => dark ? const Color(0xFFC2802E) : const Color(0xFFC98128),
    Metric.motivation => dark ? const Color(0xFF8C7BD6) : const Color(0xFF7C69C7),
    Metric.mood => dark ? const Color(0xFFD9628A) : const Color(0xFFCF4F78),
    Metric.hunger => dark ? const Color(0xFF478FD6) : const Color(0xFF2F7FC8),
  };
}

/// One x position of a [LevelChart].
class ChartDay {
  final String date;
  final Map<Metric, double> values;

  /// Values come from the forecast rather than from what was logged.
  final bool projected;
  final bool period;
  const ChartDay(this.date, this.values, {this.projected = false, this.period = false});
}

const _labelWidth = 74.0;
const _rowHeight = 56.0;

/// Energy, motivation, mood and hunger over a run of days: one small line
/// chart per metric sharing the same date axis. Tap or drag to read a day.
class LevelChart extends StatefulWidget {
  final List<ChartDay> days;
  final Map<Metric, double> baseline;

  /// Indices of the days that get an axis label, with their text.
  final Map<int, String> ticks;

  /// Selected day. When [onSelect] is set the parent owns the selection.
  final int selected;
  final ValueChanged<int>? onSelect;
  final String Function(ChartDay day) title;

  const LevelChart({
    super.key,
    required this.days,
    required this.baseline,
    required this.ticks,
    required this.title,
    this.selected = 0,
    this.onSelect,
  });

  @override
  State<LevelChart> createState() => _LevelChartState();
}

class _LevelChartState extends State<LevelChart> {
  late int _own = widget.selected;

  int get _sel => (widget.onSelect != null ? widget.selected : _own).clamp(0, widget.days.length - 1);

  void _select(double dx, double width) {
    final n = widget.days.length;
    if (n < 2) return;
    final i = ((dx / width) * (n - 1)).round().clamp(0, n - 1);
    if (i == _sel) return;
    if (widget.onSelect != null) {
      widget.onSelect!(i);
    } else {
      setState(() => _own = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final theme = Theme.of(context);
    final days = widget.days;
    final metrics = [
      for (final m in Metric.values)
        if (days.any((d) => d.values.containsKey(m))) m,
    ];
    final sel = days[_sel];
    final hasProjection = days.any((d) => d.projected && d.values.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title(sel), style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            final plotWidth = box.maxWidth - _labelWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) => _select(e.localPosition.dx - _labelWidth, plotWidth),
              onHorizontalDragUpdate: (e) => _select(e.localPosition.dx - _labelWidth, plotWidth),
              child: Column(
                children: [
                  for (final m in metrics)
                    SizedBox(
                      height: _rowHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Line key: identity never rides on text color.
                                    Container(width: 10, height: 2.5, color: metricColor(context, m)),
                                    const SizedBox(width: 6),
                                    Text(m.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                Text(
                                  _valueText(sel.values[m], widget.baseline[m], sel.projected),
                                  style: TextStyle(fontSize: 12, color: t.muted, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _SeriesPainter(
                                values: [for (final d in days) d.values[m]],
                                projected: [for (final d in days) d.projected],
                                baseline: widget.baseline[m],
                                color: metricColor(context, m),
                                selected: _sel,
                                periodMask: [for (final d in days) d.period],
                                surface: t.card,
                                grid: t.line,
                                ink: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  _xAxis(context, plotWidth),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _legend(
              context,
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: periodColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              'Período',
            ),
            _legend(context, Container(width: 14, height: 1, color: t.muted), 'Tu promedio'),
            if (hasProjection && days.any((d) => !d.projected && d.values.isNotEmpty)) ...[
              _legend(context, Container(width: 14, height: 2, color: t.muted), 'Anotado'),
              _legend(context, Container(width: 14, height: 2, color: t.muted.withValues(alpha: 0.4)), 'Proyección'),
            ],
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Widget swatch, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      swatch,
      const SizedBox(width: 6),
      Text(text, style: TextStyle(fontSize: 11.5, color: Tokens.of(context).muted)),
    ],
  );

  /// "3.8 ↑" relative to the personal average; "~" marks a projection.
  String _valueText(double? v, double? base, bool projected) {
    if (v == null) return '—';
    final arrow = base == null || (v - base).abs() < 0.3 ? '' : (v > base ? ' ↑' : ' ↓');
    return '${projected ? '~' : ''}${v.toStringAsFixed(projected ? 1 : 0)} / 5$arrow';
  }

  Widget _xAxis(BuildContext context, double plotWidth) {
    final n = widget.days.length;
    final muted = Tokens.of(context).muted;
    return SizedBox(
      height: 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final e in widget.ticks.entries)
            Positioned(
              left: _labelWidth + (n < 2 ? 0 : e.key / (n - 1) * plotWidth) - (e.key == 0 ? 0 : 20),
              width: 40,
              child: Text(
                e.value,
                textAlign: e.key == 0 ? TextAlign.left : TextAlign.center,
                style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeriesPainter extends CustomPainter {
  final List<double?> values;
  final List<bool> projected;
  final double? baseline;
  final Color color;
  final int selected;
  final List<bool> periodMask;
  final Color surface;
  final Color grid;
  final Color ink;

  _SeriesPainter({
    required this.values,
    required this.projected,
    required this.baseline,
    required this.color,
    required this.selected,
    required this.periodMask,
    required this.surface,
    required this.grid,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 2) return;
    const pad = 6.0;
    final h = size.height - pad * 2;
    double x(int i) => i / (n - 1) * size.width;
    double y(double v) => pad + (5 - v) / 4 * h;
    final step = size.width / (n - 1);

    // Period bands.
    final band = Paint()..color = periodColor.withValues(alpha: 0.10);
    for (var i = 0; i < n; i++) {
      if (!periodMask[i]) continue;
      var j = i;
      while (j + 1 < n && periodMask[j + 1]) {
        j++;
      }
      canvas.drawRect(
        Rect.fromLTRB((x(i) - step / 2).clamp(0, size.width), 0, (x(j) + step / 2).clamp(0, size.width), size.height),
        band,
      );
      i = j;
    }

    // Recessive frame: bottom hairline plus the personal average.
    final hair = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), hair);
    if (baseline != null) {
      canvas.drawLine(
        Offset(0, y(baseline!)),
        Offset(size.width, y(baseline!)),
        hair..color = ink.withValues(alpha: 0.22),
      );
    }

    // Runs of consecutive days with data; logged and projected runs are
    // drawn separately (projection lighter) but joined so the line flows.
    var i = 0;
    while (i < n) {
      if (values[i] == null) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < n && values[j + 1] != null && projected[j + 1] == projected[i]) {
        j++;
      }
      // Join to the previous run when it ended the day before.
      final from = i > 0 && values[i - 1] != null ? i - 1 : i;
      _run(canvas, size, from, j, projected[i], x, y);
      i = j + 1;
    }

    // Crosshair and marker on the selected day.
    final s = selected.clamp(0, n - 1);
    final sx = x(s);
    canvas.drawLine(
      Offset(sx, 0),
      Offset(sx, size.height),
      Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    final v = values[s];
    if (v != null) {
      canvas.drawCircle(Offset(sx, y(v)), 6, Paint()..color = surface);
      canvas.drawCircle(Offset(sx, y(v)), 4, Paint()..color = projected[s] ? color.withValues(alpha: 0.55) : color);
    }
  }

  void _run(Canvas canvas, Size size, int i, int j, bool faded, double Function(int) x, double Function(double) y) {
    // A lone point still deserves a mark.
    if (i == j) {
      canvas.drawCircle(Offset(x(i), y(values[i]!)), 3, Paint()..color = color.withValues(alpha: faded ? 0.45 : 1));
      return;
    }
    // Catmull-Rom spline through the points (clamped at the run's ends).
    Offset pt(int k) => Offset(x(k.clamp(i, j)), y(values[k.clamp(i, j)]!));
    final path = Path()..moveTo(pt(i).dx, pt(i).dy);
    for (var k = i; k < j; k++) {
      final p0 = pt(k - 1), p1 = pt(k), p2 = pt(k + 1), p3 = pt(k + 2);
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    final fill = Path.from(path)
      ..lineTo(x(j), size.height)
      ..lineTo(x(i), size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: faded ? 0.05 : 0.10));
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: faded ? 0.45 : 1)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SeriesPainter old) =>
      old.selected != selected || old.values != values || old.color != color || old.baseline != baseline;
}

/// The coming five weeks, all projected (used in the cycle screen).
class ForecastChart extends StatelessWidget {
  final CycleInsights insights;
  final CycleSummary cycle;
  const ForecastChart({super.key, required this.insights, required this.cycle});

  @override
  Widget build(BuildContext context) {
    final ranges = <(String, String)>[
      for (final p in cycle.predictions) (p.start, p.end),
      if (cycle.inPeriod) (cycle.lastStart, fmtDay(addDays(dayOf(cycle.lastStart), cycle.avgPeriod - 1))),
    ];
    final up = insights.upcoming;
    final days = [
      for (final d in up)
        ChartDay(
          d.date,
          d.expected,
          projected: true,
          period: ranges.any((r) => d.date.compareTo(r.$1) >= 0 && d.date.compareTo(r.$2) <= 0),
        ),
    ];
    return LevelChart(
      days: days,
      baseline: insights.baseline,
      ticks: {for (var i = 0; i < up.length; i += 7) i: i == 0 ? 'Hoy' : shortDate(up[i].date)},
      title: (d) {
        final i = up.indexWhere((f) => f.date == d.date);
        final label = i == 0 ? 'Hoy' : (i == 1 ? 'Mañana' : shortDate(d.date));
        return '$label · día ${up[i].cycleDay} del ciclo${d.period ? ' · período' : ''}';
      },
    );
  }
}
