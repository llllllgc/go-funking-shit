import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/app_documents.dart';

class InstalledAppVersion {
  const InstalledAppVersion({
    required this.name,
    required this.version,
    required this.build,
    required this.platform,
  });
  final String name;
  final String version;
  final String build;
  final String platform;
  String get label => build.isEmpty ? version : '$version（$build）';
  String get copyText => '$name\n版本：$label\n平台：$platform';
}

class AppDocumentation {
  const AppDocumentation({required this.documents, required this.publishing});
  final AppDocuments documents;
  final PublishingInfo publishing;
}

abstract interface class AppInformation {
  Future<InstalledAppVersion> readVersion();
  Future<AppDocumentation> readDocumentation();
  Future<bool> open(Uri uri);
}

class DeviceAppInformation implements AppInformation {
  const DeviceAppInformation();
  @override
  Future<InstalledAppVersion> readVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (info.version.trim().isEmpty) {
      throw const FormatException('Missing installed version');
    }
    return InstalledAppVersion(
      name: info.appName.isEmpty ? '拉了么？' : info.appName,
      version: info.version,
      build: info.buildNumber,
      platform: Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid
          ? 'Android'
          : Platform.operatingSystem,
    );
  }

  @override
  Future<AppDocumentation> readDocumentation() async {
    final values = await Future.wait([
      rootBundle.loadString('assets/content/app_documents.json'),
      rootBundle.loadString('assets/content/publishing.json'),
    ]);
    return AppDocumentation(
      documents: AppDocuments.fromJson(
        jsonDecode(values[0]) as Map<String, dynamic>,
      ),
      publishing: PublishingInfo.fromJson(
        jsonDecode(values[1]) as Map<String, dynamic>,
      ),
    );
  }

  @override
  Future<bool> open(Uri uri) async {
    if (!canOpenAppLink(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
