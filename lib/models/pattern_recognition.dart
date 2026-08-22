class LegendEntry {
  const LegendEntry({
    required this.code,
    required this.count,
    required this.color,
    required this.confidence,
  });

  final String code;
  final int count;
  final String color;
  final double confidence;

  bool get needsReview => confidence < 0.75 || code.isEmpty || count <= 0;

  LegendEntry copyWith({String? code, int? count, String? color}) {
    return LegendEntry(
      code: code ?? this.code,
      count: count ?? this.count,
      color: color ?? this.color,
      confidence: 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'count': count,
        'color': color,
      };

  factory LegendEntry.fromJson(Map<String, dynamic> json) {
    return LegendEntry(
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      count: (json['count'] as num?)?.round() ?? 0,
      color: (json['color'] as String? ?? '#FFFFFF').toUpperCase(),
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble(),
    );
  }
}

class LegendRecognition {
  const LegendRecognition({required this.items});

  final List<LegendEntry> items;

  int get total => items.fold(0, (sum, item) => sum + item.count);
  int get reviewCount => items.where((item) => item.needsReview).length;

  factory LegendRecognition.fromJson(Map<String, dynamic> json) {
    return LegendRecognition(
      items: [
        for (final value in json['items'] as List<dynamic>? ?? const [])
          if (value is Map<String, dynamic>) LegendEntry.fromJson(value),
      ],
    );
  }
}

class PatternCell {
  const PatternCell({
    required this.row,
    required this.column,
    required this.code,
    required this.confidence,
    required this.isEmpty,
    this.reason = '',
  });

  final int row;
  final int column;
  final String? code;
  final double confidence;
  final bool isEmpty;
  final String reason;

  bool get needsReview => !isEmpty && (code == null || confidence < 0.65 || reason.isNotEmpty);

  factory PatternCell.fromJson(Map<String, dynamic> json) {
    final rawCode = (json['code'] as String?)?.trim().toUpperCase();
    return PatternCell(
      row: (json['row'] as num?)?.round() ?? 0,
      column: (json['column'] as num?)?.round() ?? 0,
      code: rawCode == null || rawCode.isEmpty ? null : rawCode,
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble(),
      isEmpty: json['empty'] == true,
      reason: (json['reason'] as String? ?? '').trim(),
    );
  }
}

class PatternRecognition {
  const PatternRecognition({
    required this.columns,
    required this.rows,
    required this.cells,
    required this.recognizedCounts,
    required this.expectedCounts,
    required this.countDeltas,
    required this.warnings,
  });

  final int columns;
  final int rows;
  final List<PatternCell> cells;
  final Map<String, int> recognizedCounts;
  final Map<String, int> expectedCounts;
  final Map<String, int> countDeltas;
  final List<String> warnings;

  int get reviewCount => cells.where((cell) => cell.needsReview).length;
  int get filledCount => cells.where((cell) => cell.code != null).length;

  factory PatternRecognition.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['recognized_counts'];
    final rawExpectedCounts = json['expected_counts'];
    final rawDeltas = json['count_deltas'];
    return PatternRecognition(
      columns: (json['columns'] as num?)?.round() ?? 0,
      rows: (json['rows'] as num?)?.round() ?? 0,
      cells: [
        for (final value in json['cells'] as List<dynamic>? ?? const [])
          if (value is Map<String, dynamic>) PatternCell.fromJson(value),
      ],
      recognizedCounts: rawCounts is Map<String, dynamic>
          ? rawCounts.map((key, value) => MapEntry(key, (value as num).round()))
          : const {},
      expectedCounts: rawExpectedCounts is Map<String, dynamic>
          ? rawExpectedCounts.map(
              (key, value) => MapEntry(key, (value as num).round()),
            )
          : const {},
      countDeltas: rawDeltas is Map<String, dynamic>
          ? rawDeltas.map(
              (key, value) => MapEntry(key, (value as num).round()),
            )
          : const {},
      warnings: [
        for (final value in json['warnings'] as List<dynamic>? ?? const [])
          if (value is String && value.trim().isNotEmpty) value.trim(),
      ],
    );
  }
}
