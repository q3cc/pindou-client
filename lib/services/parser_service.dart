import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parsed_media.dart';

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
}

class ParseException implements Exception {
  const ParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
