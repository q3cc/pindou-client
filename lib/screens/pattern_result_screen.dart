import 'package:flutter/material.dart';

import '../models/pattern_recognition.dart';

class PatternResultScreen extends StatefulWidget {
  const PatternResultScreen({
    required this.result,
    required this.legend,
    this.title = '',
    super.key,
  });

  final PatternRecognition result;
  final List<LegendEntry> legend;
  final String title;

  @override
  State<PatternResultScreen> createState() => _PatternResultScreenState();
}

class _PatternResultScreenState extends State<PatternResultScreen> {
  final Map<int, String?> _overrides = {};

  Map<String, Color> get _colors => {
        for (final item in widget.legend) item.code: _parseColor(item.color),
      };

  int get _remainingReview => widget.result.cells.where((cell) {
        final key = _key(cell.row, cell.column);
        return cell.needsReview && !_overrides.containsKey(key);
      }).length;

  Map<String, int> get _effectiveCounts {
    final counts = <String, int>{};
    for (final cell in widget.result.cells) {
      final key = _key(cell.row, cell.column);
      final code = _overrides.containsKey(key) ? _overrides[key] : cell.code;
      if (code != null) counts[code] = (counts[code] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _countDeltas {
    final counts = _effectiveCounts;
    return {
      for (final item in widget.legend)
        if ((counts[item.code] ?? 0) != item.count)
          item.code: (counts[item.code] ?? 0) - item.count,
    };
  }

  int _key(int row, int column) => (row - 1) * widget.result.columns + column - 1;

  Future<void> _editCell(PatternCell cell) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('第 ${cell.row} 行 · 第 ${cell.column} 列',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(cell.reason.isEmpty ? '选择这个位置使用的色号。' : cell.reason),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in widget.legend)
                        ActionChip(
                          avatar: CircleAvatar(backgroundColor: _parseColor(item.color)),
                          label: Text(item.code),
                          onPressed: () => Navigator.pop(context, item.code),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, '__EMPTY__'),
                icon: const Icon(Icons.remove_rounded),
                label: const Text('这里没有豆，设为空白'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _overrides[_key(cell.row, cell.column)] = selected == '__EMPTY__' ? null : selected);
  }

  void _editNextUncertain() {
    for (final cell in widget.result.cells) {
      if (cell.needsReview && !_overrides.containsKey(_key(cell.row, cell.column))) {
        _editCell(cell);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = _PatternGrid(
      result: widget.result,
      colors: _colors,
      overrides: _overrides,
      onCellTap: _editCell,
    );
    final summary = _SummaryPanel(
      result: widget.result,
      legend: widget.legend,
      remainingReview: _remainingReview,
      countDeltas: _countDeltas,
      onReviewNext: _remainingReview == 0 ? null : _editNextUncertain,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('豆图识别结果')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth >= 600 ? 24.0 : 12.0;
            if (constraints.maxWidth >= 900) {
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: grid),
                    const SizedBox(width: 24),
                    SizedBox(width: 340, child: SingleChildScrollView(child: summary)),
                  ],
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: 12),
                  Expanded(child: grid),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PatternGrid extends StatelessWidget {
  const _PatternGrid({
    required this.result,
    required this.colors,
    required this.overrides,
    required this.onCellTap,
  });

  final PatternRecognition result;
  final Map<String, Color> colors;
  final Map<int, String?> overrides;
  final ValueChanged<PatternCell> onCellTap;

  static const cellSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final cellsByKey = {
      for (final cell in result.cells) (cell.row - 1) * result.columns + cell.column - 1: cell,
    };
    final size = Size(result.columns * cellSize, result.rows * cellSize);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: InteractiveViewer(
          minScale: 0.4,
          maxScale: 8,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(80),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final column = (details.localPosition.dx / cellSize).floor() + 1;
              final row = (details.localPosition.dy / cellSize).floor() + 1;
              if (column < 1 || column > result.columns || row < 1 || row > result.rows) return;
              final key = (row - 1) * result.columns + column - 1;
              final cell = cellsByKey[key] ?? PatternCell(
                row: row,
                column: column,
                code: null,
                confidence: 1,
                isEmpty: true,
              );
              onCellTap(cell);
            },
            child: CustomPaint(
              size: size,
              painter: _PatternPainter(
                result: result,
                colors: colors,
                overrides: overrides,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({required this.result, required this.colors, required this.overrides});

  final PatternRecognition result;
  final Map<String, Color> colors;
  final Map<int, String?> overrides;

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = _PatternGrid.cellSize;
    final byKey = {
      for (final cell in result.cells) (cell.row - 1) * result.columns + cell.column - 1: cell,
    };
    final fill = Paint()..style = PaintingStyle.fill;
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..color = const Color(0xFFB7B7B7);
    final warning = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFF7A00);

    for (var row = 0; row < result.rows; row++) {
      for (var column = 0; column < result.columns; column++) {
        final key = row * result.columns + column;
        final cell = byKey[key];
        final hasOverride = overrides.containsKey(key);
        final code = hasOverride ? overrides[key] : cell?.code;
        final rect = Rect.fromLTWH(column * cellSize, row * cellSize, cellSize, cellSize);
        fill.color = code == null ? Colors.white : colors[code] ?? const Color(0xFFE0E0E0);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, grid);
        if (cell?.needsReview == true && !hasOverride) {
          canvas.drawRect(rect.deflate(1.5), warning);
        }
        if (code != null) {
          final painter = TextPainter(
            text: TextSpan(
              text: code,
              style: TextStyle(
                color: _textColor(fill.color),
                fontSize: 7,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: cellSize - 2);
          painter.paint(
            canvas,
            Offset(
              rect.center.dx - painter.width / 2,
              rect.center.dy - painter.height / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return true;
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.result,
    required this.legend,
    required this.remainingReview,
    required this.countDeltas,
    required this.onReviewNext,
  });

  final PatternRecognition result;
  final List<LegendEntry> legend;
  final int remainingReview;
  final Map<String, int> countDeltas;
  final VoidCallback? onReviewNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: remainingReview == 0
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${result.columns} × ${result.rows} 豆图',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('已识别 ${result.filledCount} 个有豆位置'),
            const SizedBox(height: 16),
            if (remainingReview > 0) ...[
              Text('还有 $remainingReview 格需要手动确认',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text('这些位置可能被水印、文字或遮挡覆盖，系统没有替你猜测。'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onReviewNext,
                icon: const Icon(Icons.edit_location_alt_rounded),
                label: const Text('补填下一个位置'),
              ),
            ] else
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded),
                  SizedBox(width: 8),
                  Expanded(child: Text('所有不确定位置都已确认')),
                ],
              ),
            if (countDeltas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '材料数量仍有 ${countDeltas.length} 项不一致',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text('正数表示豆图多于图例，负数表示豆图少于图例。'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in countDeltas.entries)
                    Chip(
                      label: Text(
                        '${entry.key} ${entry.value > 0 ? '+' : ''}${entry.value}',
                      ),
                    ),
                ],
              ),
            ],
            const Divider(height: 28),
            Text('材料对照', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final item in legend)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    CircleAvatar(radius: 7, backgroundColor: _parseColor(item.color)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.code)),
                    Text('${item.count}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String value) {
  final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | (parsed ?? 0xFFFFFF));
}

Color _textColor(Color background) {
  final luminance = background.computeLuminance();
  return luminance > 0.45 ? Colors.black87 : Colors.white;
}
