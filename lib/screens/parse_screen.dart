import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/media_headers.dart';
import '../models/prepared_image.dart';
import '../models/parsed_media.dart';
import '../services/parser_service.dart';
import '../widgets/adaptive_content_shell.dart';
import '../workflow/media_flow.dart';
import 'frame_picker_screen.dart';
import 'image_ready_screen.dart';

class ParseScreen extends StatefulWidget {
  const ParseScreen({required this.parserService, super.key});

  final ParserService parserService;

  @override
  State<ParseScreen> createState() => _ParseScreenState();
}

class _ParseScreenState extends State<ParseScreen> {
  final _textController = TextEditingController();
  bool _isParsing = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) {
      return;
    }
    _textController.text = data!.text!.trim();
    setState(() => _error = null);
  }

  Future<void> _parse() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请先粘贴分享链接或分享文案');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isParsing = true;
      _error = null;
    });

    try {
      final media = await widget.parserService.parse(text);
      if (!mounted) return;
      await _continueWith(media);
    } on ParseException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法完成解析，请稍后再试');
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  Future<void> _continueWith(ParsedMedia media) async {
    switch (nextStepFor(media)) {
      case MediaFlowStep.imageReady:
        final headers = mediaHeaders(media.platform);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ImageReadyScreen(
              title: media.title,
              images: [
                for (var index = 0; index < media.images.length; index++)
                  PreparedImage.network(
                    label: '图片 ${index + 1}',
                    url: media.images[index],
                    headers: headers,
                  ),
              ],
            ),
          ),
        );
        return;
      case MediaFlowStep.framePicker:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FramePickerScreen(media: media),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = _ParseCard(
      controller: _textController,
      isParsing: _isParsing,
      error: _error,
      onPaste: _paste,
      onParse: _parse,
    );
    const guide = _GuideCard();

    return Scaffold(
      appBar: AppBar(
        title: const Text('拼豆'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AdaptiveContentShell(
            compact: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const SizedBox(height: 16), guide],
            ),
            expanded: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: form),
                const SizedBox(width: 24),
                const Expanded(flex: 4, child: guide),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParseCard extends StatelessWidget {
  const _ParseCard({
    required this.controller,
    required this.isParsing,
    required this.error,
    required this.onPaste,
    required this.onParse,
  });

  final TextEditingController controller;
  final bool isParsing;
  final String? error;
  final VoidCallback onPaste;
  final VoidCallback onParse;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('从一个链接开始', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '支持抖音和小红书的公开分享内容。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: '分享链接或分享文案',
                hintText: '粘贴从抖音或小红书复制的内容',
                errorText: error,
                suffixIcon: IconButton(
                  tooltip: '粘贴',
                  onPressed: isParsing ? null : onPaste,
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(avatar: Icon(Icons.music_note_rounded), label: Text('抖音')),
                Chip(avatar: Icon(Icons.auto_awesome_rounded), label: Text('小红书')),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isParsing ? null : onParse,
              icon: isParsing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(isParsing ? '正在获取内容…' : '获取内容'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('处理方式', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            const _GuideStep(
              number: '1',
              title: '粘贴分享内容',
              description: '自动识别抖音或小红书。',
            ),
            const _GuideStep(
              number: '2',
              title: '获取图片',
              description: '普通图片会直接准备好，无需额外操作。',
            ),
            const _GuideStep(
              number: '3',
              title: '选取动态画面',
              description: '实况或视频可以拖动时间轴，选择最合适的一帧。',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, child: Text(number)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
