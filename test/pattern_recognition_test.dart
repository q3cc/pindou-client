import 'package:flutter_test/flutter_test.dart';
import 'package:pindou/models/pattern_recognition.dart';

void main() {
  test('图例材料数量会汇总', () {
    final result = LegendRecognition.fromJson({
      'items': [
        {'code': 'H7', 'count': 904, 'color': '#111111', 'confidence': .98},
        {'code': 'A8', 'count': 307, 'color': '#EFC22D', 'confidence': .96},
      ],
    });

    expect(result.total, 1211);
    expect(result.reviewCount, 0);
  });

  test('空白格不进入待补列表', () {
    final result = PatternRecognition.fromJson({
      'columns': 2,
      'rows': 1,
      'cells': [
        {'row': 1, 'column': 1, 'empty': true, 'confidence': 1},
        {
          'row': 1,
          'column': 2,
          'empty': false,
          'confidence': .4,
          'reason': '检测到水印',
        },
      ],
      'recognized_counts': <String, int>{},
      'expected_counts': <String, int>{},
      'count_deltas': <String, int>{},
      'warnings': <String>[],
    });

    expect(result.reviewCount, 1);
  });

  test('数量差异与警告会被保留', () {
    final result = PatternRecognition.fromJson({
      'columns': 1,
      'rows': 1,
      'cells': <dynamic>[],
      'recognized_counts': {'H7': 903},
      'expected_counts': {'H7': 904},
      'count_deltas': {'H7': -1},
      'warnings': ['请检查水印区域'],
    });

    expect(result.countDeltas['H7'], -1);
    expect(result.warnings, ['请检查水印区域']);
  });
}
