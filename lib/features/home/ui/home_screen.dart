import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/grid_ceiling_screen.dart';
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/unit_converter/ui/unit_converter.dart';
import 'package:grid_ceiling_calculator/features/area_converter/ui/area_converter.dart';
import 'package:grid_ceiling_calculator/features/calculator/ui/basic_calculator.dart';
import 'package:grid_ceiling_calculator/features/compass/ui/compass_screen.dart';
import 'package:grid_ceiling_calculator/features/drawer/ui/drawer_calculator.dart';
import 'package:grid_ceiling_calculator/features/paint/ui/paint_screen.dart';
import 'package:grid_ceiling_calculator/features/flooring_tiles/ui/flooring_tile_screen.dart';
import 'package:grid_ceiling_calculator/features/concrete/ui/concrete_screen.dart';
import 'package:grid_ceiling_calculator/features/plaster/ui/plaster_screen.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showAppInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About BuildCalc',
                  style: AppTypography.text17W700Text,
                ),
                SizedBox(height: 10),
                Text(
                  'Built by inusltebuilding.com',
                  style: AppTypography.text14Secondarytext,
                ),
                SizedBox(height: 4),
                Text(
                  'Sirsi, Uttara Kannada',
                  style: AppTypography.text14Secondarytext,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = <_HomeTool>[
      _HomeTool(
        title: 'Grid Ceiling',
        asset: 'assets/icons/inside /grid_ceiling.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GridCeilingCalculatorScreen(),
            ),
          );
        },
      ),
      _HomeTool(
        title: 'PVC Ceiling',
        asset: 'assets/icons/inside /pvc_ceiling.png',
        tint: AppColors.primary,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PvcCeilingScreen())),
      ),
      _HomeTool(
        title: 'EasyFloor',
        asset: 'assets/icons/inside /easy_floor.png',
        tint: AppColors.primary,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const EasyFloorScreen())),
      ),
      _HomeTool(
        title: 'Unit Converter',
        asset: 'assets/icons/inside /unit_converter.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UnitConverterScreen(),
            ),
          );
        },
      ),
      _HomeTool(
        title: 'Area Converter',
        asset: 'assets/icons/inside /area_converter.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AreaConverterScreen(),
            ),
          );
        },
      ),
      _HomeTool(
        title: 'Calculator',
        asset: 'assets/icons/inside /calculator.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CalculatorScreen(),
            ),
          );
        },
      ),
      _HomeTool(
        title: 'Compass',
        asset: 'assets/icons/inside /compass.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CompassScreen(),
            ),
          );
        },
      ),
      _HomeTool(
        title: 'Drawer Calculator',
        asset: 'assets/icons/inside /drawer_calculator.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DrawerCalculatorScreen(),
            ),
          );
        },
      ),
      for (final tool in [
        (title: 'Paint', asset: 'paint', screen: const PaintScreen()),
        (
          title: 'Flooring Tiles',
          asset: 'flooring_tiles',
          screen: const FlooringTileScreen()
        ),
        (
          title: 'Concrete Volume',
          asset: 'concrete',
          screen: const ConcreteScreen()
        ),
        (
          title: 'Plaster',
          asset: 'wall_plaster',
          screen: const PlasterScreen()
        ),
      ])
        _HomeTool(
          title: tool.title,
          asset: 'assets/icons/inside /${tool.asset}.png',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => tool.screen)),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BuildCalc',
          style: AppTypography.textW700,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.transparent,
        foregroundColor: AppColors.homeTitle,
        elevation: 0.2,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'App Info',
            onPressed: () => _showAppInfo(context),
            icon: const Icon(Icons.info_outline_rounded, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 0) {
              return const SizedBox.shrink();
            }
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisExtent: 126 +
                          (MediaQuery.textScalerOf(context).scale(14) - 14) * 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildCalculatorTile(
                        tool: tools[index],
                      ),
                      childCount: tools.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 18),
                    child: Text(
                      'Built by inusltebuilding.com • Sirsi, Uttara Kannada',
                      textAlign: TextAlign.center,
                      style: AppTypography.text11Muted,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalculatorTile({required _HomeTool tool}) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: AppRadii.r14,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadii.r14,
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  tool.asset,
                  color: tool.tint,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  cacheWidth: 224,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        tool.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTypography.text14W700Heading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTool {
  const _HomeTool({
    required this.title,
    required this.asset,
    required this.onTap,
    this.tint,
  });

  final String title;
  final String asset;
  final VoidCallback onTap;
  final Color? tint;
}
