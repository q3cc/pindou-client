import 'dart:typed_data';

class PreparedImage {
  const PreparedImage.network({
    required this.label,
    required Uri url,
    this.headers = const {},
  })  : networkUrl = url,
        bytes = null;

  const PreparedImage.memory({
    required this.label,
    required Uint8List data,
  })  : bytes = data,
        networkUrl = null,
        headers = const {};

  final String label;
  final Uri? networkUrl;
  final Uint8List? bytes;
  final Map<String, String> headers;
}
