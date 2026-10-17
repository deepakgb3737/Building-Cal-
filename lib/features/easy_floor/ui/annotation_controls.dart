import 'package:flutter/material.dart';

class AnnotationControls extends StatelessWidget {
  const AnnotationControls(
      {super.key,
      required this.count,
      required this.multi,
      required this.onMulti,
      this.onEdit,
      this.onDuplicate,
      this.onDelete});
  final int count;
  final bool multi;
  final ValueChanged<bool> onMulti;
  final VoidCallback? onEdit, onDuplicate, onDelete;

  @override
  Widget build(BuildContext context) => Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
                label: const Text('Select texts'),
                selected: multi,
                onSelected: onMulti),
            if (count > 0) Text('$count text selected'),
            if (count == 1) const Text('Drag bottom-right handle to resize'),
            TextButton(onPressed: onEdit, child: const Text('Edit text')),
            IconButton(
                onPressed: onDuplicate,
                tooltip: 'Duplicate text',
                icon: const Icon(Icons.content_copy)),
            if (count > 0)
              IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete text',
                  icon: const Icon(Icons.delete_outline)),
          ]);
}
