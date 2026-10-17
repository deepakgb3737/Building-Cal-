import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../logic/wall_resize.dart';

class WallResizeOptions extends StatelessWidget {
  const WallResizeOptions(
      {super.key, required this.value, required this.onChanged});
  final WallResizeAnchor value;
  final ValueChanged<WallResizeAnchor> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: math.min(280, MediaQuery.sizeOf(context).width - 64),
      child: DropdownButtonFormField<WallResizeAnchor>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Resize behavior'),
          items: [
            for (final mode in WallResizeAnchor.values)
              DropdownMenuItem(
                  value: mode,
                  child: Text(mode.label,
                      maxLines: 2, overflow: TextOverflow.ellipsis))
          ],
          onChanged: (mode) {
            if (mode != null) onChanged(mode);
          }));
}
