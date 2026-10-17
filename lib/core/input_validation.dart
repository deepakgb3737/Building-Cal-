class InputValidation {
  static String? positiveNumber(String? value) {
    final error = nonNegativeNumber(value);
    if (error != null) return error;
    return double.parse(value!.trim()) <= 0 ? 'Must be greater than 0' : null;
  }

  static String? nonNegativeNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite) return 'Enter numeric value';
    return parsed < 0 ? 'Cannot be negative' : null;
  }

  static String? positiveCount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter whole number';
    return parsed <= 0 ? 'Must be greater than 0' : null;
  }

  static String? roomDimension(String? value, String axis) {
    if (value == null || value.isEmpty) {
      return 'Please enter room ${axis.toLowerCase()} in mm';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Only numeric numbers are allowed';
    }
    final number = int.tryParse(value);
    if (number == null) return 'Only numeric numbers are allowed';
    if (number < 800 || number > 40000) {
      return "We can't calculate. $axis must be 800 to 40000 mm.";
    }
    return null;
  }
}
