import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../data/source_links.dart';
import '../domain/knowledge_tip.dart';

class KnowledgeSources extends StatelessWidget {
  const KnowledgeSources({
    required this.sources,
    this.links = const ExternalSourceLinks(),
    super.key,
  });
  final List<KnowledgeSource> sources;
  final SourceLinks links;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '参考来源',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      const Text(
        '英文原文 · 需联网',
        style: TextStyle(color: AppColors.inkMuted, fontSize: 11, height: 1.5),
      ),
      for (final source in sources)
        _SourceReference(
          key: ValueKey(source.id),
          source: source,
          links: links,
        ),
    ],
  );
}

class _SourceReference extends StatefulWidget {
  const _SourceReference({
    required this.source,
    required this.links,
    super.key,
  });
  final KnowledgeSource source;
  final SourceLinks links;
  @override
  State<_SourceReference> createState() => _SourceReferenceState();
}

class _SourceReferenceState extends State<_SourceReference> {
  bool _busy = false;
  bool _showUrl = false;
  String? _message;

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    var opened = false;
    try {
      opened = await widget.links.open(widget.source);
    } catch (_) {
      /* Offer the public link below. */
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!opened) {
        _showUrl = true;
        _message = '未能打开浏览器。可以复制链接后自行打开。';
      }
    });
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    var copied = false;
    try {
      await Clipboard.setData(ClipboardData(text: widget.source.url));
      copied = true;
    } catch (_) {
      /* Keep a selectable fallback. */
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _showUrl = true;
      _message = copied ? '来源链接已复制' : '未能复制。可长按下方链接选择复制。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.organization,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
          Text(source.title, style: const TextStyle(fontSize: 13, height: 1.5)),
          Text(
            '内容核对：${source.checkedOn}',
            style: const TextStyle(
              color: AppColors.inkMuted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              Semantics(
                button: true,
                enabled: !_busy,
                excludeSemantics: true,
                label: '打开原文：${source.title}，${source.organization}，需要联网',
                onTap: _busy ? null : _open,
                child: TextButton.icon(
                  key: ValueKey('source-open-${source.id}'),
                  onPressed: _busy ? null : _open,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('打开原文'),
                ),
              ),
              Semantics(
                button: true,
                enabled: !_busy,
                excludeSemantics: true,
                label: '复制来源链接：${source.title}',
                onTap: _busy ? null : _copy,
                child: TextButton(
                  key: ValueKey('source-copy-${source.id}'),
                  onPressed: _busy ? null : _copy,
                  child: const Text('复制链接'),
                ),
              ),
            ],
          ),
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          if (_showUrl)
            SelectableText(
              source.url,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}
