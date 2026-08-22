import '../models/parsed_media.dart';

Map<String, String> mediaHeaders(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.douyin => const {
        'Referer': 'https://www.douyin.com/',
        'User-Agent':
            'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148',
      },
    SourcePlatform.xiaohongshu => const {
        'Referer': 'https://www.xiaohongshu.com/',
        'User-Agent':
            'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148',
      },
  };
}
