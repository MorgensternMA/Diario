// Renders the launcher icon PNGs into assets/icon/.
// Run with: flutter test tool/render_icon_test.dart && dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _coralLight = Color(0xFFE59A84);
const _coral = Color(0xFFCB5F4C);
const _cream = Color(0xFFFFF6EC);
const _creamDark = Color(0xFFF3E1CF);
const _lavender = Color(0xFF9B8AD8);
const _sage = Color(0xFF81B29A);
const _heart = Color(0xFFD4705E);

void _background(Canvas c) {
  c.drawRect(
    const Rect.fromLTWH(0, 0, _size, _size),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(_size, _size), [_coralLight, _coral]),
  );
}

/// A tote bag with an agenda card and a pencil peeking out, scaled around
/// the center.
void _glyph(Canvas c, double scale) {
  c.save();
  c.translate(_size / 2, _size / 2);
  c.scale(scale);
  c.translate(-_size / 2, -_size / 2);
  const s = _size;

  // Handle.
  c.drawArc(
    Rect.fromCenter(center: const Offset(s * 0.5, s * 0.41), width: s * 0.34, height: s * 0.36),
    3.14159,
    3.14159,
    false,
    Paint()
      ..color = _creamDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round,
  );

  // Things peeking out of the bag.
  void tilted(Offset center, double angle, void Function() draw) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    draw();
    c.restore();
  }

  tilted(const Offset(s * 0.42, s * 0.40), -0.2, () {
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.19, height: s * 0.22),
      const Radius.circular(s * 0.03),
    );
    c.drawRRect(card, Paint()..color = _lavender);
    c.drawRRect(
      RRect.fromLTRBAndCorners(
        card.left,
        card.top,
        card.right,
        card.top + s * 0.055,
        topLeft: const Radius.circular(s * 0.03),
        topRight: const Radius.circular(s * 0.03),
      ),
      Paint()..color = const Color(0xFF7D6BC4),
    );
  });
  tilted(const Offset(s * 0.62, s * 0.37), 0.22, () {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 0.065, height: s * 0.27),
        const Radius.circular(s * 0.03),
      ),
      Paint()..color = _sage,
    );
  });

  // Bag body, slightly wider at the bottom.
  final body = Path()
    ..moveTo(s * 0.27, s * 0.44)
    ..lineTo(s * 0.73, s * 0.44)
    ..lineTo(s * 0.77, s * 0.76)
    ..quadraticBezierTo(s * 0.78, s * 0.82, s * 0.72, s * 0.82)
    ..lineTo(s * 0.28, s * 0.82)
    ..quadraticBezierTo(s * 0.22, s * 0.82, s * 0.23, s * 0.76)
    ..close();
  c.drawPath(
    body.shift(const Offset(0, s * 0.02)),
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, s * 0.025),
  );
  c.drawPath(body, Paint()..color = _cream);
  // Band along the opening.
  c.drawRect(const Rect.fromLTRB(s * 0.27, s * 0.44, s * 0.73, s * 0.49), Paint()..color = _creamDark);

  // Heart on the front.
  const cx = s * 0.5, cy = s * 0.64, w = s * 0.075, h = s * 0.11;
  final heart = Path()
    ..moveTo(cx, cy + h * 0.45)
    ..cubicTo(cx - w * 1.6, cy - h * 0.05, cx - w * 0.75, cy - h * 0.75, cx, cy - h * 0.2)
    ..cubicTo(cx + w * 0.75, cy - h * 0.75, cx + w * 1.6, cy - h * 0.05, cx, cy + h * 0.45)
    ..close();
  c.drawPath(heart, Paint()..color = _heart);
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
