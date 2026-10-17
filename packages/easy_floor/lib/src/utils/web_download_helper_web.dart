// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'web_download_helper.dart';

/// Web implementation for downloading SVG files
class WebDownloadHelperWeb implements WebDownloadHelper {
  @override
  Future<void> downloadSVG(String svgContent, String filename) async {
    final blob = html.Blob([svgContent], 'image/svg+xml');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

/// Function to create WebDownloadHelper - web version
WebDownloadHelper createWebDownloadHelper() => WebDownloadHelperWeb();
