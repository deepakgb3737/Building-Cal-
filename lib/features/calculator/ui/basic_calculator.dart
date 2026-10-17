import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/calculator/logic/calculator_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const String _defaultResult = '0';
  String _expression = '';
  String _result = _defaultResult;
  String? _lastAnswer;
  bool _committed = false;
  bool _validResult = true;
  final List<_CalcHistoryItem> _history = <_CalcHistoryItem>[];

  KeyEventResult _onPhysicalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (ModalRoute.of(context)?.isCurrent != true ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    String? value;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      value = '=';
    } else if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      value = 'DEL';
    } else if (key == LogicalKeyboardKey.escape) {
      value = 'AC';
    } else {
      final character = event.character;
      if (character != null &&
          RegExp(r'^[0-9.+\-*/%()^=]$').hasMatch(character)) {
        value = character == '*'
            ? '×'
            : character == '/'
                ? '÷'
                : character;
      }
    }
    if (value == null) return KeyEventResult.ignored;
    _onKeyTap(value);
    return KeyEventResult.handled;
  }

  void _onKeyTap(String value) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (value) {
        case 'AC':
          _expression = '';
          _result = _defaultResult;
          _committed = false;
          _validResult = true;
          break;
        case 'DEL':
          _committed = false;
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
            _refreshPreview();
          }
          break;
        case '=':
          _evaluateAndCommit();
          break;
        case '+/-':
          _toggleSign();
          break;
        case 'Ans':
          if (_lastAnswer != null) _appendValue('($_lastAnswer)');
          break;
        case 'Square':
        case 'Square root':
        case 'Reciprocal':
          if (CalculatorEngine.tryEvaluate(_expression) == null) return;
          _expression = switch (value) {
            'Square' => '($_expression)^2',
            'Square root' => 'sqrt($_expression)',
            _ => '1/($_expression)',
          };
          _committed = false;
          _refreshPreview();
          break;
        default:
          _appendValue(value);
          break;
      }
    });
  }

  void _appendValue(String value) {
    if (_committed && !['+', '-', '×', '÷', '%', '^', ')'].contains(value)) {
      _expression = '';
    }
    _committed = false;
    final mapped = value == '×'
        ? '*'
        : value == '÷'
            ? '/'
            : value;
    if (_expression.length + mapped.length > 512) return;
    _expression += mapped;
    _refreshPreview();
  }

  void _toggleSign() {
    _committed = false;
    if (_expression.isEmpty) {
      _expression = '-';
      _refreshPreview();
      return;
    }
    if (_expression.endsWith(')')) {
      _expression = '-($_expression)';
      _refreshPreview();
      return;
    }
    final index = _lastNumberStartIndex(_expression);
    if (index == -1) return;
    final numberPart = _expression.substring(index);
    if (numberPart.startsWith('-')) {
      _expression =
          '${_expression.substring(0, index)}${numberPart.substring(1)}';
    } else {
      _expression = '${_expression.substring(0, index)}-$numberPart';
    }
    _refreshPreview();
  }

  int _lastNumberStartIndex(String text) {
    final match =
        RegExp(r'(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?%*$').firstMatch(text);
    if (match == null) return -1;
    final candidate = match.start;
    if (candidate > 0 && text[candidate - 1] == '-') {
      final beforeMinus = candidate - 2;
      if (beforeMinus < 0 || _isOperator(text[beforeMinus])) {
        return candidate - 1;
      }
    }
    return candidate;
  }

  void _refreshPreview() {
    if (_expression.isEmpty) {
      _result = _defaultResult;
      _validResult = true;
      return;
    }
    final value = CalculatorEngine.tryEvaluate(_expression);
    _validResult = value != null;
    _result = value == null ? '...' : CalculatorEngine.formatResult(value);
  }

  void _evaluateAndCommit() {
    final value = CalculatorEngine.tryEvaluate(_expression);
    if (value == null) {
      _result = 'Error';
      _validResult = false;
      return;
    }
    final formatted = CalculatorEngine.formatResult(value);
    _pushHistory(
      input: _expression,
      output: formatted,
      tag: 'Standard',
    );
    _expression = formatted;
    _result = formatted;
    _lastAnswer = formatted;
    _committed = true;
    _validResult = true;
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not copy. Please try again.')));
    }
  }

  void _pushHistory({
    required String input,
    required String output,
    required String tag,
  }) {
    final cleanedInput = input.trim();
    if (cleanedInput.isEmpty) return;
    final item = _CalcHistoryItem(
      input: cleanedInput,
      output: output,
      tag: tag,
      time: DateTime.now(),
    );
    _history.insert(0, item);
    if (_history.length > 30) {
      _history.removeLast();
    }
  }

  void _openHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) {
        if (_history.isEmpty) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: Text(
                'No history yet',
                style: AppTypography.text15W600Muted,
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      'History',
                      style: AppTypography.text17W700Text,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => _history.clear());
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return ListTile(
                      dense: true,
                      onTap: () {
                        setState(() {
                          _expression = item.output;
                          _result = item.output;
                          _validResult = true;
                          _committed = true;
                        });
                        Navigator.pop(context);
                      },
                      title: Text(
                        item.input,
                        style: AppTypography.text14Secondarytext,
                      ),
                      subtitle: Text(
                        item.tag,
                        style: AppTypography.text11,
                      ),
                      trailing: SizedBox(
                        width: 140,
                        child: Row(children: [
                          Expanded(
                              child: Text(item.output,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.text15W700Primary)),
                          IconButton(
                              tooltip: 'Copy history result',
                              onPressed: () => _copy(item.output),
                              icon: const Icon(Icons.copy_rounded)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _isOperator(String char) {
    return char == '+' ||
        char == '-' ||
        char == '*' ||
        char == '/' ||
        char == '(';
  }

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      'AC',
      'DEL',
      '%',
      '÷',
      '7',
      '8',
      '9',
      '×',
      '4',
      '5',
      '6',
      '-',
      '1',
      '2',
      '3',
      '+',
      '+/-',
      '0',
      '.',
      '=',
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: _onPhysicalKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calculator'),
          actions: [
            IconButton(
              tooltip: 'History',
              onPressed: _openHistorySheet,
              icon: const Icon(Icons.history_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'More operations',
              onSelected: _onKeyTap,
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: '(', child: Text('Open parenthesis (')),
                const PopupMenuItem(
                    value: ')', child: Text('Close parenthesis )')),
                const PopupMenuItem(value: 'Square', child: Text('Square x²')),
                const PopupMenuItem(
                    value: 'Square root', child: Text('Square root √x')),
                const PopupMenuItem(
                    value: 'Reciprocal', child: Text('Reciprocal 1/x')),
                PopupMenuItem(
                    value: 'Ans',
                    enabled: _lastAnswer != null,
                    child: const Text('Last answer (Ans)')),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 360 || constraints.maxHeight < 690;
              final horizontalPadding = compact ? 12.0 : 16.0;
              final spacing = compact ? 6.0 : 8.0;
              final displayExpressionSize = compact ? 22.0 : 28.0;
              final displayResultSize = compact ? 30.0 : 38.0;
              final keyFontSize = compact ? 18.0 : 22.0;

              return SingleChildScrollView(
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: SizedBox(
                              height: constraints.maxHeight
                                  .clamp(440, double.infinity)
                                  .toDouble(),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  compact ? 6 : 8,
                                  horizontalPadding,
                                  compact ? 10 : 16,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: 35,
                                      child: Column(children: [
                                        Expanded(
                                            child: Align(
                                                alignment:
                                                    Alignment.bottomRight,
                                                child: SingleChildScrollView(
                                                    reverse: true,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          _expression.isEmpty
                                                              ? '0'
                                                              : _expression,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.right,
                                                          style: AppTypography
                                                              .text14Secondarytext
                                                              .copyWith(
                                                                  fontSize:
                                                                      displayExpressionSize),
                                                        ),
                                                        SizedBox(
                                                            height: compact
                                                                ? 4
                                                                : 8),
                                                        SelectableText(
                                                          _result,
                                                          contextMenuBuilder:
                                                              (context,
                                                                  editable) {
                                                            if (!_validResult) {
                                                              return const SizedBox
                                                                  .shrink();
                                                            }
                                                            return AdaptiveTextSelectionToolbar
                                                                .buttonItems(
                                                              anchors: editable
                                                                  .contextMenuAnchors,
                                                              buttonItems: [
                                                                ContextMenuButtonItem(
                                                                  type:
                                                                      ContextMenuButtonType
                                                                          .copy,
                                                                  onPressed:
                                                                      () {
                                                                    editable
                                                                        .hideToolbar();
                                                                    _copy(
                                                                        _result);
                                                                  },
                                                                )
                                                              ],
                                                            );
                                                          },
                                                          maxLines: 1,
                                                          textAlign:
                                                              TextAlign.right,
                                                          style: AppTypography
                                                              .textW600Text
                                                              .copyWith(
                                                                  fontSize:
                                                                      displayResultSize),
                                                        ),
                                                      ],
                                                    )))),
                                      ]),
                                    ),
                                    SizedBox(height: spacing + 2),
                                    Expanded(
                                      flex: 65,
                                      child: LayoutBuilder(
                                        builder: (context, gridConstraints) {
                                          const columns = 4;
                                          const rows = 5;
                                          final cellWidth = (gridConstraints
                                                      .maxWidth -
                                                  ((columns - 1) * spacing)) /
                                              columns;
                                          final cellHeight =
                                              (gridConstraints.maxHeight -
                                                      ((rows - 1) * spacing)) /
                                                  rows;
                                          final ratio = cellHeight <= 0
                                              ? 1.0
                                              : cellWidth / cellHeight;

                                          return GridView.builder(
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: columns,
                                              childAspectRatio: ratio,
                                              crossAxisSpacing: spacing,
                                              mainAxisSpacing: spacing,
                                            ),
                                            itemCount: keys.length,
                                            itemBuilder: (context, index) {
                                              final key = keys[index];
                                              final isOperator = [
                                                '+',
                                                '-',
                                                '×',
                                                '÷',
                                                '=',
                                                '%'
                                              ].contains(key);
                                              final isUtility = [
                                                'AC',
                                                'DEL',
                                                '+/-'
                                              ].contains(key);
                                              final Color bg = key == '='
                                                  ? AppColors.primary
                                                  : isOperator
                                                      ? AppColors.blueSurface
                                                      : isUtility
                                                          ? AppColors.surfaceAlt
                                                          : AppColors
                                                              .softSurface;
                                              final Color fg = key == '='
                                                  ? AppColors.white
                                                  : isOperator
                                                      ? AppColors.blueDark
                                                      : AppColors.text;

                                              return _CalcKey(
                                                label: key,
                                                backgroundColor: bg,
                                                foregroundColor: fg,
                                                fontSize: keyFontSize,
                                                onTap: () => _onKeyTap(key),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )))));
            },
          ),
        ),
      ),
    );
  }
}

class _CalcHistoryItem {
  const _CalcHistoryItem({
    required this.input,
    required this.output,
    required this.tag,
    required this.time,
  });

  final String input;
  final String output;
  final String tag;
  final DateTime time;
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: AppRadii.r10,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadii.r10,
          ),
          child: Center(
            child: Padding(
                padding: const EdgeInsets.all(6),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: AppTypography.textW700
                          .copyWith(fontSize: fontSize, color: foregroundColor),
                    ))),
          ),
        ),
      ),
    );
  }
}
