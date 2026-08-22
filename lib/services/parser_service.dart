import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/parsed_media.dart';
import '../models/pattern_recognition.dart';

class ParserService {
  ParserService({required this.baseUri, http.Client? client})
      : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  Future<ParsedMedia> parse(String text) async {
    final response = await _client
        .post(
          baseUri.resolve('/v1/parse'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 30));

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ParseException('解析服务返回了无法识别的内容');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ParseException('解析服务返回了无效结果');
    }

    final message = decoded['msg'] as String? ?? '解析失败';
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['code'] != 200) {
      throw ParseException(message);
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const ParseException('没有找到可用的图片或视频');
    }

    try {
      return ParsedMedia.fromJson(data);
    } on FormatException catch (error) {
      throw ParseException(error.message);
    }
  }

  Future<LegendRecognition> recognizeLegend(Uint8List image) async {
    final request = http.MultipartRequest(
      'POST',
      baseUri.resolve('/v1/pattern/legend'),
    )..files.add(http.MultipartFile.fromBytes('image', image, filename: 'legend.png'));
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 45)),
    );
    final data = _decodeData(response, fallback: '图例识别失败');
    return LegendRecognition.fromJson(data);
  }

  Future<PatternRecognition> recognizePattern(
    Uint8List image,
    List<LegendEntry> legend,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      baseUri.resolve('/v1/pattern/grid'),
    )
      ..fields['legend'] = jsonEncode([
        for (final item in legend) item.toJson(),
      ])
      ..files.add(http.MultipartFile.fromBytes('image', image, filename: 'pattern.png'));
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 75)),
    );
    final data = _decodeData(response, fallback: '图纸识别失败');
    return PatternRecognition.fromJson(data);
  }

  Map<String, dynamic> _decodeData(
    http.Response response, {
    required String fallback,
  }) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ParseException('$fallback：服务返回了无法识别的内容');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ParseException('$fallback：服务返回了无效结果');
    }
    final message = decoded['msg'] as String? ?? fallback;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['code'] != 200) {
      throw ParseException(message);
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw ParseException('$fallback：没有可用结果');
    }
    return data;
  }
}

class ParseException implements Exception {
  const ParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
