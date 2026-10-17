// Conditional imports for platform-specific implementations
import 'web_download_helper_stub.dart'
    if (dart.library.html) 'web_download_helper_web.dart';

/// Abstract class for downloading SVG files
abstract class WebDownloadHelper {
  /// Factory constructor that returns the appropriate implementation
  factory WebDownloadHelper() => createWebDownloadHelper();

  /// Download SVG content as a file
  Future<void> downloadSVG(String svgContent, String filename);
}
