import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:speed_test/config.dart';
import 'package:speed_test/theme.dart';

void main() {
  test('isPlaceholder detects unfilled config values', () {
    expect(isPlaceholder('YOUR_EMAIL'), isTrue);
    expect(isPlaceholder('https://YOUR_DOMAIN/x.json'), isTrue);
    expect(isPlaceholder('https://albonik.com'), isFalse);
  });

  testWidgets('DashedBox shows its label', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DashedBox(label: 'Banner ad 320x50')),
    ));
    expect(find.text('Banner ad 320x50'), findsOneWidget);
  });
}
