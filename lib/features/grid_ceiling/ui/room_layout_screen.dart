import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/ceiling_material_service.dart';
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';

class RoomLayoutScreen extends StatelessWidget {
  final GridCeilingResult result;
  final double width;
  final double length;

  const RoomLayoutScreen({
    super.key,
    required this.result,
    required this.width,
    required this.length,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ceiling Layout Guide'),
        backgroundColor: AppColors.legacyBlue,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildRoomLayout(),
            const SizedBox(height: 30),
            _buildInfoContainer(),
            const SizedBox(height: 30),
            _buildTPlacements(),
            const SizedBox(height: 30),
            _buildInstallationNotes(),
            const SizedBox(height: 20),
            _buildNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r8,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ceiling Guide by InsulateBuilding.com',
            style: AppTypography.text24BoldDrawingink,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomLayout() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r8,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Room Layout',
            style: AppTypography.text20BoldDrawingink,
          ),
          const SizedBox(height: 20),
          _buildRoomVisualization(),
        ],
      ),
    );
  }

  Widget _buildRoomVisualization() {
    const scale = 10.0;

    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.drawingInk, width: 3),
        color: AppColors.neutralSurface,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Wall angles
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 4,
            child: Container(color: AppColors.wallAngle),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 4,
            child: Container(color: AppColors.wallAngle),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 4,
            child: Container(color: AppColors.wallAngle),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 4,
            child: Container(color: AppColors.wallAngle),
          ),
          // Main runners
          ...result.mainRunnersWidth.map((pos) => Positioned(
                left: (pos / scale) - 1,
                top: 0,
                bottom: 0,
                width: 2,
                child: Container(color: AppColors.mainRunner),
              )),
          // Cross Ts
          ...result.crossTLength.expand((pos) {
            final top = (pos / scale) - 1;
            final hasMain = result.mainRunnersWidth.isNotEmpty;
            final firstMain =
                hasMain ? (result.mainRunnersWidth.first / scale) : 0.0;
            final lastMain = hasMain
                ? (result.mainRunnersWidth.last / scale)
                : (width / scale);
            final centerSpanStart =
                result.edgeUsesTwoFootLeft && hasMain ? firstMain : 0.0;
            final centerSpanEnd = result.edgeUsesTwoFootRight && hasMain
                ? lastMain
                : (width / scale);
            final widgets = <Widget>[];

            if (result.edgeUsesTwoFootLeft && hasMain && firstMain > 0) {
              widgets.add(Positioned(
                top: top,
                left: 0,
                width: firstMain,
                height: 2,
                child: Container(color: AppColors.shortRunner),
              ));
            }

            widgets.add(Positioned(
              top: top,
              left: centerSpanStart,
              width: centerSpanEnd - centerSpanStart,
              height: 2,
              child: Container(color: AppColors.crossRunner),
            ));

            if (result.edgeUsesTwoFootRight &&
                hasMain &&
                lastMain < (width / scale)) {
              widgets.add(Positioned(
                top: top,
                left: lastMain,
                width: (width / scale) - lastMain,
                height: 2,
                child: Container(color: AppColors.shortRunner),
              ));
            }

            return widgets;
          }),
          // 2ft Cross Ts
          ...result.twoFootCrossT.map((pos) => Positioned(
                left: (pos / scale) - 1,
                top: 0,
                bottom: 0,
                width: 2,
                child: Container(color: AppColors.shortRunner),
              )),
          // Dimension labels
          Positioned(
            bottom: -30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Width: ${width.toInt()} mm',
                style: AppTypography.text14BoldDrawingink,
              ),
            ),
          ),
          Positioned(
            right: -95,
            top: 0,
            bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'Length: ${length.toInt()} mm',
                  style: AppTypography.text14BoldDrawingink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoContainer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildLegend()),
        const SizedBox(width: 20),
        Expanded(child: _buildMaterialRequirements()),
        const SizedBox(width: 20),
        Expanded(child: _buildCuttingGuide()),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r8,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ceiling Layout Guide',
            style: AppTypography.text18BoldDrawingink,
          ),
          const SizedBox(height: 15),
          _buildLegendItem(AppColors.mainRunner, 'Main Runners (10ft T-Bar)'),
          _buildLegendItem(AppColors.crossRunner, 'Cross Tees (4\' T-Bar)'),
          _buildLegendItem(
              AppColors.shortRunner, 'Short Cross Tees (2\' T-Bar)'),
          _buildLegendItem(AppColors.wallAngle, 'Wall Angle (10\' L-Angle)'),
          _buildLegendItem(AppColors.mainRunner,
              'Main Runner Joint (10ft T-Bar Connection Point)'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadii.r4,
              border: Border.all(color: AppColors.grey.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.text14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialRequirements() {
    final wallAnglePieces =
        CeilingMaterialService.wallAnglePieces(width, length);
    final hangerWires = CeilingMaterialService.hangerWires(width, length);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r8,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Material Requirements',
            style: AppTypography.text18BoldDrawingink,
          ),
          const SizedBox(height: 15),
          _buildRequirementItem(
              '10ft Main Runners:', '${result.mainRunnerPieces} pieces'),
          _buildRequirementItem('4ft Cross Ts (Optimized):',
              '${result.optimizedFourFootT} pieces'),
          _buildRequirementItem('2ft Cross Ts (Optimized):',
              '${result.optimizedTwoFootCrossT} pieces'),
          _buildRequirementItem('4ft Saved by Edge Optimization:',
              '${result.savedFourFootT} pieces'),
          _buildRequirementItem(
              'Ceiling Tiles (${GridCeilingResult.tileSizeMm}x${GridCeilingResult.tileSizeMm} mm):',
              '${result.tilesRequired} pieces'),
          _buildRequirementItem(
              'Full Tiles:', '${result.fullTilesRequired} pieces'),
          _buildRequirementItem(
              'Cut Tiles (Edge):', '${result.cutTilesRequired} pieces'),
          if (result.widthEdgeCutPieces > 0)
            _buildRequirementItem(
                'Width Edge Cut (${result.widthEdgeCutSizeMm}mm):',
                '${result.widthEdgeCutPieces} pieces'),
          if (result.lengthEdgeCutPieces > 0)
            _buildRequirementItem(
                'Length Edge Cut (${result.lengthEdgeCutSizeMm}mm):',
                '${result.lengthEdgeCutPieces} pieces'),
          if (result.cornerOverlapPieces > 0)
            _buildRequirementItem('Corner Overlap (double-count):',
                '${result.cornerOverlapPieces} pieces'),
          _buildRequirementItem('Tiles to Purchase (Optimized):',
              '${result.optimizedTilesRequired} pieces'),
          _buildRequirementItem(
              'Wall Angle Molding:', '$wallAnglePieces pieces'),
          _buildRequirementItem('Hanger Wires:', '$hangerWires pieces'),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text('🔹', style: AppTypography.text16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.text14W500,
            ),
          ),
          Text(
            value,
            style: AppTypography.text14BoldDrawingink,
          ),
        ],
      ),
    );
  }

  Widget _buildCuttingGuide() {
    final remainingLength = CeilingMaterialService.runnerCutMm(length);
    final fullPieces = CeilingMaterialService.fullRunnerPieces(length);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r8,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '10ft Main Runner Cutting Guide',
            style: AppTypography.text18BoldDrawingink,
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: AppColors.drawingSurface,
              borderRadius: AppRadii.r6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Main Runner Layout (Per Row)',
                  style: AppTypography.text16BoldDrawingink,
                ),
                const SizedBox(height: 10),
                Text('Room Length: ${length.toInt()}mm'),
                Text('Full 10ft Runner (3048mm) × $fullPieces pieces'),
                if (remainingLength > 0)
                  Text('Cut Piece: ${remainingLength.toInt()}mm × 1 piece'),
                Text('Total Rows: ${result.numMainRunners}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildCuttingDiagram(fullPieces, remainingLength),
          const SizedBox(height: 20),
          _buildCuttingNotes(fullPieces, remainingLength),
        ],
      ),
    );
  }

  Widget _buildCuttingDiagram(int fullPieces, double remainingLength) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.drawingSurface,
        borderRadius: AppRadii.r6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Layout Example:',
            style: AppTypography.text16BoldDrawingink,
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Wall indicator left
                Container(
                  width: 4,
                  height: 40,
                  color: AppColors.wallAngle,
                ),
                // Full runners
                ...List.generate(
                    fullPieces,
                    (index) => Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 8,
                                color: AppColors.mainRunner,
                                child: const Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: -15,
                                      child: Text('⚡',
                                          style:
                                              AppTypography.text16Mainrunner),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text('3048mm (10ft)',
                                  style: AppTypography.text12),
                            ],
                          ),
                        )),
                // Cut piece if needed
                if (remainingLength > 0) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Column(
                      children: [
                        Container(
                          width: (remainingLength /
                                  CeilingMaterialService.runnerLengthMm) *
                              100,
                          height: 8,
                          color: AppColors.mainRunner,
                          child: Stack(
                            children: [
                              const Positioned(
                                left: 0,
                                top: -15,
                                child: Text('⚡',
                                    style: AppTypography.text16Mainrunner),
                              ),
                              Positioned(
                                right: -20,
                                top: -15,
                                child: Transform.rotate(
                                  angle: 0.785398, // 45 degrees
                                  child: const Text('✂️',
                                      style: AppTypography.text16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text('${remainingLength.toInt()}mm',
                            style: AppTypography.text12),
                      ],
                    ),
                  ),
                ],
                // Wall indicator right
                Container(
                  width: 4,
                  height: 40,
                  color: AppColors.wallAngle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuttingNotes(int fullPieces, double remainingLength) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.orangeSurface,
        border: Border.all(color: AppColors.wallAngle, width: 4),
        borderRadius: AppRadii.r4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Installation Notes:',
            style: AppTypography.text16BoldDrawingink,
          ),
          const SizedBox(height: 10),
          ...[
            'Each row requires $fullPieces full 10ft runners (3048mm)',
            if (remainingLength > 0)
              'Plus one cut piece of ${remainingLength.toInt()}mm at the end',
            'Total ${result.numMainRunners} rows needed for the room',
            '⚡ symbols show where runners connect',
            '✂️ shows where to cut the last piece',
          ].map((note) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: AppTypography.textDrawingink),
                    Expanded(
                        child:
                            Text(note, style: AppTypography.textDrawingtext)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTPlacements() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r8,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'T PLACEMENTS',
            style: AppTypography.text18BoldDrawingink,
          ),
          const SizedBox(height: 15),
          _buildPlacementSection('For Width:', [
            'First T placement at: ${result.tPlacementWidth} mm',
            'Main 10ft T-channels required along width: ${result.mainRunnersWidth.join(', ')} mm',
            '2ft Cross T placement along width: ${result.twoFootCrossT.join(', ')} mm',
          ]),
          const SizedBox(height: 15),
          _buildPlacementSection('For Length:', [
            'First T placement at: ${result.tPlacementLength} mm',
            '4ft Cross T placement along length side: ${result.crossTLength.join(', ')} mm',
          ]),
        ],
      ),
    );
  }

  Widget _buildPlacementSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.text16BoldDrawingink,
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                item,
                style: AppTypography.text14Drawingtext,
              ),
            )),
      ],
    );
  }

  Widget _buildInstallationNotes() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadii.r8,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSTALLATION NOTES:',
            style: AppTypography.text18BoldDrawingink,
          ),
          const SizedBox(height: 15),
          ...[
            'Install 10\' wall angle molding around the entire perimeter at the specified ceiling height.',
            'Main runners should be hung with 12-gauge wire at 4\' intervals.',
            'Ensure grid is level and square before installing ceiling panels.',
            '2-foot cross Ts should be installed between 4-foot cross Ts at every other main runner spacing.',
            'All measurements are in millimeters unless otherwise noted.',
          ].map((note) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: AppTypography.textDrawingink),
                    Expanded(
                        child:
                            Text(note, style: AppTypography.textDrawingtext)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.yellowSurface,
        border: Border.all(color: AppColors.yellow, width: 4),
        borderRadius: AppRadii.r4,
      ),
      child: const Text(
        'Note: The cross T calculation is an approximation and should be verified manually. The exact number may vary based on actual installation conditions.',
        style: AppTypography.text14Drawingtext,
      ),
    );
  }
}
