import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/calculator/logic/calculator_engine.dart';

void main() {
  test('Arithmetic and advanced operations respect precedence', () {
    final cases = <String, double>{
      '2+3*4': 14,
      '(2+3)*4': 20,
      '200*10%': 20,
      '200+10%': 200.1,
      '3--2': 5,
      '2*-3': -6,
      '-2^2': -4,
      '(-2)^2': 4,
      '2^3^2': 512,
      'sqrt(81)': 9,
      '1/(4)': .25,
      '2^-2': .25,
      '1e-8*1e8': 1,
      '4×3÷2': 6,
    };
    for (final entry in cases.entries) {
      expect(
          CalculatorEngine.tryEvaluate(entry.key), closeTo(entry.value, 1e-10),
          reason: entry.key);
    }
  });

  test('Invalid input and nonfinite intermediate values are rejected', () {
    for (final input in [
      '',
      '1/0',
      'sqrt(-1)',
      '(2+3',
      '2(3)',
      '2abc+3',
      '1..2',
      '1e999',
      '1/(1e308*1e308)',
      '2^1024',
      '()'
    ]) {
      expect(CalculatorEngine.tryEvaluate(input), isNull, reason: input);
    }
    expect(CalculatorEngine.tryEvaluate('1' * 513), isNull);
  });

  test('Formatted results can be reused including scientific notation', () {
    for (final value in [0.0, -0.0, 12.5, 1e20, -1e-12]) {
      final text = CalculatorEngine.formatResult(value);
      expect(CalculatorEngine.tryEvaluate(text),
          closeTo(value, value.abs() * 1e-8 + 1e-20));
    }
  });
}
