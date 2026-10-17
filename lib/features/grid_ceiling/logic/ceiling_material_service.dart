class CeilingMaterialService {
  static const runnerLengthMm = 3048.0;
  static const runnerLabel = '10ft';
  static const runnerShortLabel = '10f';

  static int wallAnglePieces(double width, double length) =>
      (2 * (width + length) / runnerLengthMm).ceil();

  static int hangerWires(double width, double length) =>
      (2 * (width + length) / 1200).ceil();

  static int fullRunnerPieces(double length) =>
      (length / runnerLengthMm).floor();

  static double runnerCutMm(double length) => length % runnerLengthMm;
}
