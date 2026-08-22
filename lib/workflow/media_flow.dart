import '../models/parsed_media.dart';

enum MediaFlowStep { imageReady, framePicker }

MediaFlowStep nextStepFor(ParsedMedia media) {
  if (media.hasStaticImages) {
    return MediaFlowStep.imageReady;
  }
  if (media.frameSources.isNotEmpty) {
    return MediaFlowStep.framePicker;
  }
  throw const FormatException('没有找到可继续处理的媒体');
}
