import 'dart:io';

abstract final class AppConfig {
  static Uri get parserBaseUri {
    const configured = String.fromEnvironment('PARSE_API_BASE_URL');
    if (configured.isNotEmpty) {
      return Uri.parse(configured);
    }

    // Android 模拟器通过 10.0.2.2 访问宿主机；Apple 模拟器使用回环地址。
    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2:8787');
    }
    return Uri.parse('http://127.0.0.1:8787');
  }
}
