import 'package:flutter/material.dart';

/// Konu notları için küçük bir markdown görüntüleyici:
/// başlıklar, maddeler, tablolar, alıntı, **kalın**, *italik*, ~~üstü çizili~~, `kod`.
class MdView extends StatelessWidget {
  final String text;
  const MdView(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium!.copyWith(height: 1.45);
    final lines = text.split('\n');
    final children = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final raw = lines[i];
      final line = raw.trimRight();
      final t = line.trimLeft();
      if (t.isEmpty) {
        children.add(const SizedBox(height: 6));
        i++;
        continue;
      }
      if (t.startsWith('|')) {
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          final r = lines[i].trim();
          final cells = r
              .substring(1, r.endsWith('|') ? r.length - 1 : r.length)
              .split('|')
              .map((c) => c.trim())
              .toList();
          final isSep = cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
          if (!isSep) rows.add(cells);
          i++;
        }
        children.add(_table(context, rows, base));
        children.add(const SizedBox(height: 8));
        continue;
      }
      if (t.startsWith('---')) {
        children.add(const Divider());
        i++;
        continue;
      }
      if (t.startsWith('#')) {
        final level = t.indexOf(' ');
        final content = t.substring(level + 1);
        final style = level <= 2
            ? theme.textTheme.titleMedium
            : theme.textTheme.titleSmall;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text.rich(
              TextSpan(children: inlineSpans(content, style!, context))),
        ));
        i++;
        continue;
      }
      if (t.startsWith('> ')) {
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 3)),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ),
          child: Text.rich(TextSpan(
              children: inlineSpans(t.substring(2), base, context))),
        ));
        i++;
        continue;
      }
      if (t.startsWith('- ') || t.startsWith('* ')) {
        final indent = (line.length - t.length) ~/ 2;
        children.add(Padding(
          padding: EdgeInsets.only(left: 4.0 + indent * 16, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(indent > 0 ? '◦  ' : '•  ', style: base),
              Expanded(
                child: Text.rich(TextSpan(
                    children: inlineSpans(t.substring(2), base, context))),
              ),
            ],
          ),
        ));
        i++;
        continue;
      }
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(TextSpan(children: inlineSpans(t, base, context))),
      ));
      i++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _table(BuildContext context, List<List<String>> rows, TextStyle base) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final small = base.copyWith(fontSize: (base.fontSize ?? 14) - 1);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: theme.dividerColor, width: 0.6),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0
                  ? BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withOpacity(0.45))
                  : null,
              children: [
                for (var c = 0; c < cols; c++)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 230),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Text.rich(TextSpan(
                          children: inlineSpans(
                              c < rows[r].length ? rows[r][c] : '',
                              r == 0
                                  ? small.copyWith(fontWeight: FontWeight.w600)
                                  : small,
                              context))),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

final _inline = RegExp(r'(\*\*[^*]+\*\*|~~[^~]+~~|`[^`]+`|\*[^*\s][^*]*\*)');

List<InlineSpan> inlineSpans(String s, TextStyle base, BuildContext context) {
  final out = <InlineSpan>[];
  var pos = 0;
  for (final m in _inline.allMatches(s)) {
    if (m.start > pos) {
      out.add(TextSpan(text: s.substring(pos, m.start), style: base));
    }
    final tok = m.group(0)!;
    if (tok.startsWith('**')) {
      out.add(TextSpan(
          text: tok.substring(2, tok.length - 2),
          style: base.copyWith(fontWeight: FontWeight.w700)));
    } else if (tok.startsWith('~~')) {
      out.add(TextSpan(
          text: tok.substring(2, tok.length - 2),
          style: base.copyWith(decoration: TextDecoration.lineThrough)));
    } else if (tok.startsWith('`')) {
      out.add(TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: base.copyWith(fontFamily: 'monospace')));
    } else {
      out.add(TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: base.copyWith(fontStyle: FontStyle.italic)));
    }
    pos = m.end;
  }
  if (pos < s.length) out.add(TextSpan(text: s.substring(pos), style: base));
  return out;
}
