/// A run of pages, counted from 1, with both ends included.
class PageRange {
  const PageRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start + 1;

  String get label => start == end ? 'Page $start' : 'Pages $start–$end';

  bool contains(int page) => page >= start && page <= end;

  @override
  bool operator ==(Object other) => other is PageRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => start == end ? '$start' : '$start-$end';
}

/// The outcome of reading what the user typed into the page range box.
class RangeParseResult {
  const RangeParseResult(this.ranges, [this.error]);

  final List<PageRange> ranges;

  /// A message to show the user, or null when everything is fine.
  final String? error;

  bool get isValid => error == null && ranges.isNotEmpty;
}

/// Reads text like "1-4, 5-10, 11" for a PDF with [pageCount] pages.
RangeParseResult parsePageRanges(String input, int pageCount) {
  final parts = input
      .split(RegExp(r'[,;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return const RangeParseResult([], 'Type at least one page range, like 1-3.');
  }

  final pattern = RegExp(r'^(\d+)\s*(?:[-–]\s*(\d+))?$');
  final ranges = <PageRange>[];
  for (final part in parts) {
    final match = pattern.firstMatch(part);
    if (match == null) {
      return RangeParseResult(const [], '"$part" is not a page range. Use numbers like 1-3 or 5.');
    }
    final start = int.tryParse(match.group(1)!);
    final endText = match.group(2);
    final end = endText == null ? start : int.tryParse(endText);
    if (start == null || end == null || start < 1 || end < 1) {
      return const RangeParseResult([], 'Page numbers start at 1.');
    }
    if (start > end) {
      return RangeParseResult(const [], '"$part" goes backwards. Write it as $end-$start.');
    }
    if (end > pageCount) {
      return RangeParseResult(
        const [],
        pageCount == 1 ? 'This PDF has only 1 page.' : 'This PDF has only $pageCount pages.',
      );
    }
    ranges.add(PageRange(start, end));
  }
  return RangeParseResult(ranges);
}

/// One range for every single page.
List<PageRange> everyPage(int pageCount) => [for (var i = 1; i <= pageCount; i++) PageRange(i, i)];

/// A sensible starting value for the range box: the PDF cut into two halves.
String suggestedRanges(int pageCount) {
  if (pageCount <= 1) return '1';
  final half = (pageCount / 2).ceil();
  final first = half == 1 ? '1' : '1-$half';
  final second = half + 1 == pageCount ? '$pageCount' : '${half + 1}-$pageCount';
  return '$first, $second';
}
