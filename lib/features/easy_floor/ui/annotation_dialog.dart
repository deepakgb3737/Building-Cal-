import 'package:flutter/material.dart';
import '../logic/drawing_annotations.dart';
import 'annotation_painter.dart';

class AnnotationDialog extends StatefulWidget {
  const AnnotationDialog({super.key, required this.note});
  final DrawingAnnotation note;
  @override
  State<AnnotationDialog> createState() => _AnnotationDialogState();
}

class _AnnotationDialogState extends State<AnnotationDialog> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.note.text);
  late double _size = widget.note.sizeMm / 10;
  late AnnotationInk _ink = widget.note.ink;
  late AnnotationAlignment _alignment = widget.note.alignment;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(12),
        title: Text(widget.note.id == 0 ? 'Add text' : 'Edit text'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      key: const ValueKey('annotationText'),
                      controller: _text,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 2000,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(labelText: 'Text'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter text' : null),
                  Text('Size ${_size.round()} (at 100% zoom)'),
                  Slider(
                      value: _size,
                      min: 12,
                      max: 48,
                      divisions: 36,
                      onChanged: (value) => setState(() => _size = value)),
                  DropdownButtonFormField<AnnotationInk>(
                      initialValue: _ink,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Color'),
                      items: [
                        for (final ink in AnnotationInk.values)
                          DropdownMenuItem(
                              value: ink,
                              child: Row(children: [
                                Icon(Icons.circle,
                                    size: 14, color: annotationColor(ink)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(ink.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis))
                              ]))
                      ],
                      onChanged: (v) => setState(() => _ink = v!)),
                  DropdownButtonFormField<AnnotationAlignment>(
                      initialValue: _alignment,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Alignment'),
                      items: [
                        for (final alignment in AnnotationAlignment.values)
                          DropdownMenuItem(
                              value: alignment,
                              child: Text(alignment.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: (v) => setState(() => _alignment = v!)),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                      context,
                      widget.note.copyWith(
                          text: _text.text,
                          sizeMm: _size * 10,
                          ink: _ink,
                          alignment: _alignment));
                }
              },
              child: const Text('Apply text'))
        ],
      );
}
