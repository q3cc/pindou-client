import 'package:flutter_test/flutter_test.dart';
import 'package:pindou/models/parsed_media.dart';
import 'package:pindou/workflow/media_flow.dart';

void main() {
  test('普通图片跳过关键帧步骤', () {
    final media = ParsedMedia.fromJson({
      'platform': 'douyin',
      'type': 'image',
      'images': ['https://example.com/image.jpg'],
    });

    expect(nextStepFor(media), MediaFlowStep.imageReady);
  });

  test('视频进入关键帧步骤', () {
    final media = ParsedMedia.fromJson({
      'platform': 'douyin',
      'type': 'video',
      'url': 'https://example.com/video.mp4',
    });

    expect(nextStepFor(media), MediaFlowStep.framePicker);
  });
}
