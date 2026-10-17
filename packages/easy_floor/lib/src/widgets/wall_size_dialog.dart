import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/room.dart';
import '../utils/room_dimensions.dart';

class WallSizeDialog extends StatefulWidget {
  const WallSizeDialog({super.key, required this.room});
  final Room room;
  @override
  State<WallSizeDialog> createState() => _WallSizeDialogState();
}

class _WallSizeDialogState extends State<WallSizeDialog> {
  final _form = GlobalKey<FormState>();
  final _length = TextEditingController();
  var _wall = 0;
  var _unit = DimensionUnit.metres;
  List<Offset> get _points => widget.room.wallPoints!;
  double _size(int wall) =>
      (_points[(wall + 1) % _points.length] - _points[wall]).distance * 10;
  @override
  void initState() {
    super.initState();
    _length.text = _unit.fromMm(_size(0)).toString();
  }

  @override
  void dispose() {
    _length.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit wall lengths'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Choose the numbered wall. Its starting corner stays fixed; connected walls adjust with it.'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _wall,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Wall'),
                      items: [
                        for (var i = 0; i < _points.length; i++)
                          DropdownMenuItem(
                              value: i,
                              child: Text(
                                  'Wall ${i + 1} · ${_unit.fromMm(_size(i)).toStringAsFixed(2)} ${_unit.symbol}'))
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setState(() {
                            _wall = value;
                            _length.text =
                                _unit.fromMm(_size(value)).toString();
                          });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<DimensionUnit>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: [
                        for (final unit in DimensionUnit.values)
                          DropdownMenuItem(value: unit, child: Text(unit.label))
                      ],
                      onChanged: (unit) {
                        if (unit != null)
                          setState(() {
                            final value = double.tryParse(_length.text);
                            if (value != null && value.isFinite)
                              _length.text =
                                  unit.fromMm(_unit.toMm(value)).toString();
                            _unit = unit;
                          });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _length,
                        decoration: InputDecoration(
                            labelText: 'Wall length (${_unit.symbol})'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        validator: (text) {
                          final value = double.tryParse(text ?? '');
                          if (value == null ||
                              !value.isFinite ||
                              _unit.toMm(value) < 100 ||
                              _unit.toMm(value) > 1000000) {
                            return 'Enter a length from 0.1 to 1000 metres';
                          }
                          return null;
                        }),
                  ],
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate())
                  Navigator.pop(
                      context, (_wall, _unit.toMm(double.parse(_length.text))));
              },
              child: const Text('Apply')),
        ],
      );
}
