import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../models/prepared_image.dart';
import '../services/parser_service.dart';
import '../services/prepared_image_loader.dart';
import 'legend_review_screen.dart';

enum _CropStage { legend, pattern }

class TemplateCropScreen extends StatefulWidget {
  const TemplateCropScreen({
    required this.source,
    required this.parserService,
    this.title = '',
    super.key,
  });

  final PreparedImage source;
  final ParserService parserService;
  final String title;

  @override
  State<TemplateCropScreen> createState() => _TemplateCropScreenState();
}

class _TemplateCropScreenState extends State<TemplateCropScreen> {
  CropController _controller = CropController();
  Uint8List? _sourceBytes;
  Uint8List? _legendBytes;
  _CropStage _stage = _CropStage.legend;
  bool _isLoading = true;
  bool _isCropping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await loadPreparedImage(widget.source);
      if (!mounted) return;
      setState(() {
        _sourceBytes = bytes;
        _isLoading = false;
      });
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '模板图片暂时无法打开，请重新解析';
        });
      }
    }
  }

  void _startCrop() {
    if (_sourceBytes == null || _isCropping) return;
    setState(() {
      _isCropping = true;
      _error = null;
    });
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        if (_stage == _CropStage.legend) {
          setState(() {
            _legendBytes = croppedImage;
            _stage = _CropStage.pattern;
            _controller = CropController();
            _isCropping = false;
          });
          return;
        }
        final legend = _legendBytes;
        if (legend == null) {
          setState(() {
            _isCropping = false;
            _error = '请先框选材料图例';
          });
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => LegendReviewScreen(
              parserService: widget.parserService,
              legendImage: legend,
              patternImage: croppedImage,
              title: widget.title,
            ),
          ),
        );
      case CropFailure(:final cause):
        setState(() {
          _isCropping = false;
          _error = '裁剪失败：$cause';
        });
    }
  }

  void _backToLegend() {
    setState(() {
      _stage = _CropStage.legend;
      _legendBytes = null;
      _controller = CropController();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = _sourceBytes;
    return Scaffold(
      appBar: AppBar(title: Text(_stage == _CropStage.legend ? '框选材料图例' : '框选豆图网格')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : source == null
                ? _ErrorState(message: _error ?? '模板图片无法打开')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final editor = Card(
                        clipBehavior: Clip.antiAlias,
                        color: Colors.black,
                        child: Crop(
                          key: ValueKey(_stage),
                          image: source,
                          controller: _controller,
                          onCropped: _onCropped,
                          interactive: true,
                          fixCropRect: false,
                          baseColor: Colors.black,
                          maskColor: Colors.black.withValues(alpha: 0.62),
                          cornerDotBuilder: (size, edgeAlignment) => DotControl(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                            size: _stage == _CropStage.legend ? 0.62 : 0.84,
                            aspectRatio: _stage == _CropStage.legend ? 7 : 1,
                          ),
                          progressIndicator: const CircularProgressIndicator(),
                        ),
                      );
                      final controls = _CropControls(
                        stage: _stage,
                        isCropping: _isCropping,
                        error: _error,
                        legendPreview: _legendBytes,
                        onCrop: _startCrop,
                        onBack: _backToLegend,
                      );
                      if (constraints.maxWidth >= 900) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 7, child: editor),
                              const SizedBox(width: 24),
                              SizedBox(width: 330, child: SingleChildScrollView(child: controls)),
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Expanded(child: editor),
                            const SizedBox(height: 16),
                            controls,
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _CropControls extends StatelessWidget {
  const _CropControls({
    required this.stage,
    required this.isCropping,
    required this.error,
    required this.legendPreview,
    required this.onCrop,
    required this.onBack,
  });

  final _CropStage stage;
  final bool isCropping;
  final String? error;
  final Uint8List? legendPreview;
  final VoidCallback onCrop;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isLegend = stage == _CropStage.legend;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isLegend ? '第一步 · 材料图例' : '第二步 · 豆图网格',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              isLegend
                  ? '移动和缩放原图，让选框只保留“色号 + 数量”列表。'
                  : '再次在同一张原图中框选完整网格，尽量保留四周的行列编号。',
            ),
            if (legendPreview != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(legendPreview!, height: 72, fit: BoxFit.contain),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isCropping ? null : onCrop,
              icon: isCropping
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLegend ? Icons.looks_one_rounded : Icons.looks_two_rounded),
              label: Text(isCropping
                  ? '正在裁剪…'
                  : isLegend
                      ? '保存图例，继续框选图纸'
                      : '保存图纸并开始识别'),
            ),
            if (!isLegend) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: isCropping ? null : onBack, child: const Text('重新框选图例')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}
