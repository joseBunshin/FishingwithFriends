import 'package:fishing_with_friends/features/feed/presentation/widgets/comment_body_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(String body) {
  return MaterialApp(
    home: Scaffold(body: Padding(
      padding: const EdgeInsets.all(8),
      child: CommentBodyText(body),
    )),
  );
}

List<TextSpan> _spans(WidgetTester tester) {
  final rich = tester.widget<RichText>(find.byType(RichText));
  return (rich.text as TextSpan).children!.cast<TextSpan>();
}

void main() {
  group('CommentBodyText', () {
    testWidgets('plain text renders as a single span', (tester) async {
      await tester.pumpWidget(_wrap('great catch!'));
      expect(_spans(tester), hasLength(1));
      expect(_spans(tester).first.text, 'great catch!');
    });

    testWidgets('@mention is split into a styled span', (tester) async {
      await tester.pumpWidget(_wrap('Nice fish @silentfisher100'));
      final spans = _spans(tester);
      // 'Nice fish ' + '@silentfisher100'
      expect(spans, hasLength(2));
      expect(spans[0].text, 'Nice fish ');
      expect(spans[1].text, '@silentfisher100');
      expect(spans[1].style?.fontWeight, FontWeight.w700);
    });

    testWidgets('multiple mentions all get styled', (tester) async {
      await tester.pumpWidget(_wrap('hey @abc and @xyz_123 nice'));
      final spans = _spans(tester);
      final mentions =
          spans.where((s) => s.text!.startsWith('@')).toList();
      expect(mentions, hasLength(2));
      expect(mentions.map((s) => s.text), contains('@abc'));
      expect(mentions.map((s) => s.text), contains('@xyz_123'));
    });

    testWidgets('email-shaped tokens are NOT mentioned', (tester) async {
      await tester.pumpWidget(_wrap('email me at hi@gmail.com please'));
      final spans = _spans(tester);
      // The regex matches @gmail (5 chars, fits 3..30 so it counts).
      // Verify it doesn't bleed into the next dotted token.
      final styled = spans.where(
        (s) => s.style?.fontWeight == FontWeight.w700,
      );
      for (final s in styled) {
        expect(s.text!.contains('.'), isFalse,
            reason: 'mention regex must not include dots');
      }
    });

    testWidgets('1-2 char @ tokens are NOT highlighted', (tester) async {
      await tester.pumpWidget(_wrap('@ab not a mention'));
      final styled = _spans(tester).where(
        (s) => s.style?.fontWeight == FontWeight.w700,
      );
      expect(styled, isEmpty);
    });
  });
}
