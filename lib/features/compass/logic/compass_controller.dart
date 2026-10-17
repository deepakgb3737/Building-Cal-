class CompassController {
  double? heading;
  double? _lastForTurn;
  double turns = 0;

  double smooth(double next) {
    if (heading == null) return next;
    final prev = heading!;
    final delta = ((next - prev + 540) % 360) - 180;
    return (prev + (delta * 0.22) + 360) % 360;
  }

  String cardinal(double deg) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = (((deg + 22.5) % 360) / 45).floor();
    return labels[index];
  }

  String fullCardinal(String short) {
    switch (short) {
      case 'N':
        return 'North';
      case 'NE':
        return 'North East';
      case 'E':
        return 'East';
      case 'SE':
        return 'South East';
      case 'S':
        return 'South';
      case 'SW':
        return 'South West';
      case 'W':
        return 'West';
      case 'NW':
        return 'North West';
      default:
        return short;
    }
  }

  void updateTurns(double heading) {
    if (_lastForTurn == null) {
      turns = -heading / 360.0;
      _lastForTurn = heading;
      return;
    }
    final delta = ((heading - _lastForTurn! + 540) % 360) - 180;
    turns -= delta / 360.0;
    _lastForTurn = heading;
  }
}
