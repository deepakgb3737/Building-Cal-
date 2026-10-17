import 'dart:math' as math;
import 'ceiling_material_service.dart';

enum PlacementMode {
  centerBased,
  oneSide,
}

class GridCeilingResult {
  static const int tileSizeMm = 595;

  final PlacementMode placementMode;
  final double tPlacementWidth;
  final double tPlacementLength;
  final List<double> mainRunnersWidth;
  final List<double> crossTLength;
  final List<double> twoFootCrossT;
  final int mainRunnerPieces;
  final int numFourFootT;
  final int numTwoFootCrossT;
  final int optimizedFourFootT;
  final int optimizedTwoFootCrossT;
  final int savedFourFootT;
  final bool edgeUsesTwoFootLeft;
  final bool edgeUsesTwoFootRight;
  final int tilesRequired;
  final int fullTilesRequired;
  final int cutTilesRequired;
  final int optimizedTilesRequired;
  final int widthEdgeCutSizeMm;
  final int widthEdgeCutPieces;
  final int lengthEdgeCutSizeMm;
  final int lengthEdgeCutPieces;
  final int cornerOverlapPieces;
  final int numMainRunners;
  final int numCrossT;

  GridCeilingResult({
    required this.placementMode,
    required this.tPlacementWidth,
    required this.tPlacementLength,
    required this.mainRunnersWidth,
    required this.crossTLength,
    required this.twoFootCrossT,
    required this.mainRunnerPieces,
    required this.numFourFootT,
    required this.numTwoFootCrossT,
    required this.optimizedFourFootT,
    required this.optimizedTwoFootCrossT,
    required this.savedFourFootT,
    required this.edgeUsesTwoFootLeft,
    required this.edgeUsesTwoFootRight,
    required this.tilesRequired,
    required this.fullTilesRequired,
    required this.cutTilesRequired,
    required this.optimizedTilesRequired,
    required this.widthEdgeCutSizeMm,
    required this.widthEdgeCutPieces,
    required this.lengthEdgeCutSizeMm,
    required this.lengthEdgeCutPieces,
    required this.cornerOverlapPieces,
    required this.numMainRunners,
    required this.numCrossT,
  });
}

class GridCeilingCalculator {
  static const double _gridSpacingMm = 600.0;
  static const double _fourFootLengthMm = 1200.0;

  // Function to calculate the center-based T placement
  static double calculateTPlacement(double size) {
    double center = size / 2; // Find the initial center
    while (center > _gridSpacingMm) {
      center -= _gridSpacingMm; // Deduct 600 mm
    }
    if (center < 300) {
      center += 300; // Add 300 mm if below 300 mm
    }
    return double.parse(
        center.toStringAsFixed(1)); // Return rounded center value
  }

  // Function to calculate main runner placements along width
  static List<double> calculateMainRunners(double center, double roomWidth) {
    List<double> mains = [center]; // Start with the first main runner
    double step = 1200; // Spacing between main runners
    double currentCenter = center;

    // Add additional runners until it reaches or exceeds room width
    while (currentCenter + step <= roomWidth) {
      currentCenter += step;
      mains.add(currentCenter);
    }

    return mains; // Return sorted positions (they're already sorted)
  }

  // Place main runners from one side wall: 1200, 2400, 3600...
  static List<double> calculateMainRunnersOneSide(double roomWidth) {
    final mains = <double>[];
    double position = 1200;
    while (position < roomWidth) {
      mains.add(position);
      position += 1200;
    }
    return mains;
  }

  // Function to calculate 4ft cross T placements along the length
  static List<double> calculateCrossT(double startPosition, double roomLength) {
    List<double> crossTs = [
      startPosition
    ]; // Start at the length's first T placement
    double step = 600; // 4ft cross T spacing is 600mm
    step = _gridSpacingMm;

    while (crossTs.last + step < roomLength) {
      // Use '<' instead of '<='
      crossTs.add(crossTs.last + step);
    }

    return crossTs; // Return sorted positions (they're already sorted)
  }

