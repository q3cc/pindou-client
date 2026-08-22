import 'package:flutter_test/flutter_test.dart';
import 'package:pindou/models/parsed_media.dart';

void main() {
  test('静态图集直接形成图片集合', () {
    final media = ParsedMedia.fromJson({
      'platform': 'xiaohongshu',
      'type': 'image',
      'title': '图集',
      'author': {'name': '作者'},
      'images': ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
      'live_photo': <dynamic>[],
    });

    expect(media.hasStaticImages, isTrue);
    expect(media.images, hasLength(2));
    expect(media.frameSources, isEmpty);
  });

  test('实况内容按每段视频生成关键帧来源', () {
    final media = ParsedMedia.fromJson({
      'platform': 'douyin',
      'type': 'live',
      'images': ['https://example.com/cover.jpg'],
      'live_photo': [
        {
          'image': 'https://example.com/live.jpg',
          'video': 'https://example.com/live.mp4',
        },
      ],
    });

    expect(media.hasStaticImages, isFalse);
    expect(media.frameSources, hasLength(1));
    expect(media.frameSources.single.candidates.single.path, '/live.mp4');
  });

  test('视频保留主地址和备用地址', () {
    final media = ParsedMedia.fromJson({
      'platform': 'xiaohongshu',
      'type': 'video',
      'url': 'https://example.com/main.mp4',
      'video_backup': ['https://example.com/backup.mp4'],
    });

    expect(media.videoCandidates, hasLength(2));
    expect(media.frameSources.single.candidates, hasLength(2));
  });
}
