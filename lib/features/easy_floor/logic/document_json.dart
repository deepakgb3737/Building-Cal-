Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected an object.');
  }
  return value;
}

List<dynamic> jsonArray(Object? value, {int max = 10000}) {
  if (value is! List || value.length > max) {
    throw const FormatException('Invalid object list.');
  }
  return value;
}

double jsonNumber(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Invalid number.');
  }
  return value.toDouble();
}

int jsonInteger(Object? value, {bool positive = true}) {
  if (value is! int || (positive && value <= 0)) {
    throw const FormatException('Invalid identifier.');
  }
  return value;
}

bool jsonBoolean(Object? value) {
  if (value is! bool) throw const FormatException('Invalid boolean.');
  return value;
}

T jsonEnum<T extends Enum>(List<T> values, Object? value) =>
    values.firstWhere((e) => e.name == value,
        orElse: () => throw const FormatException('Unknown setting.'));
