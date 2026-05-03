import 'package:flutter/material.dart';

/// Renders a comment body with `@username` substrings styled in primary
/// color. Username characters are alphanumeric + underscore, 3..30 chars
/// (matches `profiles.username` CHECK constraint).
class CommentBodyText extends StatelessWidget {
  const CommentBodyText(this.body, {super.key});

  final String body;

  static final RegExp _mention = RegExp('@([A-Za-z0-9_]{3,30})');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final spans = <TextSpan>[];

    var cursor = 0;
    for (final match in _mention.allMatches(body)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: base.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor)));
    }

    return RichText(
      text: TextSpan(style: base, children: spans),
    );
  }
}
