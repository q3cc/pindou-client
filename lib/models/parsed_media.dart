enum SourcePlatform { douyin, xiaohongshu }

enum ParsedMediaType { image, live, video }

class LiveMedia {
  const LiveMedia({required this.imageUrl, required this.videoUrl});

  final Uri? imageUrl;
  final Uri videoUrl;

  factory LiveMedia.fromJson(Map<String, dynamic> json) {
    final videoUrl = _uriOrNull(json['video']);
    if (videoUrl == null) {
      throw const FormatException('实况内容缺少视频地址');
    }
    return LiveMedia(
      imageUrl: _uriOrNull(json['image']),
      videoUrl: videoUrl,
    );
  }
}

class FrameSource {
  const FrameSource({
    required this.label,
    required this.candidates,
    this.posterUrl,
  });

  final String label;
  final List<Uri> candidates;
  final Uri? posterUrl;
}

class ParsedMedia {
  const ParsedMedia({
    required this.platform,
    required this.type,
    required this.title,
    required this.description,
    required this.authorName,
    required this.coverUrl,
    required this.images,
    required this.livePhotos,
    required this.videoCandidates,
    required this.duration,
    required this.sourceUrl,
  });

  final SourcePlatform platform;
  final ParsedMediaType type;
  final String title;
  final String description;
  final String authorName;
  final Uri? coverUrl;
  final List<Uri> images;
  final List<LiveMedia> livePhotos;
  final List<Uri> videoCandidates;
  final Duration? duration;
  final Uri? sourceUrl;

  bool get hasStaticImages => type == ParsedMediaType.image && images.isNotEmpty;

  List<FrameSource> get frameSources {
    if (livePhotos.isNotEmpty) {
      return [
        for (var index = 0; index < livePhotos.length; index++)
          FrameSource(
            label: '实况 ${index + 1}',
            candidates: [livePhotos[index].videoUrl],
            posterUrl: livePhotos[index].imageUrl,
          ),
      ];
    }

    if (videoCandidates.isNotEmpty) {
      return [
        FrameSource(
          label: '视频',
          candidates: videoCandidates,
          posterUrl: coverUrl,
        ),
      ];
    }
    return const [];
  }

  factory ParsedMedia.fromJson(Map<String, dynamic> json) {
    final platform = switch (json['platform']) {
      'douyin' => SourcePlatform.douyin,
      'xiaohongshu' => SourcePlatform.xiaohongshu,
      _ => throw const FormatException('未知内容来源'),
    };

    final type = switch (json['type']) {
      'image' => ParsedMediaType.image,
      'live' => ParsedMediaType.live,
      'video' => ParsedMediaType.video,
      _ => throw const FormatException('暂不支持这种内容类型'),
    };

    final author = json['author'];
    final rawDuration = json['duration'];
    final videoCandidates = <Uri>[
      ..._uriList(json['url']),
      ..._uriList(json['video_backup']),
    ];

    return ParsedMedia(
      platform: platform,
      type: type,
      title: (json['title'] as String?)?.trim() ?? '',
      description: (json['desc'] as String?)?.trim() ?? '',
      authorName: author is Map<String, dynamic>
          ? (author['name'] as String?)?.trim() ?? ''
          : '',
      coverUrl: _uriOrNull(json['cover']),
      images: _uriList(json['images']),
      livePhotos: [
        for (final item in (json['live_photo'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) LiveMedia.fromJson(item),
      ],
      videoCandidates: videoCandidates.toSet().toList(growable: false),
      duration: rawDuration is num && rawDuration > 0
          ? Duration(milliseconds: rawDuration.round())
          : null,
      sourceUrl: _uriOrNull(json['source_url']),
    );
  }
}

Uri? _uriOrNull(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return Uri.tryParse(value.trim());
}

List<Uri> _uriList(dynamic value) {
  if (value is String) {
    final uri = _uriOrNull(value);
    return uri == null ? const [] : [uri];
  }
  if (value is List) {
    final result = <Uri>[];
    for (final item in value) {
      final uri = _uriOrNull(item);
      if (uri != null) {
        result.add(uri);
      }
    }
    return result;
  }
  return const [];
}
