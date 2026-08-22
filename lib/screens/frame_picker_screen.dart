import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_video_thumbnail/get_video_thumbnail.dart';
import 'package:video_player/video_player.dart';

import '../core/media_headers.dart';
import '../models/prepared_image.dart';
import '../models/parsed_media.dart';
import '../widgets/adaptive_content_shell.dart';
import 'image_ready_screen.dart';

class FramePickerScreen extends StatefulWidget {
  const FramePickerScreen({required this.media, super.key});

  final ParsedMedia media;

  @override
  State<FramePickerScreen> createState() => _FramePickerScreenState();
}

class _FramePickerScreenState extends State<FramePickerScreen> {
  VideoPlayerController? _controller;
  Uri? _activeVideoUrl;
  int _sourceIndex = 0;
  int _loadGeneration = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoadingVideo = true;
  bool _isExtracting = false;
  bool _isDragging = false;
  String? _error;

  List<FrameSource> get _sources => widget.media.frameSources;

  @override
  void initState() {
    super.initState();
    _loadSource(0);
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.removeListener(_onPlaybackTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadSource(int index) async {
    final generation = ++_loadGeneration;
    final previous = _controller;
    previous?.removeListener(_onPlaybackTick);
    _controller = null;
    _activeVideoUrl = null;
    await previous?.dispose();

    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _sourceIndex = index;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isLoadingVideo = true;
      _error = null;
    });

    final headers = mediaHeaders(widget.media.platform);
    Object? lastError;
    for (final candidate in _sources[index].candidates) {
      final controller = VideoPlayerController.networkUrl(
        candidate,
        httpHeaders: headers,
      );
      try {
        await controller.initialize();
        if (!mounted || generation != _loadGeneration) {
          await controller.dispose();
          return;
        }
        controller.addListener(_onPlaybackTick);
        setState(() {
          _controller = controller;
          _activeVideoUrl = candidate;
          _duration = controller.value.duration;
          _isLoadingVideo = false;
        });
        return;
      } catch (error) {
        lastError = error;
        await controller.dispose();
      }
    }

    if (mounted && generation == _loadGeneration) {
      setState(() {
        _isLoadingVideo = false;
        _error = lastError == null ? '没有可播放的视频' : '视频暂时无法打开，请重新解析';
      });
    }
  }

  void _onPlaybackTick() {
    final controller = _controller;
    if (!mounted || controller == null || _isDragging) return;
    final nextPosition = controller.value.position;
    final nextDuration = controller.value.duration;
    if (nextPosition.inMilliseconds != _position.inMilliseconds ||
        nextDuration.inMilliseconds != _duration.inMilliseconds) {
      setState(() {
        _position = nextPosition;
        _duration = nextDuration;
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _seek(double milliseconds) async {
    final position = Duration(milliseconds: milliseconds.round());
    setState(() {
      _isDragging = false;
      _position = position;
    });
    await _controller?.seekTo(position);
  }

  Future<void> _extractFrame() async {
    final videoUrl = _activeVideoUrl;
    final controller = _controller;
    if (videoUrl == null || controller == null) return;

    setState(() {
      _isExtracting = true;
      _error = null;
    });

    try {
      await controller.pause();
      await controller.seekTo(_position);
      final Uint8List data = await VideoThumbnail.thumbnailData(
        video: videoUrl.toString(),
        headers: mediaHeaders(widget.media.platform),
        maxWidth: 2048,
        timeMs: _position.inMilliseconds,
        quality: 95,
      );
      if (data.isEmpty) {
        throw StateError('empty frame');
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ImageReadyScreen(
            title: widget.media.title,
            images: [
              PreparedImage.memory(
                label: '${_sources[_sourceIndex].label} · ${_formatTime(_position)}',
                data: data,
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = '这一帧生成失败，请换个位置再试');
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _VideoPreview(
      controller: _controller,
      isLoading: _isLoadingVideo,
      error: _error,
    );
    final controls = _FrameControls(
      sources: _sources,
      sourceIndex: _sourceIndex,
      position: _position,
      duration: _duration,
      isPlaying: _controller?.value.isPlaying ?? false,
      isEnabled: _controller != null && !_isLoadingVideo,
      isExtracting: _isExtracting,
      onSourceSelected: _loadSource,
      onTogglePlayback: _togglePlayback,
      onDragStart: () => setState(() => _isDragging = true),
      onPositionChanged: (value) => setState(
        () => _position = Duration(milliseconds: value.round()),
      ),
      onPositionChangeEnd: _seek,
      onExtract: _extractFrame,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('选择关键帧')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AdaptiveContentShell(
            breakpoint: 900,
            compact: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [preview, const SizedBox(height: 20), controls],
            ),
            expanded: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: preview),
                const SizedBox(width: 28),
                Expanded(flex: 4, child: controls),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({
    required this.controller,
    required this.isLoading,
    required this.error,
  });

  final VideoPlayerController? controller;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final value = controller?.value;
    final aspectRatio = value != null && value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    final Widget content;
    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (controller != null) {
      content = VideoPlayer(controller!);
    } else if (error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error!, style: const TextStyle(color: Colors.white)),
        ),
      );
    } else {
      content = const Center(
        child: Text('没有可预览的内容', style: TextStyle(color: Colors.white)),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: content,
      ),
    );
  }
}

class _FrameControls extends StatelessWidget {
  const _FrameControls({
    required this.sources,
    required this.sourceIndex,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isEnabled,
    required this.isExtracting,
    required this.onSourceSelected,
    required this.onTogglePlayback,
    required this.onDragStart,
    required this.onPositionChanged,
    required this.onPositionChangeEnd,
    required this.onExtract,
  });

  final List<FrameSource> sources;
  final int sourceIndex;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isEnabled;
  final bool isExtracting;
  final ValueChanged<int> onSourceSelected;
  final VoidCallback onTogglePlayback;
  final VoidCallback onDragStart;
  final ValueChanged<double> onPositionChanged;
  final ValueChanged<double> onPositionChangeEnd;
  final VoidCallback onExtract;

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final value = position.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('找到想保留的画面', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '播放或拖动时间轴，停在合适的位置后生成图片。',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (sources.length > 1) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < sources.length; index++)
                    ChoiceChip(
                      label: Text(sources[index].label),
                      selected: index == sourceIndex,
                      onSelected: isExtracting ? null : (_) => onSourceSelected(index),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: isPlaying ? '暂停' : '播放',
                  onPressed: isEnabled ? onTogglePlayback : null,
                  icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: value,
                    max: max,
                    onChangeStart: isEnabled ? (_) => onDragStart() : null,
                    onChanged: isEnabled ? onPositionChanged : null,
                    onChangeEnd: isEnabled ? onPositionChangeEnd : null,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${_formatTime(position)} / ${_formatTime(duration)}'),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: isEnabled && !isExtracting ? onExtract : null,
              icon: isExtracting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_rounded),
              label: Text(isExtracting ? '正在生成图片…' : '使用这一帧'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
