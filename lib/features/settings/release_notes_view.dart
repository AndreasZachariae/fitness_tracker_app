import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../domain/updates.dart';

/// The text of a GitHub release, readable in the app (1.2.2): headings,
/// lists, test list boxes, bold and code.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({required this.markdown, super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = parseReleaseNotes(markdown);
    if (blocks.isEmpty) {
      return Text(
        S.releaseNotesEmpty,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final body = theme.textTheme.bodyMedium!;
    TextSpan spans(NoteBlock block, TextStyle style) => TextSpan(
      style: style,
      children: [
        for (final s in block.spans)
          TextSpan(
            text: s.text,
            style: s.bold
                ? const TextStyle(fontWeight: FontWeight.w700)
                : s.code
                ? TextStyle(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  )
                : null,
          ),
      ],
    );

    Widget item(NoteBlock block, Widget marker) => Padding(
      padding: EdgeInsets.only(left: 4 + 16.0 * block.level, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: marker),
          Expanded(child: Text.rich(spans(block, body))),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, block) in blocks.indexed)
          switch (block.kind) {
            NoteBlockKind.heading => Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 2),
              child: Text.rich(
                spans(
                  block,
                  (block.level <= 2
                          ? theme.textTheme.titleMedium!
                          : theme.textTheme.titleSmall!)
                      .copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ),
            NoteBlockKind.bullet => item(
              block,
              Text('•', style: body.copyWith(fontWeight: FontWeight.w700)),
            ),
            NoteBlockKind.task => item(
              block,
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.check_box_outline_blank,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            NoteBlockKind.paragraph => Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Text.rich(spans(block, body)),
            ),
          },
      ],
    );
  }
}
