import 'web_download_helper.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Stub implementation for non-web platforms
class WebDownloadHelperStub implements WebDownloadHelper {
  @override
  Future<void> downloadSVG(String svgContent, String filename) async {
    final target = await FilePicker.platform.saveFile(
      dialogTitle: 'Save floor plan',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['svg'],
      bytes: Uint8List.fromList(utf8.encode(svgContent)),
    );
    if (target == null) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(target).writeAsString(svgContent, encoding: utf8);
    }
  }
}

/// Function to create WebDownloadHelper - stub version
WebDownloadHelper createWebDownloadHelper() => WebDownloadHelperStub();
