import 'package:flutter/material.dart';

/// A selectable text preview with case-insensitive search highlighting.
class SearchableTextPreview extends StatefulWidget {
  const SearchableTextPreview({required this.text, super.key});

  final String text;

  @override
  State<SearchableTextPreview> createState() => _SearchableTextPreviewState();
}

class _SearchableTextPreviewState extends State<SearchableTextPreview> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches(widget.text, _query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('text_preview_search'),
          controller: _searchController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            labelText: 'Search in file',
            prefixIcon: const Icon(Icons.search),
            suffixText: _query.isEmpty ? null : '${matches.length} match(es)',
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText.rich(
              TextSpan(children: _highlightedSpans(context, matches)),
            ),
          ),
        ),
      ],
    );
  }

  List<_TextMatch> _matches(String text, String query) {
    if (query.isEmpty) return const [];
    final matches = <_TextMatch>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    while ((start = lowerText.indexOf(lowerQuery, start)) != -1) {
      matches.add(_TextMatch(start, start + query.length));
      start += query.length;
    }
    return matches;
  }

  List<TextSpan> _highlightedSpans(
    BuildContext context,
    List<_TextMatch> matches,
  ) {
    if (matches.isEmpty) return [TextSpan(text: widget.text)];
    final spans = <TextSpan>[];
    var position = 0;
    for (final match in matches) {
      if (match.start > position) {
        spans.add(TextSpan(text: widget.text.substring(position, match.start)));
      }
      spans.add(
        TextSpan(
          text: widget.text.substring(match.start, match.end),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onTertiaryContainer,
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      position = match.end;
    }
    if (position < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(position)));
    }
    return spans;
  }
}

class _TextMatch {
  const _TextMatch(this.start, this.end);

  final int start;
  final int end;
}
