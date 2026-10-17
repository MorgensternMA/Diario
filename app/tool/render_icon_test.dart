// Renders the launcher icon PNGs into assets/icon/.
// Run with: flutter test tool/render_icon_test.dart && dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _lavender = Color(0xFF9B7BD8);
const _rose = Color(0xFFE88BB0);
const _pink = Color(0xFFE5397A);
const _plum = Color(0xFF5B3E96);

void _background(Canvas c) {
  c.drawRect(
    const Rect.fromLTWH(0, 0, _size, _size),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(_size, _size), [_lavender, _rose]),
  );
}

/// A calendar page with binder rings and a drop, scaled around the center.
void _glyph(Canvas c, double scale) {
  c.save();
  c.translate(_size / 2, _size / 2);
  c.scale(scale);
  c.translate(-_size / 2, -_size / 2);

  const s = _size;
  const w = s * 0.56, h = s * 0.56;
  const left = (s - w) / 2, top = (s - h) / 2 + s * 0.03;
  const r = Radius.circular(s * 0.08);
  final page = RRect.fromLTRBR(left, top, left + w, top + h, r);

  c.drawRRect(
    page.shift(const Offset(0, s * 0.018)),
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, s * 0.025),
  );
  c.drawRRect(page, Paint()..color = const Color(0xFFFFFFFF));
  c.drawRRect(
    RRect.fromLTRBAndCorners(left, top, left + w, top + h * 0.24, topLeft: r, topRight: r),
    Paint()..color = _pink,
  );
  for (final x in [left + w * 0.28, left + w * 0.72]) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, top), width: s * 0.05, height: s * 0.13),
        const Radius.circular(s * 0.025),
      ),
      Paint()..color = _plum,
    );
  }

  // Drop centered in the page body.
  const cx = s / 2, cy = top + h * 0.62, d = h * 0.46;
  const rad = d * 0.32;
  const cc = Offset(cx, cy + d * 0.18);
  final drop = Path()
    ..moveTo(cx, cy - d * 0.5)
    // Control points above the arc ends keep the sides tangent to the arc.
    ..cubicTo(cx + rad * 0.25, cy - d * 0.36, cx + rad, cc.dy - rad * 0.95, cx + rad, cc.dy)
    ..arcToPoint(Offset(cx - rad, cc.dy), radius: const Radius.circular(rad))
    ..cubicTo(cx - rad, cc.dy - rad * 0.95, cx - rad * 0.25, cy - d * 0.36, cx, cy - d * 0.5)
    ..close();
  c.drawPath(drop, Paint()..color = _pink);
  c.drawCircle(Offset(cx - rad * 0.4, cc.dy - rad * 0.25), rad * 0.18, Paint()..color = const Color(0x88FFFFFF));
  c.restore();
}

Future<void> _save(String name, void Function(Canvas) paint) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(_size.toInt(), _size.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('assets/icon/$name').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render icons', (tester) async {
    await tester.runAsync(() async {
      // Full icon (iOS, macOS, legacy Android).
      await _save('icon.png', (c) {
        _background(c);
        _glyph(c, 1.0);
      });
      // Android adaptive icon layers; the glyph must fit the inner safe zone.
      await _save('icon_background.png', _background);
      await _save('icon_foreground.png', (c) => _glyph(c, 0.78));
    });
  });
}
