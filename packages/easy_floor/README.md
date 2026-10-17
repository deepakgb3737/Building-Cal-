# EasyFloor

A Flutter package for creating and editing floor plan blueprints with rooms, doors, and SVG export/import capabilities.

## Features

- 🏠 **Multiple Room Shapes**: Rectangle, L-shape, U-shape, T-shape, and Circular rooms
- ✏️ **Freehand Drawing**: Draw custom room shapes with pencil mode
- 🚪 **Door Management**: Add doors to rooms with automatic opening detection
- 🎨 **Color Customization**: Choose from a palette of colors for rooms
- 📐 **Room Manipulation**: Move, resize, and rotate rooms
- 📝 **Room Naming**: Edit room names and view dimensions
- 📊 **Area Calculation**: Automatic area calculation in m²
- 💾 **SVG Import/Export**: Load and save floor plans as SVG files
- 🌐 **Web Support**: Full support for web platform with file download

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  easy_floor:
    path: packages/easy_floor
```


## Usage

### Basic Usage

```dart
import 'package:easy_floor/easy_floor.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: FloorPlanEditor(),
      ),
    );
  }
}
```

### With Callbacks

```dart
FloorPlanEditor(
  onChanged: (rooms, doors) {
    // Handle changes to rooms or doors
    print('Rooms: ${rooms.length}, Doors: ${doors.length}');
  },
  onSave: (svgContent) {
    // Handle SVG save
    print('SVG content length: ${svgContent.length}');
  },
  initialRooms: [
    Room(
      id: 'room1',
      path: Path()..addRect(Rect.fromLTWH(0, 0, 200, 150)),
      name: 'Living Room',
    ),
  ],
  canvasColor: Colors.blue.shade50,
  showToolbar: true,
  showSidebars: true,
)
```

## API Reference

### FloorPlanEditor

Main widget for the floor plan editor.

**Properties:**
- `onChanged`: Callback when rooms or doors change
- `onSave`: Callback when save is triggered (receives SVG content)
- `initialRooms`: Initial list of rooms to load
- `initialDoors`: Initial list of doors to load
- `canvasColor`: Background color of the canvas
- `showToolbar`: Whether to show the top toolbar
- `showSidebars`: Whether to show the left and right sidebars

### Room

Represents a room in the floor plan.

**Properties:**
- `id`: Unique identifier
- `path`: Flutter Path object defining the room shape
- `fillColor`: Room fill color
- `name`: Room name
- `doorOpenings`: List of door opening paths

### Door

Represents a door in the floor plan.

**Properties:**
- `id`: Unique identifier
- `path`: Flutter Path object defining the door shape
- `rotation`: Rotation angle in degrees
- `roomId`: Reference to the room this door belongs to
- `edge`: Which edge the door is on ('top', 'bottom', 'left', 'right')

## Features in Detail

### Creating Rooms

1. **Predefined Shapes**: Click on shape buttons in the right sidebar (Square, L-shape, U-shape, T-shape, Circular)
2. **Freehand Drawing**: Click the "Walls" button to enable pencil mode, then drag to draw custom shapes

### Adding Doors

1. Select a room
2. Click "Add Door" in the right sidebar
3. Click on a border edge of the room to place the door

### Editing Rooms

- **Move**: Click and drag a room
- **Resize**: Click and drag the corner handles
- **Rotate**: Click the rotation button in the left sidebar
- **Change Color**: Click the color button or use the color palette
- **Rename**: Click on the room name in the contextual bar

### Import/Export

- **Open**: Click "Open" to load an SVG file
- **Save**: Click "Save" to export the floor plan as SVG

## Platform Support

- ✅ Web (full support with file download)
- ✅ Mobile (iOS/Android - SVG export limited)
- ✅ Desktop (Windows/Mac/Linux - SVG export limited)

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


## Local fixes

Room area now follows the outline, including concave shapes and rotated rooms.
Coordinates use 100 drawing units per metre (the dimensions shown in centimetres).
Curves are sampled every 0.25 drawing units, so curved area is approximate.
Use simple closed room outlines; overlapping or self-intersecting contours are
not supported as measurement geometry. Holes must use opposite contour winding.

SVG opening now reads UTF-8 file bytes on web and native platforms. Native saving
uses the platform file picker; desktop writes the selected file, while mobile
uses the file picker's document save operation. Cancelling the dialog leaves the
plan unchanged. Keep the supplied MIT license when reusing this package.

Below 760px the sidebars become drawers, leaving room for the canvas. The top
and contextual toolbars scroll horizontally. Tests cover room area and the
320px-wide editor. Native file dialogs still require device verification.

Drawn rooms now retain numbered wall vertices. Select a drawn room and choose
Edit wall lengths to set one wall in metres, feet or millimetres. The starting
corner stays fixed; axis-aligned connected walls move with the edited endpoint.
Diagonal edits move the endpoint and adjust its neighbours. Invalid intersections
and collapsed walls are rejected. Remove doors before individual-wall edits and
place them again afterward. Predefined shapes without stored vertices retain
whole-room resizing. Wall vertices survive EasyFloor SVG export/import.

Pencil outlines smooth small drawing slips with a size-aware 4–12 drawing-unit
threshold. Short out-and-back excursions are removed. End close to the starting
point to snap the outline shut; a visibly open stroke shows a message rather than
creating an unintended closing wall. Completed rooms are selected automatically.

## BuildCalc site notebook workflow

BuildCalc uses a compact Draw room / Undo / Redo / Open / Save toolbar and hides
legacy shape/color sidebars. Undo/Redo keeps up to 30 completed edits in the
current session; one drag is one edit. Exact wall measurements remain available
alongside hand resizing. Invalid crossed, overlapping or collapsed outlines are
rejected. Room names containing XML characters are escaped and restored on open.

Interaction references reviewed:
- https://help.magicplan.app/create-a-room-with-the-define-corners-feature
- https://help.magicplan.app/migration/change-dimensions-of-your-floor-plan
- https://www.roomsketcher.com/features/draw-floor-plans/