  // 4ft cross Ts from one wall: 600, 1200, 1800...
  static List<double> calculateCrossTOneSide(double roomLength) {
    final crossTs = <double>[];
    double position = 600;
    position = _gridSpacingMm;
    while (position < roomLength) {
      crossTs.add(position);
      position += 600;
    }
    return crossTs;
  }

  // Function to calculate 2ft cross T placements along the width only
  static List<double> calculateTwoFootCrossT(
      double tPlacementWidth, double roomWidth) {
    // First 2ft cross T position starts after the initial tile width (600mm)
    double firstPosition = tPlacementWidth + _gridSpacingMm;
    List<double> twoFootTs = [firstPosition];
    double step = 1200; // 2ft cross T spacing matches main runners (1200mm)

    // Add more 2ft cross Ts until the next step would exceed room width
    while (twoFootTs.last + step < roomWidth) {
      // Changed '<=' to '<'
      twoFootTs.add(twoFootTs.last + step);
    }

    return twoFootTs; // Return list of positions
  }

  // 2ft cross Ts from one wall: 600, 1800, 3000...
  static List<double> calculateTwoFootCrossTOneSide(double roomWidth) {
    final twoFootTs = <double>[];
    double position = 600;
    position = _gridSpacingMm;
    while (position < roomWidth) {
      twoFootTs.add(position);
      position += 1200;
    }
    return twoFootTs;
  }

  // Function to calculate number of 2ft required
  static int calculateTwoFootCrossTCount(
      List<double> twoFootCrossT, List<double> crossTLength) {
    int numColumns =
        twoFootCrossT.length; // Dynamically get 2ft Cross T columns
    int numRows = crossTLength.length +
        1; // Dynamically get rows of 4ft Cross Ts + 1 extra row
    return numColumns * numRows;
  }

  // Function to calculate number of 4ft T required
  static int calculateFourFootTCount(
      List<double> mainRunnersWidth, List<double> crossTLength) {
    int numTBarsPerRow =
        mainRunnersWidth.length + 1; // T-bars are placed between main runners
    int numRows = crossTLength.length; // Number of rows along the length

    return numTBarsPerRow * numRows; // Total 4ft T-bars required
  }

  static ({
    int optimizedFourFoot,
    int optimizedTwoFoot,
    int savedFourFoot,
    bool leftEdgeUsesTwoFoot,
    bool rightEdgeUsesTwoFoot,
  }) _optimizeFourFootAtEdges({
    required double roomWidth,
    required List<double> mainRunnersWidth,
    required List<double> crossTLength,
    required int baseFourFootCount,
    required int baseTwoFootCount,
  }) {
    if (mainRunnersWidth.isEmpty || crossTLength.isEmpty) {
      return (
        optimizedFourFoot: baseFourFootCount,
        optimizedTwoFoot: baseTwoFootCount,
        savedFourFoot: 0,
        leftEdgeUsesTwoFoot: false,
        rightEdgeUsesTwoFoot: false,
      );
    }

    final leftEdgeBay = mainRunnersWidth.first;
    final rightEdgeBay = roomWidth - mainRunnersWidth.last;
    final rows = crossTLength.length;

    // Optimization rule:
    // If edge bay is a cut (<1200) and <=600, use 2ft instead of 4ft.
    final leftReplace = leftEdgeBay > 0 &&
        leftEdgeBay < _fourFootLengthMm &&
        leftEdgeBay <= 600;
    final rightReplace = rightEdgeBay > 0 &&
        rightEdgeBay < _fourFootLengthMm &&
        rightEdgeBay <= 600;

    final replacementsPerRow = (leftReplace ? 1 : 0) + (rightReplace ? 1 : 0);
    final totalReplacements = replacementsPerRow * rows;

    return (
      optimizedFourFoot: baseFourFootCount - totalReplacements,
      optimizedTwoFoot: baseTwoFootCount + totalReplacements,
      savedFourFoot: totalReplacements,
      leftEdgeUsesTwoFoot: leftReplace,
      rightEdgeUsesTwoFoot: rightReplace,
    );
  }

