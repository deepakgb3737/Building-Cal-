import 'dart:math' as math;

class CalculatorEngine {
  static double? tryEvaluate(String expression) {
    if (expression.length > 512) return null;
    try {
      final parser = _ExpressionParser(expression);
      final value = parser.expression();
      if (parser.position != parser.source.length || !value.isFinite) {
        return null;
      }
      return value;
    } on FormatException {
      return null;
    }
  }

  static String formatResult(double value) {
    if (!value.isFinite) return 'Error';
    if (value == 0) return '0';
    if (value.abs() >= 1e12 || value.abs() < 1e-8) {
      return value.toStringAsExponential(8);
    }
    return value.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _ExpressionParser {
  _ExpressionParser(String input)
      : source = input
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll('×', '*')
            .replaceAll('÷', '/');

  final String source;
  int position = 0;

  double checked(double value) {
    if (!value.isFinite) throw const FormatException('Number out of range');
    return value;
  }

  bool take(String token) {
    if (!source.startsWith(token, position)) return false;
    position += token.length;
    return true;
  }

  double expression() {
    var value = product();
    while (position < source.length) {
      if (take('+')) {
        value = checked(value + product());
      } else if (take('-')) {
        value = checked(value - product());
      } else {
        break;
      }
    }
    return value;
  }

  double product() {
    var value = unary();
    while (position < source.length) {
      if (take('*')) {
        value = checked(value * unary());
      } else if (take('/')) {
        final divisor = unary();
        if (divisor == 0) throw const FormatException('Division by zero');
        value = checked(value / divisor);
      } else {
        break;
      }
    }
    return checked(value);
  }

  double unary() {
    if (take('-')) return -unary();
    if (take('+')) return unary();
    return power();
  }

  double power() {
    var value = primary();
    while (take('%')) {
      value /= 100;
    }
    if (take('^')) value = math.pow(value, unary()).toDouble();
    return checked(value);
  }

  double primary() {
    if (take('sqrt(')) {
      final value = expression();
      if (!take(')') || value < 0) throw const FormatException('Invalid root');
      return math.sqrt(value);
    }
    if (take('(')) {
      final value = expression();
      if (!take(')')) throw const FormatException('Missing parenthesis');
      return value;
    }
    final match = RegExp(r'(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?')
        .matchAsPrefix(source, position);
    if (match == null) throw const FormatException('Expected number');
    position = match.end;
    return checked(double.parse(match.group(0)!));
  }
}
