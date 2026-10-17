import 'pvc_room.dart';

class PvcPlankSegment {
  const PvcPlankSegment(this.x0, this.x1, this.pieces);
  final double x0, x1;
  final List<double> pieces;
}

class PvcPlankRow {
  const PvcPlankRow(this.y0, this.y1, this.segments);
  final double y0, y1;
  final List<PvcPlankSegment> segments;
  double get width => y1 - y0;
}

/// Plank cover width: 300 mm (315 mm overall), in feet.
const double kPW = 300 / 304.8;

/// Saw blade width 1/8 in, in feet. Added to every cut.
const double kKerf = 0.125 / 12;

const double kEps = 1e-8;

/// Shortest piece allowed on a joint, in feet.
const double kMinPiece = 2;

class RowInfo {
  final int n;
  final double edge;
  final bool ok;
  final double score;
  const RowInfo(this.n, this.edge, this.ok, [this.score = 0]);
}

class PlanItem {
  final double stock;
  final List<int> counts;
  const PlanItem(this.stock, this.counts);
}

class Layout {
  final String dir;
  final double run;
  final double across;
  final int rowsCount;
  final RowInfo rows;
  final List<double> pcs;
  final List<double> sizes;
  final List<PlanItem> plan;
  final double total;
  final int joints;
  final List<PvcPoint> polygon;
  final List<PvcPlankRow> layoutRows;
  final double pieceTotal;

  const Layout({
    required this.dir,
    required this.run,
    required this.across,
    required this.rowsCount,
    required this.rows,
    required this.pcs,
    required this.sizes,
    required this.plan,
    required this.total,
    required this.joints,
    required this.polygon,
    required this.layoutRows,
    required this.pieceTotal,
  });

  int get count => plan.length;
  int get q10 => plan.where((p) => p.stock == 10).length;
  int get q12 => plan.where((p) => p.stock == 12).length;
  double get waste => total - pieceTotal;
  double get area => polygonArea(polygon);
  bool get turned => dir == 'width';
  bool get uniform {
    String signature(PvcPlankRow row) => row.segments
        .map((s) =>
            '${s.x0.toStringAsFixed(3)}:${s.x1.toStringAsFixed(3)}:${s.pieces}')
        .join('|');
    return layoutRows.every((r) => signature(r) == signature(layoutRows.first));
  }

  double get wastePercent => (waste / total * 1000).round() / 10;
  List<double> get rowWidths => layoutRows.map((r) => r.width).toList();
  int stockCount(double stock) => plan.where((p) => p.stock == stock).length;
  int wholeCount(double stock) => plan
      .where((p) =>
          p.stock == stock &&
          CutGroup(
                  p.stock,
                  [
                    for (var i = 0; i < p.counts.length; i++)
                      for (var j = 0; j < p.counts[i]; j++) sizes[i]
                  ],
                  1)
              .whole)
      .length;
}

class CutGroup {
  final double stock;
  final List<double> cuts;
  int q;
  CutGroup(this.stock, this.cuts, this.q);

  /// Piece offsets and tape readings in feet, including preceding blade cuts.
  List<({double start, double end})> get spans {
    var offset = 0.0;
    final result = <({double start, double end})>[];
    for (final cut in cuts) {
      final end = offset + cut;
      result.add((start: offset, end: end));
      offset = end + kKerf;
    }
    return result;
  }

  double get scrap {
    final l = stock - cuts.fold(0.0, (s, x) => s + x) - cuts.length * kKerf;
    return l > .02 ? l : 0;
  }

  /// A plank used whole needs no cutting.
  bool get whole => cuts.length == 1 && scrap == 0;
}
