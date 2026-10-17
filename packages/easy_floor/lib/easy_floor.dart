/// Floor Plan Editor Package
///
/// A Flutter package for creating and editing floor plan blueprints
/// with rooms, doors, and SVG export/import capabilities.
library;

// Export models
export 'src/models/room.dart';
export 'src/models/door.dart';
export 'src/models/resize_handle.dart';

// Export widgets
export 'src/widgets/floor_plan_editor.dart';
export 'src/widgets/floor_painter.dart';

// Export utilities (optional - for advanced usage)
export 'src/utils/path_utils.dart';
export 'src/utils/svg_parser.dart';
export 'src/utils/web_download_helper.dart';
