import 'package:flutter/material.dart';

import '../models/prepared_image.dart';
import '../services/parser_service.dart';
import 'template_crop_screen.dart';

class ImageReadyScreen extends StatelessWidget {
  const ImageReadyScreen({
    required this.images,
    required this.parserService,
    this.title = '',
    super.key,
  });

  final List<PreparedImage> images;
  final ParserService parserService;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片已准备好')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 20, padding, 12),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _Header(title: title, count: images.length),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, sliverConstraints) {
                      return SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _ImageTile(
                            image: images[index],
                            onUseTemplate: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TemplateCropScreen(
                                  source: images[index],
                                  parserService: parserService,
                                  title: title,
                                ),
                              ),
                            ),
                          ),
                          childCount: images.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选择模板原图', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    title.isEmpty
                        ? '从其中一张图连续框选材料图例和豆图网格'
                        : '$title · 共 $count 张图片',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.image, required this.onUseTemplate});

  final PreparedImage image;
  final VoidCallback onUseTemplate;

  @override
  Widget build(BuildContext context) {
    final imageWidget = image.bytes != null
        ? Image.memory(image.bytes!, fit: BoxFit.contain)
        : Image.network(
            image.networkUrl!.toString(),
            headers: image.headers,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, _, _) => const Center(child: Text('图片加载失败')),
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.04),
              child: InteractiveViewer(child: Center(child: imageWidget)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(image.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: onUseTemplate,
                  icon: const Icon(Icons.crop_rounded),
                  label: const Text('从这张图识别豆图'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