  static int _sourceTilesForEdgeCuts({
    required int pieceCount,
    required double cutWidthMm,
    required double tileSizeMm,
  }) {
    if (pieceCount <= 0 || cutWidthMm <= 0) {
      return 0;
    }
    final stripsPerTile = math.max(1, (tileSizeMm / cutWidthMm).floor());
    return (pieceCount / stripsPerTile).ceil();
  }

  static List<double> _buildModuleSegments({
    required double sizeMm,
    required double firstSegmentMm,
  }) {
    if (sizeMm <= 0) {
      return const [];
    }

    if (firstSegmentMm <= 0 || firstSegmentMm >= sizeMm) {
      return [sizeMm];
    }

    final segments = <double>[firstSegmentMm];
    var current = firstSegmentMm;
    while (current + _gridSpacingMm < sizeMm) {
      segments.add(_gridSpacingMm);
      current += _gridSpacingMm;
    }

    final tail = sizeMm - current;
    if (tail > 0) {
      segments.add(tail);
    }
    return segments;
  }

  // Main calculation function
  static GridCeilingResult calculate(
    double width,
    double length, {
    PlacementMode mode = PlacementMode.centerBased,
  }) {
    // Calculate T placements
    double tPlacementWidth = calculateTPlacement(width); // For main runners
    double tPlacementLength = calculateTPlacement(length); // For cross Ts

    // Tile module segmentation (600 grid with center/one-side start).
    final firstWidthSegment =
        mode == PlacementMode.oneSide ? _gridSpacingMm : tPlacementWidth;
    final firstLengthSegment =
        mode == PlacementMode.oneSide ? _gridSpacingMm : tPlacementLength;
    final widthSegments = _buildModuleSegments(
      sizeMm: width,
      firstSegmentMm: firstWidthSegment,
    );
    final lengthSegments = _buildModuleSegments(
      sizeMm: length,
      firstSegmentMm: firstLengthSegment,
    );

    final tileSize = GridCeilingResult.tileSizeMm.toDouble();
    final tilesRequired = widthSegments.length * lengthSegments.length;
    final fullTilesAcrossWidth =
        widthSegments.where((s) => s >= tileSize).length;
    final fullTilesAcrossLength =
        lengthSegments.where((s) => s >= tileSize).length;
    final fullTilesRequired = fullTilesAcrossWidth * fullTilesAcrossLength;
    final cutTilesRequired = tilesRequired - fullTilesRequired;

    final leftWidth = widthSegments.isNotEmpty ? widthSegments.first : 0.0;
    final rightWidth = widthSegments.isNotEmpty ? widthSegments.last : 0.0;
    final topLength = lengthSegments.isNotEmpty ? lengthSegments.first : 0.0;
    final bottomLength = lengthSegments.isNotEmpty ? lengthSegments.last : 0.0;

    final leftCut = leftWidth < tileSize;
    final rightCut = rightWidth < tileSize;
    final topCut = topLength < tileSize;
    final bottomCut = bottomLength < tileSize;

    final widthCutSides = (leftCut ? 1 : 0) + (rightCut ? 1 : 0);
    final lengthCutSides = (topCut ? 1 : 0) + (bottomCut ? 1 : 0);
    final widthEdgeCutSizeMm =
        leftCut ? leftWidth.round() : (rightCut ? rightWidth.round() : 0);
    final lengthEdgeCutSizeMm =
        topCut ? topLength.round() : (bottomCut ? bottomLength.round() : 0);
    final widthEdgeCutPieces = widthCutSides * lengthSegments.length;
    final lengthEdgeCutPieces = lengthCutSides * widthSegments.length;
    final cornerOverlapPieces = widthCutSides * lengthCutSides;

    // Optimized source tiles required for cut pieces.
    final widthStripsPerTile = widthEdgeCutPieces > 0
        ? math.max(1, (tileSize / widthEdgeCutSizeMm).floor())
        : 0;
    final lengthStripsPerTile = lengthEdgeCutPieces > 0
        ? math.max(1, (tileSize / lengthEdgeCutSizeMm).floor())
        : 0;
    final widthCutSourceTiles = _sourceTilesForEdgeCuts(
      pieceCount: widthEdgeCutPieces,
      cutWidthMm: widthEdgeCutSizeMm.toDouble(),
      tileSizeMm: tileSize,
    );
    final lengthCutSourceTiles = _sourceTilesForEdgeCuts(
      pieceCount: lengthEdgeCutPieces,
      cutWidthMm: lengthEdgeCutSizeMm.toDouble(),
      tileSizeMm: tileSize,
    );
    final spareWidthStrips =
        (widthCutSourceTiles * widthStripsPerTile) - widthEdgeCutPieces;
    final spareLengthStrips =
        (lengthCutSourceTiles * lengthStripsPerTile) - lengthEdgeCutPieces;
    final cornerCoveredBySpare = cornerOverlapPieces == 0
        ? true
        : (spareWidthStrips > 0 || spareLengthStrips > 0);
    final cornerExtraSourceTile = cornerCoveredBySpare ? 0 : 1;

    final optimizedTilesRequired = fullTilesRequired +
        widthCutSourceTiles +
        lengthCutSourceTiles +
        cornerExtraSourceTile;

    // Determine placement of main 10ft T-channels along width
    final List<double> mainRunnersWidth = mode == PlacementMode.oneSide
        ? calculateMainRunnersOneSide(width)
        : calculateMainRunners(tPlacementWidth, width);

    // Determine placement of 4ft cross T-channels along length side
    final List<double> crossTLength = mode == PlacementMode.oneSide
        ? calculateCrossTOneSide(length)
        : calculateCrossT(tPlacementLength, length);

    // Determine placement of 2ft cross Ts - using tPlacementWidth, not hardcoded value
    final List<double> twoFootCrossT = mode == PlacementMode.oneSide
        ? calculateTwoFootCrossTOneSide(width)
        : calculateTwoFootCrossT(tPlacementWidth, width);

    // Calculate quantities
    int numMainRunners = mainRunnersWidth.length;
    int numCrossT = crossTLength.length * (numMainRunners + 1);
    int numTwoFootCrossT =
        calculateTwoFootCrossTCount(twoFootCrossT, crossTLength);

    // Calculate the required number of 4ft cross T-bars
    int numFourFootT = calculateFourFootTCount(mainRunnersWidth, crossTLength);
    final tOptimization = _optimizeFourFootAtEdges(
      roomWidth: width,
      mainRunnersWidth: mainRunnersWidth,
      crossTLength: crossTLength,
      baseFourFootCount: numFourFootT,
      baseTwoFootCount: numTwoFootCrossT,
    );

    // Calculate stock pieces using the supplied 3048 mm formula
    int mainRunnerPieces =
        ((length * numMainRunners) / CeilingMaterialService.runnerLengthMm)
            .ceil();

    return GridCeilingResult(
      placementMode: mode,
      tPlacementWidth: tPlacementWidth,
      tPlacementLength: tPlacementLength,
      mainRunnersWidth: mainRunnersWidth,
      crossTLength: crossTLength,
      twoFootCrossT: twoFootCrossT,
      mainRunnerPieces: mainRunnerPieces,
      numFourFootT: numFourFootT,
      numTwoFootCrossT: numTwoFootCrossT,
      optimizedFourFootT: tOptimization.optimizedFourFoot,
      optimizedTwoFootCrossT: tOptimization.optimizedTwoFoot,
      savedFourFootT: tOptimization.savedFourFoot,
      edgeUsesTwoFootLeft: tOptimization.leftEdgeUsesTwoFoot,
      edgeUsesTwoFootRight: tOptimization.rightEdgeUsesTwoFoot,
      tilesRequired: tilesRequired,
      fullTilesRequired: fullTilesRequired,
      cutTilesRequired: cutTilesRequired,
      optimizedTilesRequired: optimizedTilesRequired,
      widthEdgeCutSizeMm: widthEdgeCutSizeMm,
      widthEdgeCutPieces: widthEdgeCutPieces,
      lengthEdgeCutSizeMm: lengthEdgeCutSizeMm,
      lengthEdgeCutPieces: lengthEdgeCutPieces,
      cornerOverlapPieces: cornerOverlapPieces,
      numMainRunners: numMainRunners,
      numCrossT: numCrossT,
    );
  }
}
