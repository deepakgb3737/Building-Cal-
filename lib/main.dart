import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/home/ui/home_screen.dart';

void main() {
  runApp(const GridCeilingCalculatorApp());
}

class GridCeilingCalculatorApp extends StatelessWidget {
  const GridCeilingCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuildCalc',
      theme: AppTheme.light,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
