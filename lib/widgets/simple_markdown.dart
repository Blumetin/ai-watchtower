import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';
import 'call.dart';

class SimpleMarkdown extends StatefulWidget {
  final String data;
  final TextStyle style;
  const SimpleMarkdown({super.key, required this.data, required this.style});

  @override
  State<SimpleMarkdown> createState() => _SimpleMarkdownState();
}

enum _Kind { paragraph, heading, bullet, numbered, gap }

class _Seg {
  final String text;
  final bool bold;
  final TapGestureRecognizer? link;
  const _Seg(this.text, {this.bold = false, this.link});
}

class _Block {
  final _Kind kind;
  final String marker;
  final List<_Seg> segs;
  const _Block(this.kind, this.segs, [this.marker = '']);
}

class _SimpleMarkdownState extends State<SimpleMarkdown> {
  static final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
  static final _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final _heading = RegExp(r'^\s*#{1,6}\s+(.*)$');
  static final _inline = RegExp(
    r'!\[([^\]]*)\]\([^)]*\)|\[([^\]]+)\]\(([^)\s]+)\)|\*\*(.+?)\*\*',
  );

  final _recognizers = <TapGestureRecognizer>[];
  List<_Block> _blocks = const [];

  final _links = <(String, String)>[];

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(SimpleMarkdown old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _parse();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _parse() {
    _disposeRecognizers();
    _links.clear();
    final blocks = <_Block>[];
    for (final raw in widget.data.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        if (blocks.isNotEmpty) blocks.add(const _Block(_Kind.gap, []));
        continue;
      }
      if (_heading.firstMatch(line) case final m?) {
        blocks.add(_Block(_Kind.heading, _inlineSegs(m[1]!)));
      } else if (_bullet.firstMatch(line) case final m?) {
        blocks.add(_Block(_Kind.bullet, _inlineSegs(m[1]!), '•'));
      } else if (_numbered.firstMatch(line) case final m?) {
        blocks.add(_Block(_Kind.numbered, _inlineSegs(m[2]!), '${m[1]}.'));
      } else {
        blocks.add(_Block(_Kind.paragraph, _inlineSegs(line)));
      }
    }
    _blocks = blocks;
  }

  List<_Seg> _inlineSegs(String text) {
    final segs = <_Seg>[];
    var i = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > i) segs.add(_Seg(text.substring(i, m.start)));
      if (m[1] != null) {
        segs.add(_Seg(m[1]!));
      } else if (m[2] != null) {
        final url = m[3]!;
        if (url.startsWith('https://')) {
          final tap = TapGestureRecognizer()
            ..onTap = () {
              if (mounted) openExternal(context, url);
            };
          _recognizers.add(tap);
          segs.add(_Seg(m[2]!, link: tap));
          if (!_links.any((l) => l.$2 == url)) _links.add((m[2]!, url));
        } else {
          segs.add(_Seg(m[2]!));
        }
      } else {
        segs.add(_Seg(m[4]!, bold: true));
      }
      i = m.end;
    }
    if (i < text.length) segs.add(_Seg(text.substring(i)));
    return segs;
  }

  Widget _rich(List<_Seg> segs, TextStyle base) => Text.rich(
    TextSpan(
      style: base,
      children: [
        for (final s in segs)
          TextSpan(
            text: s.text,
            recognizer: s.link,
            style: s.link != null
                ? const TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  )
                : s.bold
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in _blocks)
          switch (b.kind) {
            _Kind.gap => const SizedBox(height: 8),
            _Kind.heading => _rich(
              b.segs,
              style.copyWith(fontWeight: FontWeight.w700),
            ),
            _Kind.paragraph => _rich(b.segs, style),
            _Kind.bullet || _Kind.numbered => Padding(
              padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 36, child: Text(b.marker, style: style)),
                  Expanded(child: _rich(b.segs, style)),
                ],
              ),
            ),
          },
        for (final (label, url) in _links)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 56),
            ),
            onPressed: () => openExternal(context, url),
            icon: const Icon(Symbols.open_in_new_rounded, size: 18),
            label: Text(label),
          ),
      ],
    );
  }
}
