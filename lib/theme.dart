import 'package:flutter/material.dart';

/// Colour palette. Default is dark (black). Light is optional (Drawer > Theme).
/// The k... values below are getters that read the active palette, so they
/// cannot be used inside `const` expressions.
class AppPalette {
  final Color bg, tile, line, muted, lime, orange, text, onLime, track, dash,
      limeDisabled;
  const AppPalette({
    required this.bg,
    required this.tile,
    required this.line,
    required this.muted,
    required this.lime,
    required this.orange,
    required this.text,
    required this.onLime,
    required this.track,
    required this.dash,
    required this.limeDisabled,
  });

  static const dark = AppPalette(
    bg: Color(0xFF0A0A0A),
    tile: Color(0xFF161616),
    line: Color(0xFF1F1F1F),
    muted: Color(0xFF8C8C8C),
    lime: Color(0xFFB4EB19),
    orange: Color(0xFFF5A623),
    text: Color(0xFFFFFFFF),
    onLime: Color(0xFF000000),
    track: Color(0xFF1E1E1E),
    dash: Color(0xFF3A3A3A),
    limeDisabled: Color(0xFF3C4D12),
  );

  static const light = AppPalette(
    bg: Color(0xFFF1F3F6),
    tile: Color(0xFFFFFFFF),
    line: Color(0xFFDDE1E7),
    muted: Color(0xFF6B7280),
    lime: Color(0xFF3F7D00),
    orange: Color(0xFFC26A00),
    text: Color(0xFF111827),
    onLime: Color(0xFFFFFFFF),
    track: Color(0xFFE3E7EC),
    dash: Color(0xFFB8BEC8),
    limeDisabled: Color(0xFFA9C48A),
  );
}

AppPalette _palette = AppPalette.dark;
bool get isLightPalette => identical(_palette, AppPalette.light);

void applyPalette(Brightness b) {
  _palette = b == Brightness.light ? AppPalette.light : AppPalette.dark;
}

Color get kBg => _palette.bg;
Color get kTile => _palette.tile;
Color get kLine => _palette.line;
Color get kMuted => _palette.muted;
Color get kLime => _palette.lime;
Color get kOrange => _palette.orange;
Color get kText => _palette.text;
Color get kOnLime => _palette.onLime;
Color get kTrack => _palette.track;
Color get kDash => _palette.dash;
Color get kLimeDisabled => _palette.limeDisabled;

class DashedBox extends StatelessWidget {
  final String label;
  final double height;
  const DashedBox({super.key, required this.label, this.height = 56});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _DashedPainter(),
          child: Center(
            child: Text(label,
                style: TextStyle(color: kMuted, fontSize: 15)),
          ),
        ),
      );
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kDash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(14)));
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => false;
}
