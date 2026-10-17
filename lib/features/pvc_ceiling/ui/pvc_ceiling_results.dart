import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';
import '../logic/pvc_ceiling_calculator.dart';
import 'pvc_format.dart';
import 'pvc_ceiling_painter.dart';
import 'pvc_section.dart';
import 'pvc_diagram_view.dart';

class PvcCeilingResults extends StatelessWidget {
  const PvcCeilingResults({super.key, required this.layout});
  final Layout? layout;
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: _results());
  List<Widget> _results() {
    final c = layout;
    if (c == null) {
      return const [
        PvcSection(
          title: 'What to buy',
          child: Text(
            'No valid layout for this choice. Try another plank option or '
            'check the room size.',
            style: AppTypography.text16,
          ),
        ),
      ];
    }
    return [
      PvcSection(
          title: 'What to buy',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buyRow(c),
            const SizedBox(height: 10),
            Text('Room area: ${fmt(c.area)} sq ft',
                style: AppTypography.text14Greymuted),
            if (c.turned)
              const Text('Plan rotated so planks run left to right.',
                  style: AppTypography.text14Greymuted),
          ])),
      PvcSection(title: 'Ceiling layout', child: _layoutView(c)),
      if (!c.uniform)
        const Text(
            'Each piece covers the longest span of its row. Trim the shape edge to the wall.',
            style: AppTypography.text14Greymuted),
      PvcSection(title: 'Cutting guide', child: _guide(c)),
    ];
  }

  Widget _buyRow(Layout c) {
    Widget stat(String value, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: AppTypography.text22BoldInk),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.text14Greymuted),
          ]),
        );
    return Container(
      decoration: const BoxDecoration(
          border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.border))),
      child: LayoutBuilder(builder: (context, box) {
        final counts = [
          stat('${c.q12}', 'planks of 12 ft'),
          stat('${c.q10}', 'planks of 10 ft')
        ];
        final waste = stat('${fmt(c.waste)} ft',
            'wastage, ${c.wastePercent}% of stock length');
        if (box.maxWidth >= 600) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final item in [...counts, waste]) Expanded(child: item)
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final item in counts) Expanded(child: item)]),
              const Divider(height: 1),
              waste,
            ]);
      }),
    );
  }

  Widget _layoutView(Layout c) {
    final g = LayoutGeometry.of(c);
    return PvcDiagramView(
        key: ValueKey(c),
        size: Size(g.vw, g.vh),
        painter: CeilingPainter(c, 1.2),
        label: 'Calculated ceiling layout');
  }

  Widget _guide(Layout c) {
    final groups = buildGroups(c);
    final cutList = groups.where((o) => !o.whole).toList();
    if (cutList.isEmpty) {
      return const Text('No cutting needed. Use every plank whole.',
          style: AppTypography.text14Greymuted);
    }

    final children = <Widget>[
      const Text(
        'Cut in number order. Marked readings = tape measure from the left '
        'end of the plank (blade width included).',
        style: AppTypography.text14Greymuted,
      ),
    ];

    for (final stock in const [10.0, 12.0]) {
      final total = c.stockCount(stock);
      if (total == 0) continue;
      final list = cutList.where((o) => o.stock == stock).toList();
      final wholeCount = c.wholeCount(stock);
      final cutCount = total - wholeCount;
      final note = [
        if (cutCount > 0) '$cutCount to cut',
        if (wholeCount > 0) '$wholeCount used whole, no cutting',
      ].join(', ');

      children.add(Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '${stock.toInt()} ft planks: '),
            TextSpan(text: '$total', style: AppTypography.textW700Primary),
          ]),
          style: AppTypography.text22BoldInk,
        ),
      ));
      children.add(Text(note, style: AppTypography.text14Greymuted));

      for (final o in list) {
        children.add(_cutCard(o, c));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _cutCard(CutGroup o, Layout c) {
    final cutText = o.cuts.map(ftin).join(' + ');
    final scrapText = o.scrap > 0 ? ', scrap ${ftin(o.scrap)}' : '';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Text('${o.q}×', style: AppTypography.text22BoldInk),
              Text(
                '${o.q > 1 ? 'planks' : 'plank'}: cut into $cutText$scrapText',
                style: AppTypography.textW600,
              ),
            ],
          ),
          const SizedBox(height: 6),
          PvcDiagramView(
              key: ValueKey('${o.stock}:${o.cuts}'),
              size: const Size(CutPainter.viewW, CutPainter.viewH),
              painter: CutPainter(o, c.sizes),
              label: 'Cutting diagram for ${o.stock.toInt()} ft stock'),
        ],
      ),
    );
  }
}
