import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/prepared_image.dart';

Future<Uint8List> loadPreparedImage(PreparedImage image) async {
  if (image.bytes != null) return image.bytes!;
  final url = image.networkUrl;
  if (url == null) throw const FormatException('没有可用的模板图片');
  final response = await http
      .get(url, headers: image.headers)
      .timeout(const Duration(seconds: 40));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const FormatException('模板图片下载失败，请重新解析');
  }
  if (response.bodyBytes.isEmpty) {
    throw const FormatException('模板图片内容为空');
  }
  if (response.bodyBytes.length > 24 * 1024 * 1024) {
    throw const FormatException('模板图片超过 24 MB，请先压缩后重试');
  }
  return response.bodyBytes;
}
