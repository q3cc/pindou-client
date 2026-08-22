import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/pattern_recognition.dart';
import '../services/parser_service.dart';
import 'pattern_result_screen.dart';

class LegendReviewScreen extends StatefulWidget {
  const LegendReviewScreen({
    required this.parserService,
    required this.legendImage,
    required this.patternImage,
    this.title = '',
    super.key,
  });

  final ParserService parserService;
  final Uint8List legendImage;
  final Uint8List patternImage;
  final String title;

  @override
  State<LegendReviewScreen> createState() => _LegendReviewScreenState();
}

class _LegendReviewScreenState extends State<LegendReviewScreen> {
  final List<LegendEntry> _items = [];
  bool _isLoading = true;
  bool _isRecognizingPattern = false;
  String? _error;

  int get _total => _items.fold(0, (sum, item) => sum + item.count);

  @override
  void initState() {
    super.initState();
    _recognizeLegend();
  }

  Future<void> _recognizeLegend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.parserService.recognizeLegend(widget.legendImage);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _isLoading = false;
      });
    } on ParseException catch (error) {
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
          _error = '图例暂时无法识别，请重新框选后再试';
        });
      }
    }
  }

  Future<void> _editItem(int? index) async {
    final current = index == null
        ? const LegendEntry(code: '', count: 0, color: '#FFFFFF', confidence: 1)
        : _items[index];
    final codeController = TextEditingController(text: current.code);
    final countController = TextEditingController(text: current.count == 0 ? '' : '${current.count}');
    final colorController = TextEditingController(text: current.color);
    final result = await showDialog<LegendEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? '补充一种材料' : '修正材料'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: '色号，例如 H7'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '数量'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: '颜色，例如 #1A1A1A'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final code = codeController.text.trim().toUpperCase();
              final count = int.tryParse(countController.text.trim()) ?? 0;
              final color = colorController.text.trim().toUpperCase();
              if (!RegExp(r'^[A-Z][0-9]{1,3}$').hasMatch(code) ||
                  count <= 0 ||
                  !RegExp(r'^#[0-9A-F]{6}$').hasMatch(color)) {
                return;
              }
              Navigator.pop(
                context,
                LegendEntry(code: code, count: count, color: color, confidence: 1),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    codeController.dispose();
    countController.dispose();
    colorController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
    });
  }

  Future<void> _recognizePattern() async {
    if (_items.isEmpty) {
      setState(() => _error = '请先确认至少一种材料');
      return;
    }
    setState(() {
      _isRecognizingPattern = true;
      _error = null;
    });
    try {
      final result = await widget.parserService.recognizePattern(widget.patternImage, _items);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PatternResultScreen(
            title: widget.title,
            result: result,
            legend: _items,
          ),
        ),
      );
    } on ParseException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '图纸暂时无法识别，请检查裁剪范围');
    } finally {
      if (mounted) setState(() => _isRecognizingPattern = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('核对材料图例')),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editItem(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('补充材料'),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                  padding: EdgeInsets.all(constraints.maxWidth >= 600 ? 24 : 16),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('材料总计 $_total 颗', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('共识别 ${_items.length} 种材料。进入图纸识别前请先核对色号和数量。'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 180, height: 64, child: Image.memory(widget.legendImage, fit: BoxFit.contain)),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _recognizeLegend,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新识别图例'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      color: item.needsReview
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.surface,
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: _parseColor(item.color)),
                        title: Text(item.code, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(item.needsReview ? '识别结果不确定，请核对' : '识别可信度 ${(item.confidence * 100).round()}%'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${item.count} 颗'),
                            IconButton(
                              tooltip: '修正',
                              onPressed: () => _editItem(index),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: '删除',
                              onPressed: () => setState(() => _items.removeAt(index)),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isRecognizingPattern || _items.isEmpty ? null : _recognizePattern,
          icon: _isRecognizingPattern
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.grid_on_rounded),
          label: Text(_isRecognizingPattern ? '正在识别图纸…' : '图例正确，识别图纸'),
        ),
      ],
    );
  }
}

Color _parseColor(String value) {
  final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | (parsed ?? 0xFFFFFF));
}
