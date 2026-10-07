import 'package:flutter/material.dart';

const kBg = Color(0xFF0A0A0A);
const kLime = Color(0xFFB4EB19);
const kOrange = Color(0xFFF5A623);
const kTile = Color(0xFF161616);
const kLine = Color(0xFF1F1F1F);
const kMuted = Color(0xFF8C8C8C);

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
                style: const TextStyle(color: kMuted, fontSize: 15)),
          ),
        ),
      );
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A3A3A)
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
