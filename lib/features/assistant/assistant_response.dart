import 'package:flutter/material.dart';
import 'reading_palette.dart';
import 'response_entities.dart';

/// All headings and highlighted figures are verbatim excerpts of the response.
/// The original prose remains complete, including uncertainty and attribution.
class AssistantResponse extends StatelessWidget {
  const AssistantResponse({super.key, required this.text});
  final String text;
  static final _heading = RegExp(r'^#{1,6}\s+(.+)$');
  static final _boldHeading = RegExp(r'^\*\*([^*\n]+)\*\*(:?)$');
  static final _list = RegExp(r'^(?:([-+•*])|(\d+[.)]))\s+(.+)$');
  static final _markup = RegExp(r'\*\*([^*\n]+)\*\*|\*([^*\n]+)\*');
  static final _bold = RegExp(r'\*\*([^*\n]+)\*\*');
  static final _place = RegExp(
    r'^(?:Parque|Plaza|Palacio|Museo|Teatro|Catedral|Universidad|Estación|Barrio)\b',
  );

  static String plain(String value) =>
      value.replaceAllMapped(_markup, (m) => m.group(1) ?? m.group(2)!);

  static List<InlineSpan> _entities(String value, ReadingPalette palette) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final e in ResponseEntities.parse(value)) {
      spans.add(TextSpan(text: value.substring(cursor, e.start)));
      spans.add(
        TextSpan(
          text: e.text,
          style: switch (e.kind) {
            ResponseEntityKind.name => TextStyle(
              color: palette.green,
              fontWeight: FontWeight.w700,
            ),
            ResponseEntityKind.date => TextStyle(
              color: palette.rust,
              fontWeight: FontWeight.w800,
            ),
            ResponseEntityKind.quantity => TextStyle(
              fontWeight: FontWeight.w800,
              backgroundColor: palette.highlight,
            ),
            ResponseEntityKind.number => TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.rust,
            ),
          },
        ),
      );
      cursor = e.end;
    }
    spans.add(TextSpan(text: value.substring(cursor)));
    return spans;
  }

  static List<InlineSpan> _inline(String value, ReadingPalette palette) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _markup.allMatches(value)) {
      spans.addAll(_entities(value.substring(cursor, m.start), palette));
      spans.add(
        TextSpan(
          children: _entities(m.group(1) ?? m.group(2)!, palette),
          style: TextStyle(
            fontWeight: m.group(1) != null ? FontWeight.w700 : null,
            fontStyle: m.group(2) != null ? FontStyle.italic : null,
          ),
        ),
      );
      cursor = m.end;
    }
    spans.addAll(_entities(value.substring(cursor), palette));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final children = <Widget>[];
    final narrative = text.length > 450;
    final usedSubjects = <String>{};
    final figures = ResponseEntities.parse(plain(text))
        .where((e) => e.value != null)
        .fold<List<ResponseEntity>>([], (all, e) {
          if (!all.any((old) => old.text == e.text)) all.add(e);
          return all;
        })
        .take(6)
        .toList();
    var afterBlank = false;
    var previousHeading = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        afterBlank = true;
        continue;
      }
      final heading = _heading.firstMatch(trimmed);
      final boldHeading = _boldHeading.firstMatch(trimmed);
      final isHeading =
          heading != null || (boldHeading != null && trimmed.length <= 130);
      final list = isHeading ? null : _list.firstMatch(trimmed);
      final quote = trimmed.startsWith('> ');
      final content =
          heading?.group(1) ??
          (isHeading
              ? '${boldHeading!.group(1)}${boldHeading.group(2)}'
              : null) ??
          list?.group(3) ??
          (quote ? trimmed.substring(2) : line);
      final cleaned = plain(content);
      final entities = ResponseEntities.parse(cleaned);
      String? subject;
      if (narrative &&
          !isHeading &&
          !previousHeading &&
          list == null &&
          !quote) {
        final bold = _bold
            .allMatches(content)
            .where(
              (m) =>
                  m.group(1)!.split(' ').length >= 4 &&
                  m.group(1)!.length <= 130,
            );
        if (bold.isNotEmpty) subject = bold.first.group(1);
        final places = entities.where(
          (e) => e.kind == ResponseEntityKind.name && _place.hasMatch(e.text),
        );
        subject ??= places.isNotEmpty ? places.first.text : null;
        if (subject != null && !usedSubjects.add(subject)) subject = null;
      }
      final first = children.isEmpty;
      final style = isHeading
          ? Theme.of(context).textTheme.headlineSmall!.copyWith(
              fontSize: first ? 30 : 23,
              height: 1.2,
            )
          : Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontFamily: 'Lora',
              fontSize: 16,
              height: 1.7,
            );
      Widget body = Text.rich(
        TextSpan(children: _inline(content, ReadingPalette.of(context))),
        style: style,
      );
      if (isHeading) body = Semantics(header: true, child: body);
      if (list != null) {
        body = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${list.group(2) ?? '•'}  ', style: style),
            Expanded(child: body),
          ],
        );
      }
      if (quote) {
        body = Container(
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: ReadingPalette.of(context).green,
                width: 3,
              ),
            ),
          ),
          child: body,
        );
      }
      final block = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject != null) ...[
            Semantics(
              header: true,
              child: Text(
                subject,
                style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                  fontSize: first ? 32 : 25,
                  height: 1.18,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          body,
        ],
      );
      children.add(
        Padding(
          padding: EdgeInsets.only(
            top: first ? 0 : (afterBlank && !previousHeading ? 28 : 12),
          ),
          child: block,
        ),
      );
      afterBlank = false;
      previousHeading = isHeading;
    }
    final prose = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (figures.isEmpty || text.length <= 180) return prose;
          final wide =
              constraints.maxWidth >= 620 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.4;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: prose),
                const SizedBox(width: 28),
                Container(
                  width: 128,
                  padding: const EdgeInsets.only(left: 22),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: ReadingPalette.of(context).line),
                    ),
                  ),
                  child: _Figures(figures: figures, vertical: true),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              prose,
              Padding(
                padding: EdgeInsets.only(top: 26, bottom: 20),
                child: Divider(
                  height: 1,
                  color: ReadingPalette.of(context).line,
                ),
              ),
              _Figures(figures: figures, vertical: false),
            ],
          );
        },
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.figures, required this.vertical});
  final List<ResponseEntity> figures;
  final bool vertical;
  Widget _figure(BuildContext context, ResponseEntity figure) {
    final isDate = figure.kind == ResponseEntityKind.date;
    final valueIndex = figure.text.indexOf(figure.value!);
    final prefix = isDate && valueIndex > 0
        ? figure.text.substring(0, valueIndex).trim()
        : '';
    final suffix = isDate
        ? figure.text.substring(valueIndex + figure.value!.length).trim()
        : figure.caption!;
    final labelStyle = TextStyle(
      fontFamily: 'Lora',
      fontSize: 12,
      height: 1.45,
      color: ReadingPalette.of(context).muted,
    );
    return Semantics(
      label: figure.text,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix.isNotEmpty) ...[
            Text(
              '${prefix[0].toUpperCase()}${prefix.substring(1)}',
              style: labelStyle,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            figure.value!,
            style: Theme.of(context).textTheme.headlineLarge!.copyWith(
              fontSize: figure.value!.length > 6 ? 22 : 36,
              fontWeight: FontWeight.w500,
              height: 1.1,
              color: figure.kind == ResponseEntityKind.date
                  ? ReadingPalette.of(context).rust
                  : ReadingPalette.of(context).ink,
            ),
          ),
          if (suffix.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              suffix,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 12,
                height: 1.45,
                color: ReadingPalette.of(context).muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < figures.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Divider(
                  height: 1,
                  color: ReadingPalette.of(context).line,
                ),
              ),
            _figure(context, figures[i]),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count =
            MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                constraints.maxWidth < 250
            ? 1
            : constraints.maxWidth > 460
            ? 3
            : 2;
        return Wrap(
          spacing: 20,
          runSpacing: 24,
          children: [
            for (final figure in figures)
              SizedBox(
                width: (constraints.maxWidth - (count - 1) * 20) / count,
                child: _figure(context, figure),
              ),
          ],
        );
      },
    );
  }
}
