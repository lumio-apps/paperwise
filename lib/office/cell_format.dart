/// Turns the numbers stored in an Excel sheet into the text Excel would show,
/// using the cell's number format (dates, times, percents, decimals, currency).
///
/// It covers the formats people use every day. Rare ones fall back to a plain number.
class CellFormat {
  CellFormat(this.code) {
    _sections = _splitSections(code);
    final first = _sections.isEmpty ? '' : _sections.first;
    final lower = first.toLowerCase().trim();
    isGeneral = lower.isEmpty || lower == 'general';
    isText = !isGeneral && first.contains('@');
    isDate = !isGeneral && !isText && _looksLikeDate(first);
  }

  /// The format of a built-in number format id, as Excel defines them.
  static String builtIn(int id) {
    const formats = <int, String>{
      0: 'General',
      1: '0',
      2: '0.00',
      3: '#,##0',
      4: '#,##0.00',
      9: '0%',
      10: '0.00%',
      11: '0.00E+00',
      12: 'General',
      13: 'General',
      14: 'yyyy-mm-dd',
      15: 'd-mmm-yy',
      16: 'd-mmm',
      17: 'mmm-yy',
      18: 'h:mm AM/PM',
      19: 'h:mm:ss AM/PM',
      20: 'h:mm',
      21: 'h:mm:ss',
      22: 'yyyy-mm-dd h:mm',
      37: '#,##0',
      38: '#,##0',
      39: '#,##0.00',
      40: '#,##0.00',
      45: 'mm:ss',
      46: '[h]:mm:ss',
      47: 'mm:ss.0',
      48: '0.0E+0',
      49: '@',
    };
    final known = formats[id];
    if (known != null) return known;
    // Ids 27 to 36 and 50 to 58 are dates in East Asian versions of Excel.
    if ((id >= 27 && id <= 36) || (id >= 50 && id <= 58)) return 'yyyy-mm-dd';
    return 'General';
  }

  final String code;
  late final List<String> _sections;
  late final bool isGeneral;
  late final bool isText;
  late final bool isDate;

  /// The text for a stored number.
  String format(double value, {required bool date1904}) {
    if (value.isNaN || value.isInfinite) return value.toString();
    if (isGeneral || isText) return generalNumber(value);

    var section = _sections.first;
    var signed = true;
    if (value < 0 && _sections.length > 1) {
      section = _sections[1];
      signed = false;
    } else if (value == 0 && _sections.length > 2) {
      section = _sections[2];
    }

    try {
      if (isDate) {
        if (value < 0) return generalNumber(value);
        return _formatDate(value, section, date1904);
      }
      return _formatNumber(value, section, signed);
    } catch (_) {
      return generalNumber(value);
    }
  }

