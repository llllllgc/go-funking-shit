import 'dart:convert';
import 'dart:io';
import 'package:lalema/domain/app_documents.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final requirePublisher = args.contains('--require-publisher');
  final documents = AppDocuments.fromJson(
    jsonDecode(File('assets/content/app_documents.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final publisher = PublishingInfo.fromJson(
    jsonDecode(File('assets/content/publishing.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final draft = !publisher.hasPublisherContact || !publisher.hasPublicPolicyUrl;
  final policyTitle = draft ? '拉了么？隐私政策（发布草案）' : '拉了么？隐私政策';
  final policy = StringBuffer(
    '# $policyTitle\n\n更新日期：${documents.updatedOn}\n\n',
  );
  if (draft) policy.writeln('> 发布者名称、支持联系方式或公开政策地址尚未配置。本草案不能视为已完成商店发布审核。\n');
  policy.writeln('发布者：${publisher.publisherName ?? '待发布者确认'}\n');
  policy.writeln('支持与隐私联系：${publisher.supportUrl?.toString() ?? '待发布者确认'}\n');
  policy.writeln(
    '公开政策地址：${publisher.privacyPolicyUrl?.toString() ?? '待发布者确认'}\n',
  );
  for (final section in documents.privacy.sections) {
    policy.writeln('## ${section.title}\n');
    for (final paragraph in section.paragraphs) {
      policy.writeln('$paragraph\n');
    }
  }
  final outputs = <String, String>{
    'docs/release/privacy-policy.md': policy.toString(),
    'docs/release/privacy-policy.html': _html(
      policyTitle,
      documents.privacy,
      documents.updatedOn,
      publisher,
      draft,
    ),
    'docs/release/user-guide.md': _markdown(
      documents.help,
      documents.updatedOn,
    ),
    'docs/release/user-guide.html': _html(
      documents.help.title,
      documents.help,
      documents.updatedOn,
      null,
      false,
    ),
    'docs/release/changelog.md': _markdown(
      documents.changes,
      documents.updatedOn,
    ),
  };
  var mismatched = false;
  for (final entry in outputs.entries) {
    final file = File(entry.key);
    if (check) {
      if (!file.existsSync() || file.readAsStringSync() != entry.value) {
        stderr.writeln('Outdated generated document: ${entry.key}');
        mismatched = true;
      }
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }
  }
  if (requirePublisher && draft) {
    stderr.writeln(
      'Publisher name, support URL and public privacy policy URL must be provided before publication.',
    );
    exitCode = 1;
  }
  if (mismatched) exitCode = 1;
  if (exitCode == 0) {
    stdout.writeln(
      check
          ? 'App documents match generated release files.'
          : 'Exported app documents. Publisher status: ${draft ? 'incomplete' : 'fields present; live verification still required'}.',
    );
  }
}

String _markdown(AppDocument document, String date) {
  final output = StringBuffer('# ${document.title}\n\n更新日期：$date\n\n');
  for (final section in document.sections) {
    output.writeln('## ${section.title}\n');
    for (final paragraph in section.paragraphs) {
      output.writeln('$paragraph\n');
    }
  }
  return output.toString();
}

String _html(
  String title,
  AppDocument document,
  String date,
  PublishingInfo? publisher,
  bool draft,
) {
  const escape = HtmlEscape();
  String e(String value) => escape.convert(value);
  final body = StringBuffer(
    '<h1>${e(title)}</h1>\n<p class="meta">更新日期：${e(date)}</p>\n',
  );
  if (draft) {
    body.writeln('<aside>发布草案：发布者名称、支持联系方式或公开政策地址待确认，不代表已完成发布审核。</aside>');
  }
  if (publisher != null) {
    body.writeln('<p>发布者：${e(publisher.publisherName ?? '待发布者确认')}</p>');
    body.writeln(
      publisher.supportUrl == null
          ? '<p>支持与隐私联系：待发布者确认</p>'
          : '<p>支持与隐私联系：<a href="${e(publisher.supportUrl.toString())}">${e(publisher.supportUrl.toString())}</a></p>',
    );
    body.writeln(
      publisher.privacyPolicyUrl == null
          ? '<p>公开政策地址：待发布者确认</p>'
          : '<p>公开政策地址：<a href="${e(publisher.privacyPolicyUrl.toString())}">${e(publisher.privacyPolicyUrl.toString())}</a></p>',
    );
  }
  for (final section in document.sections) {
    body.writeln('<section><h2>${e(section.title)}</h2>');
    for (final paragraph in section.paragraphs) {
      body.writeln('<p>${e(paragraph)}</p>');
    }
    body.writeln('</section>');
  }
  return '''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${e(title)}</title>
<style>body{margin:0;background:#f7f4ea;color:#1f292b;font:16px/1.8 system-ui,-apple-system,"PingFang SC",sans-serif}main{max-width:760px;margin:auto;padding:32px 24px 64px}h1{font-size:28px;line-height:1.4}h2{font-size:20px;margin-top:30px}p{overflow-wrap:anywhere}.meta{color:#68706c;font-size:14px}aside{padding:16px;border:1px solid #a9a79a;background:#fffdf7}a{color:#4f6847}a:focus-visible{outline:3px solid #4f6847;outline-offset:4px}@media(max-width:420px){main{padding:24px 18px}h1{font-size:24px}}</style>
</head><body><main>
$body</main></body></html>
''';
}
