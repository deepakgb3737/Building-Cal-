String fmt(double n) {
  var s = n.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

String _fraction(int parts, int denom) {
  if (parts == 0) return '';
  if (denom == 4) {
    return const {1: '¼', 2: '½', 3: '¾'}[parts] ?? '';
  }
  return const {
        1: '⅛',
        2: '¼',
        3: '⅜',
        4: '½',
        5: '⅝',
        6: '¾',
        7: '⅞',
      }[parts] ??
      '';
}

String _feetInches(double x, int denom) {
  final t = (x * 12 * denom).round() / denom;
  final f = (t / 12 + 1e-9).floor();
  final i = t - f * 12;
  final w = (i + 1e-9).floor();
  final q = ((i - w) * denom).round();
  final whole = q >= denom ? w + 1 : w;
  final part = q >= denom ? 0 : q;
  final sb = StringBuffer();
  if (f > 0) sb.write('$f ft');
  if (whole > 0 || part > 0) {
    if (f > 0) sb.write(' ');
    if (whole > 0) sb.write('$whole');
    sb.write(_fraction(part, denom));
    sb.write(' in');
  }
  final out = sb.toString();
  return out.isEmpty ? '0' : out;
}

/// Feet and inches to the nearest quarter inch, for sizes.
String ftin(double x) => _feetInches(x, 4);

/// Feet and inches to the nearest eighth inch, for tape measure readings.
String ftx(double x) => _feetInches(x, 8);