  /// A number shown the way Excel's "General" format shows it.
  static String generalNumber(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) return value.toInt().toString();
    final abs = value.abs();
    if (abs >= 1e15 || abs < 1e-9) return _excelExponent(value.toStringAsExponential(5));
    var text = value.toStringAsPrecision(11);
    if (text.contains('e')) return _excelExponent(text);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    }
    return text;
  }

  /// Turns Dart's `1.5e+7` into Excel's `1.5E+07`.
  static String _excelExponent(String dart) {
    final parts = dart.split('e');
    if (parts.length != 2) return dart;
    var mantissa = parts[0];
    if (mantissa.contains('.')) {
      mantissa = mantissa.replaceFirst(RegExp(r'0+$'), '');
      if (mantissa.endsWith('.')) mantissa = mantissa.substring(0, mantissa.length - 1);
    }
    final exponent = int.parse(parts[1]);
    final sign = exponent < 0 ? '-' : '+';
    return '${mantissa}E$sign${exponent.abs().toString().padLeft(2, '0')}';
  }

  static List<String> _splitSections(String code) {
    final sections = <String>[];
    final current = StringBuffer();
    var inQuote = false;
    var inBracket = false;
    for (var i = 0; i < code.length; i++) {
      final char = code[i];
      if (char == '\\' && !inQuote && i + 1 < code.length) {
        current.write(char);
        current.write(code[i + 1]);
        i++;
        continue;
      }
      if (char == '"') inQuote = !inQuote;
      if (!inQuote && char == '[') inBracket = true;
      if (!inQuote && char == ']') inBracket = false;
      if (char == ';' && !inQuote && !inBracket) {
        sections.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    sections.add(current.toString());
    return sections;
  }

  static bool _looksLikeDate(String section) {
    final clean = StringBuffer();
    var i = 0;
    while (i < section.length) {
      final char = section[i];
      if (char == '"') {
        final end = section.indexOf('"', i + 1);
        i = end < 0 ? section.length : end + 1;
      } else if (char == '\\' || char == '_' || char == '*') {
        i += 2;
      } else if (char == '[') {
        final end = section.indexOf(']', i + 1);
        final inner = section.substring(i + 1, end < 0 ? section.length : end).toLowerCase();
        if (RegExp(r'^(h+|m+|s+)$').hasMatch(inner)) clean.write(inner);
        i = end < 0 ? section.length : end + 1;
      } else {
        clean.write(char);
        i++;
      }
    }
    final text = clean.toString().toLowerCase();
    if (RegExp('[ydhs]').hasMatch(text)) return true;
    return text.contains('m') && !RegExp('[0#?]').hasMatch(text);
  }

  // ----- numbers

  static String _formatNumber(double value, String section, bool signed) {
    final prefix = StringBuffer();
    final suffix = StringBuffer();
    final pattern = StringBuffer();
    var stage = 0; // 0: before the digits, 1: in the digits, 2: after them.
    var percent = false;

    void literal(String text) {
      if (stage == 0) {
        prefix.write(text);
      } else {
        stage = 2;
        suffix.write(text);
      }
    }

    bool isDigitMark(String char) => char == '0' || char == '#' || char == '?';

    var i = 0;
    while (i < section.length) {
      final char = section[i];
      if (char == '"') {
        final end = section.indexOf('"', i + 1);
        literal(section.substring(i + 1, end < 0 ? section.length : end));
        i = end < 0 ? section.length : end + 1;
      } else if (char == '\\') {
        if (i + 1 < section.length) literal(section[i + 1]);
        i += 2;
      } else if (char == '_') {
        literal(' ');
        i += 2;
      } else if (char == '*') {
        i += 2;
      } else if (char == '[') {
        final end = section.indexOf(']', i + 1);
        final inner = section.substring(i + 1, end < 0 ? section.length : end);
        if (inner.startsWith(r'$')) literal(inner.substring(1).split('-').first);
        i = end < 0 ? section.length : end + 1;
      } else if (isDigitMark(char)) {
        stage = 1;
        pattern.write(char);
        i++;
      } else if ((char == '.' || char == ',') && (stage == 1 || (i + 1 < section.length && isDigitMark(section[i + 1])))) {
        stage = 1;
        pattern.write(char);
        i++;
      } else if ((char == 'E' || char == 'e') &&
          stage == 1 &&
          i + 1 < section.length &&
          (section[i + 1] == '+' || section[i + 1] == '-')) {
        pattern.write('E');
        i += 2;
      } else if (char == '%') {
        percent = true;
        literal('%');
        i++;
      } else if (char == '@') {
        i++;
      } else {
        literal(char);
        i++;
      }
    }

    final marks = pattern.toString();
    if (marks.isEmpty) return '$prefix$suffix';

    var number = value.abs();
    if (percent) number *= 100;

    String digits;
    final exponentAt = marks.indexOf('E');
    if (exponentAt >= 0) {
      final mantissa = marks.substring(0, exponentAt);
      final dot = mantissa.indexOf('.');
      final decimals = dot < 0 ? 0 : mantissa.substring(dot + 1).replaceAll(',', '').length;
      final parts = number.toStringAsExponential(decimals).split('e');
      final exponent = int.parse(parts[1]);
      digits = '${parts[0]}E${exponent < 0 ? '-' : '+'}${exponent.abs().toString().padLeft(2, '0')}';
    } else {
      final dot = marks.indexOf('.');
      final integerMarks = dot < 0 ? marks : marks.substring(0, dot);
      final decimalMarks = dot < 0 ? '' : marks.substring(dot + 1).replaceAll(',', '');
      // Commas after the last digit mark divide by 1000 ("#,##0," shows thousands).
      var scaled = integerMarks;
      while (scaled.endsWith(',')) {
        number /= 1000;
        scaled = scaled.substring(0, scaled.length - 1);
      }
      final grouping = scaled.contains(',');
      final maxDecimals = decimalMarks.length;
      final minDecimals = '0'.allMatches(decimalMarks).length;
      digits = number.toStringAsFixed(maxDecimals);
      if (maxDecimals > minDecimals && digits.contains('.')) {
        var trimmed = digits;
        while (trimmed.endsWith('0') && trimmed.length - trimmed.indexOf('.') - 1 > minDecimals) {
          trimmed = trimmed.substring(0, trimmed.length - 1);
        }
        if (trimmed.endsWith('.')) trimmed = trimmed.substring(0, trimmed.length - 1);
        digits = trimmed;
      }
      var whole = digits;
      var fraction = '';
      final point = digits.indexOf('.');
      if (point >= 0) {
        whole = digits.substring(0, point);
        fraction = digits.substring(point);
      }
      if (whole == '0' && !scaled.contains('0') && fraction.isNotEmpty) whole = '';
      if (grouping) whole = _group(whole);
      digits = '$whole$fraction';
    }

    final negative = signed && value < 0 && digits.replaceAll(RegExp('[^1-9]'), '').isNotEmpty;
    return '${negative ? '-' : ''}$prefix$digits$suffix';
  }

  static String _group(String whole) {
    if (whole.length <= 3) return whole;
    final out = StringBuffer();
    final first = whole.length % 3;
    if (first > 0) out.write(whole.substring(0, first));
    for (var i = first; i < whole.length; i += 3) {
      if (out.isNotEmpty) out.write(',');
      out.write(whole.substring(i, i + 3));
    }
    return out.toString();
  }

  // ----- dates and times

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static String _formatDate(double serial, String section, bool date1904) {
    final wholeDays = serial.floor();
    final millis = ((serial - wholeDays) * 86400000).round();
    final DateTime base;
    if (date1904) {
      base = DateTime.utc(1904, 1, 1);
    } else if (wholeDays < 60) {
      // Excel counts a 29 February 1900 that never existed; days before it start one day later.
      base = DateTime.utc(1899, 12, 31);
    } else {
      base = DateTime.utc(1899, 12, 30);
    }
    final date = base.add(Duration(days: wholeDays, milliseconds: millis));
    final totalSeconds = (serial * 86400).round();

    final tokens = _dateTokens(section);
    final hasAmPm = tokens.any((t) => t.kind == 'ampm');

    // An "m" next to an hour or a second means minutes, otherwise month.
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].kind != 'm' || tokens[i].count > 2) continue;
      String? before;
      for (var j = i - 1; j >= 0; j--) {
        if (tokens[j].kind != 'literal') {
          before = tokens[j].kind;
          break;
        }
      }
      String? after;
      for (var j = i + 1; j < tokens.length; j++) {
        if (tokens[j].kind != 'literal') {
          after = tokens[j].kind;
          break;
        }
      }
      if (before == 'h' || after == 's') tokens[i] = _DateToken('minute', tokens[i].count, elapsed: tokens[i].elapsed);
    }

    String two(int value) => value.toString().padLeft(2, '0');
    final out = StringBuffer();
    for (final token in tokens) {
      switch (token.kind) {
        case 'literal':
          out.write(token.text);
        case 'y':
          out.write(token.count <= 2 ? two(date.year % 100) : date.year.toString().padLeft(4, '0'));
        case 'm':
          final month = date.month;
          out.write(switch (token.count) {
            1 => '$month',
            2 => two(month),
            3 => _months[month - 1].substring(0, 3),
            4 => _months[month - 1],
            _ => _months[month - 1].substring(0, 1),
          });
        case 'd':
          out.write(switch (token.count) {
            1 => '${date.day}',
            2 => two(date.day),
            3 => _days[date.weekday - 1].substring(0, 3),
            _ => _days[date.weekday - 1],
          });
        case 'h':
          var hour = date.hour;
          if (token.elapsed) {
            hour = totalSeconds ~/ 3600;
          } else if (hasAmPm) {
            hour = hour % 12 == 0 ? 12 : hour % 12;
          }
          out.write(token.count >= 2 ? two(hour) : '$hour');
        case 'minute':
          final minute = token.elapsed ? totalSeconds ~/ 60 : date.minute;
          out.write(token.count >= 2 ? two(minute) : '$minute');
        case 's':
          final second = token.elapsed ? totalSeconds : date.second;
          out.write(token.count >= 2 ? two(second) : '$second');
        case 'fraction':
          final fraction = (date.millisecond / 1000).toStringAsFixed(token.count);
          out.write(fraction.substring(fraction.indexOf('.')));
        case 'ampm':
          final morning = date.hour < 12;
          out.write(token.count == 1 ? (morning ? 'A' : 'P') : (morning ? 'AM' : 'PM'));
      }
    }
    return out.toString();
  }

  static List<_DateToken> _dateTokens(String section) {
    final tokens = <_DateToken>[];
    var i = 0;
    while (i < section.length) {
      final char = section[i];
      final lower = char.toLowerCase();
      if (char == '"') {
        final end = section.indexOf('"', i + 1);
        tokens.add(_DateToken.literal(section.substring(i + 1, end < 0 ? section.length : end)));
        i = end < 0 ? section.length : end + 1;
      } else if (char == '\\') {
        if (i + 1 < section.length) tokens.add(_DateToken.literal(section[i + 1]));
        i += 2;
      } else if (char == '_') {
        tokens.add(_DateToken.literal(' '));
        i += 2;
      } else if (char == '*') {
        i += 2;
      } else if (char == '[') {
        final end = section.indexOf(']', i + 1);
        final inner = section.substring(i + 1, end < 0 ? section.length : end).toLowerCase();
        if (RegExp(r'^(h+|m+|s+)$').hasMatch(inner)) {
          final kind = inner[0] == 'm' ? 'minute' : inner[0];
          tokens.add(_DateToken(kind, inner.length, elapsed: true));
        }
        i = end < 0 ? section.length : end + 1;
      } else if (section.substring(i).toUpperCase().startsWith('AM/PM')) {
        tokens.add(const _DateToken('ampm', 2));
        i += 5;
      } else if (section.substring(i).toUpperCase().startsWith('A/P')) {
        tokens.add(const _DateToken('ampm', 1));
        i += 3;
      } else if ('ymdhs'.contains(lower) || lower == 'e') {
        var count = 0;
        while (i < section.length && section[i].toLowerCase() == lower) {
          count++;
          i++;
        }
        tokens.add(lower == 'e' ? const _DateToken('y', 4) : _DateToken(lower, count));
      } else if (char == '.' && i + 1 < section.length && section[i + 1] == '0' && tokens.isNotEmpty && tokens.last.kind == 's') {
        var count = 0;
        i++;
        while (i < section.length && section[i] == '0') {
          count++;
          i++;
        }
        tokens.add(_DateToken('fraction', count));
      } else {
        tokens.add(_DateToken.literal(char));
        i++;
      }
    }
    return tokens;
  }
}

class _DateToken {
  const _DateToken(this.kind, this.count, {this.elapsed = false}) : text = '';
  const _DateToken.literal(this.text)
      : kind = 'literal',
        count = 0,
        elapsed = false;

  final String kind;
  final int count;
  final bool elapsed;
  final String text;
}
