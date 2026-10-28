/// A small XML reader for the parts inside Office files.
///
/// It builds a simple tree. Namespace prefixes are dropped from element names
/// (`w:p` becomes `p`), and [XmlElement.attr] finds an attribute by its name
/// with or without a prefix.
class XmlElement {
  XmlElement(this.name);

  /// The element name without its prefix.
  final String name;

  /// Attributes by their full name, for example `r:id`.
  final Map<String, String> attributes = {};

  /// Child elements and text, in document order.
  final List<Object> children = [];

  /// The value of the attribute called [local], with or without a prefix.
  String? attr(String local) {
    final exact = attributes[local];
    if (exact != null) return exact;
    for (final entry in attributes.entries) {
      if (entry.key.endsWith(':$local')) return entry.value;
    }
    return null;
  }

  Iterable<XmlElement> get elements => children.whereType<XmlElement>();

  /// The first child element called [name], or null.
  XmlElement? child(String name) {
    for (final element in elements) {
      if (element.name == name) return element;
    }
    return null;
  }

  Iterable<XmlElement> childrenNamed(String name) => elements.where((e) => e.name == name);

  /// Every element called [name] below this one, in document order.
  Iterable<XmlElement> descendants(String name) sync* {
    for (final element in elements) {
      if (element.name == name) yield element;
      yield* element.descendants(name);
    }
  }

  /// All text below this element, joined.
  String get text {
    final buffer = StringBuffer();
    _collectText(buffer);
    return buffer.toString();
  }

  void _collectText(StringBuffer buffer) {
    for (final child in children) {
      if (child is String) {
        buffer.write(child);
      } else if (child is XmlElement) {
        child._collectText(buffer);
      }
    }
  }
}

/// Text in these elements keeps its spaces, even when it is only spaces.
const _keepSpaces = {'t', 'delText', 'instrText'};

/// Reads [source] and returns a root element that holds the document's elements.
XmlElement parseXml(String source) {
  final root = XmlElement('#document');
  final stack = <XmlElement>[root];
  final text = StringBuffer();
  final length = source.length;
  var i = 0;

  void flushText() {
    if (text.isEmpty) return;
    final value = text.toString();
    text.clear();
    final parent = stack.last;
    if (value.trim().isEmpty && !_keepSpaces.contains(parent.name)) return;
    parent.children.add(_decodeEntities(value));
  }

  while (i < length) {
    final open = source.indexOf('<', i);
    if (open < 0) {
      text.write(source.substring(i));
      break;
    }
    if (open > i) text.write(source.substring(i, open));

    if (source.startsWith('<!--', open)) {
      final close = source.indexOf('-->', open + 4);
      i = close < 0 ? length : close + 3;
      continue;
    }
    if (source.startsWith('<![CDATA[', open)) {
      final close = source.indexOf(']]>', open + 9);
      flushText();
      stack.last.children.add(source.substring(open + 9, close < 0 ? length : close));
      i = close < 0 ? length : close + 3;
      continue;
    }
    if (source.startsWith('<?', open)) {
      final close = source.indexOf('?>', open + 2);
      i = close < 0 ? length : close + 2;
      continue;
    }
    if (source.startsWith('<!', open)) {
      final close = source.indexOf('>', open + 2);
      i = close < 0 ? length : close + 1;
      continue;
    }
    if (source.startsWith('</', open)) {
      flushText();
      final close = source.indexOf('>', open + 2);
      if (stack.length > 1) stack.removeLast();
      i = close < 0 ? length : close + 1;
      continue;
    }

    flushText();
    final close = _tagEnd(source, open + 1);
    var body = source.substring(open + 1, close);
    var selfClosing = false;
    if (body.endsWith('/')) {
      selfClosing = true;
      body = body.substring(0, body.length - 1);
    }
    final element = _readTag(body);
    stack.last.children.add(element);
    if (!selfClosing) stack.add(element);
    i = close + 1;
  }
  flushText();
  return root;
}

/// Finds the `>` that ends a tag, skipping any inside quoted values.
int _tagEnd(String source, int from) {
  String? quote;
  for (var i = from; i < source.length; i++) {
    final char = source[i];
    if (quote != null) {
      if (char == quote) quote = null;
    } else if (char == '"' || char == "'") {
      quote = char;
    } else if (char == '>') {
      return i;
    }
  }
  return source.length;
}

bool _isSpace(String char) => char == ' ' || char == '\n' || char == '\r' || char == '\t';

XmlElement _readTag(String body) {
  var i = 0;
  final length = body.length;
  while (i < length && !_isSpace(body[i])) {
    i++;
  }
  final fullName = body.substring(0, i);
  final colon = fullName.indexOf(':');
  final element = XmlElement(colon < 0 ? fullName : fullName.substring(colon + 1));

  while (i < length) {
    while (i < length && _isSpace(body[i])) {
      i++;
    }
    if (i >= length) break;
    final nameStart = i;
    while (i < length && body[i] != '=' && !_isSpace(body[i])) {
      i++;
    }
    final name = body.substring(nameStart, i);
    while (i < length && _isSpace(body[i])) {
      i++;
    }
    if (i >= length || body[i] != '=') {
      if (name.isNotEmpty) element.attributes[name] = '';
      continue;
    }
    i++;
    while (i < length && _isSpace(body[i])) {
      i++;
    }
    if (i >= length) break;
    final quote = body[i];
    if (quote != '"' && quote != "'") {
      final valueStart = i;
      while (i < length && !_isSpace(body[i])) {
        i++;
      }
      element.attributes[name] = _decodeEntities(body.substring(valueStart, i));
      continue;
    }
    final valueEnd = body.indexOf(quote, i + 1);
    final end = valueEnd < 0 ? length : valueEnd;
    element.attributes[name] = _decodeEntities(body.substring(i + 1, end));
    i = end + 1;
  }
  return element;
}

String _decodeEntities(String value) {
  if (!value.contains('&')) return value;
  final out = StringBuffer();
  var i = 0;
  while (i < value.length) {
    final amp = value.indexOf('&', i);
    if (amp < 0) {
      out.write(value.substring(i));
      break;
    }
    out.write(value.substring(i, amp));
    final semi = value.indexOf(';', amp);
    if (semi < 0 || semi - amp > 10) {
      out.write('&');
      i = amp + 1;
      continue;
    }
    final name = value.substring(amp + 1, semi);
    String? decoded;
    switch (name) {
      case 'lt':
        decoded = '<';
      case 'gt':
        decoded = '>';
      case 'amp':
        decoded = '&';
      case 'quot':
        decoded = '"';
      case 'apos':
        decoded = "'";
      default:
        if (name.startsWith('#x') || name.startsWith('#X')) {
          final code = int.tryParse(name.substring(2), radix: 16);
          if (code != null && code <= 0x10FFFF) decoded = String.fromCharCode(code);
        } else if (name.startsWith('#')) {
          final code = int.tryParse(name.substring(1));
          if (code != null && code <= 0x10FFFF) decoded = String.fromCharCode(code);
        }
    }
    if (decoded == null) {
      out.write(value.substring(amp, semi + 1));
    } else {
      out.write(decoded);
    }
    i = semi + 1;
  }
  return out.toString();
}
