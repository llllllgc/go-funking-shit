import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/app_information.dart';
import '../domain/app_documents.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({
    this.information = const DeviceAppInformation(),
    super.key,
  });
  final AppInformation information;
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  InstalledAppVersion? _version;
  AppDocumentation? _documentation;
  bool _versionBusy = true;
  bool _docsBusy = true;
  bool _copyBusy = false;
  String? _copyMessage;

  @override
  void initState() {
    super.initState();
    _readVersion();
    _readDocuments();
  }

  Future<void> _readVersion() async {
    setState(() => _versionBusy = true);
    InstalledAppVersion? value;
    try {
      value = await widget.information.readVersion();
    } catch (_) {
      /* Retry stays available. */
    }
    if (mounted) {
      setState(() {
        _version = value;
        _versionBusy = false;
      });
    }
  }

  Future<void> _readDocuments() async {
    setState(() => _docsBusy = true);
    AppDocumentation? value;
    try {
      value = await widget.information.readDocumentation();
    } catch (_) {
      /* Do not replace policy with guessed text. */
    }
    if (mounted) {
      setState(() {
        _documentation = value;
        _docsBusy = false;
      });
    }
  }

  Future<void> _copyVersion() async {
    if (_copyBusy || _version == null) return;
    setState(() {
      _copyBusy = true;
      _copyMessage = null;
    });
    var success = false;
    try {
      await Clipboard.setData(ClipboardData(text: _version!.copyText));
      success = true;
    } catch (_) {
      /* No success message on failure. */
    }
    if (mounted) {
      setState(() {
        _copyBusy = false;
        _copyMessage = success ? '版本信息已复制，不含记录内容' : '没有复制成功，请重试。';
      });
    }
  }

  void _document(
    AppDocument document, {
    bool expand = false,
    bool privacy = false,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AppDocumentScreen(
          document: document,
          updatedOn: _documentation!.documents.updatedOn,
          publishing: privacy ? _documentation!.publishing : null,
          information: widget.information,
          expandable: expand,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _documentation?.documents;
    final publisher = _documentation?.publishing;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '帮助与关于',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: pixelStyle(size: 20),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('拉了么？', style: pixelStyle(size: 30, height: 1.4)),
                const SizedBox(height: 8),
                const Text(
                  '把每次记录留在自己手里。',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
                const SizedBox(height: 16),
                if (_versionBusy)
                  const Text('正在读取版本…')
                else if (_version != null)
                  Text('版本 ${_version!.label}', key: const Key('about-version'))
                else
                  Row(
                    children: [
                      const Expanded(child: Text('暂时无法读取版本')),
                      TextButton(
                        key: const Key('about-version-retry'),
                        onPressed: _readVersion,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('about-copy-version'),
                    onPressed: _version == null || _copyBusy
                        ? null
                        : _copyVersion,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('复制版本信息'),
                  ),
                ),
                if (_copyMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _copyMessage!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 20),
                if (_docsBusy)
                  const LinearProgressIndicator()
                else if (docs == null) ...[
                  const Text('使用说明暂时无法读取，其他功能仍可使用。'),
                  TextButton(
                    key: const Key('about-docs-retry'),
                    onPressed: _readDocuments,
                    child: const Text('重新读取说明'),
                  ),
                ],
                _MenuLink(
                  key: const Key('about-help'),
                  title: '使用帮助',
                  subtitle: '记录、备份、应用锁与提醒',
                  icon: Icons.help_outline,
                  onPressed: docs == null
                      ? null
                      : () => _document(docs.help, expand: true),
                ),
                _MenuLink(
                  key: const Key('about-privacy'),
                  title: '隐私与数据',
                  subtitle: '保存范围、删除与第三方服务',
                  icon: Icons.privacy_tip_outlined,
                  onPressed: docs == null
                      ? null
                      : () => _document(docs.privacy, privacy: true),
                ),
                _MenuLink(
                  key: const Key('about-changes'),
                  title: '版本更新',
                  subtitle: '查看近期改进',
                  icon: Icons.history,
                  onPressed: docs == null
                      ? null
                      : () => _document(docs.changes),
                ),
                _MenuLink(
                  key: const Key('about-licenses'),
                  title: '开源组件许可',
                  subtitle: '查看应用所用组件的许可声明',
                  icon: Icons.article_outlined,
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: '拉了么？',
                    applicationVersion: _version?.label,
                  ),
                ),
                const Divider(height: 36),
                Text('问题反馈', style: pixelStyle(size: 20, height: 1.4)),
                const SizedBox(height: 8),
                const Text('可以提供版本信息、操作步骤、期望结果和实际结果。请勿公开发送个人记录、备份文件或未经处理的截图。'),
                if (publisher != null) ...[
                  if (publisher.publisherName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('发布者：${publisher.publisherName}'),
                    ),
                  if (publisher.supportUrl != null)
                    _ExternalAction(
                      key: const Key('about-support'),
                      uri: publisher.supportUrl!,
                      label: '打开支持联系方式',
                      information: widget.information,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '此安装包未提供公开支持渠道。你可以复制版本信息，联系提供安装包的人。',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
                const Divider(height: 36),
                Text('资源出处', style: pixelStyle(size: 20, height: 1.4)),
                const SizedBox(height: 8),
                const Text('像素字体：Zpix · SolidZORO。科普资料的具体来源在每张小纸条中列出。'),
                _ExternalAction(
                  uri: Uri.parse(
                    'https://github.com/SolidZORO/zpix-pixel-font',
                  ),
                  label: 'Zpix 字体说明（联网）',
                  information: widget.information,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuLink extends StatelessWidget {
  const _MenuLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    super.key,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, height: 1.5)),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
}

class AppDocumentScreen extends StatelessWidget {
  const AppDocumentScreen({
    required this.document,
    required this.updatedOn,
    required this.information,
    this.publishing,
    this.expandable = false,
    super.key,
  });
  final AppDocument document;
  final String updatedOn;
  final PublishingInfo? publishing;
  final AppInformation information;
  final bool expandable;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        document.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: pixelStyle(size: 20),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '更新日期：$updatedOn',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              for (final section in document.sections)
                if (expandable)
                  ExpansionTile(
                    key: PageStorageKey('help-${section.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      section.title,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    children: [_Paragraphs(paragraphs: section.paragraphs)],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _Paragraphs(paragraphs: section.paragraphs),
                      ],
                    ),
                  ),
              if (publishing != null) ...[
                const Divider(height: 32),
                Text('发布与联系', style: pixelStyle(size: 20, height: 1.4)),
                const SizedBox(height: 8),
                Text(
                  publishing!.publisherName == null
                      ? '此安装包未提供发布者名称。'
                      : '发布者：${publishing!.publisherName}',
                ),
                if (publishing!.supportUrl != null)
                  _ExternalAction(
                    uri: publishing!.supportUrl!,
                    label: '打开支持联系方式',
                    information: information,
                  )
                else
                  const Text('尚无公开联系渠道，请联系提供安装包的人。'),
                if (publishing!.privacyPolicyUrl != null)
                  _ExternalAction(
                    uri: publishing!.privacyPolicyUrl!,
                    label: '查看在线隐私政策',
                    information: information,
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Paragraphs extends StatelessWidget {
  const _Paragraphs({required this.paragraphs});
  final List<String> paragraphs;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final paragraph in paragraphs)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(paragraph, style: const TextStyle(height: 1.6)),
        ),
    ],
  );
}

class _ExternalAction extends StatefulWidget {
  const _ExternalAction({
    required this.uri,
    required this.label,
    required this.information,
    super.key,
  });
  final Uri uri;
  final String label;
  final AppInformation information;
  @override
  State<_ExternalAction> createState() => _ExternalActionState();
}

class _ExternalActionState extends State<_ExternalAction> {
  bool _busy = false;
  bool _failed = false;
  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await widget.information.open(widget.uri);
    } catch (_) {
      /* A selectable URL remains available. */
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: _busy ? null : _open,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(widget.label),
      ),
      if (_failed) ...[
        const Text('未能打开，可选择下方地址复制后自行访问。', style: TextStyle(fontSize: 13)),
        SelectableText(
          widget.uri.toString(),
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
      ],
    ],
  );
}
