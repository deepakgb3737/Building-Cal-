# EasyFloor Documents And Smart Defaults

Updated 2026-10-15. This extends the existing drawing engine; geometry and text
remain separate layers. No cloud, accounts, export or new architectural objects
are included.

## Workspace

- Smart touch, endpoint snapping, horizontal/vertical assistance and shape
  recognition start enabled. Diagonal and irregular outlines remain available.
  Basic endpoint connections now remain enabled even when loading older
  documents whose saved snapping preference was off.
- Contextual measurements and temporary guides retain their existing behavior;
  guides default to 50% opacity. Show labels remains an explicit all-wall choice.
- Text, Single wall and Freehand remain directly accessible, with automatic touch
  editing. Shapes opens the shape grid; More holds help, Cancel and drawing
  assistance. Pan remains a direct toolbar action.
- Documents is the folder menu: Save, Save As, New Document, Open Document and
  Close Document. The title shows the document name and `*` for unsaved changes.
- Open Document lists saved plans, modified dates and the current document.
  Each row's menu provides rename and confirmed deletion. Deleting the current
  saved copy does not delete its open geometry; it becomes an unsaved document.

## Persistence And Boundaries

`logic/floor_document.dart` defines versioned document data: wall/corner IDs and
coordinates in mm, fixed measured spans, wall relationships, calibration,
annotation IDs/content/formatting/positions, units, drawing assistance and view
settings. Units serialize by stable symbol, not localized display name.
Wall rows optionally include a fifth boolean for dashed styling. Missing flags
load as normal solid walls. Geometry, locks and wall IDs remain unchanged when
converting styles. Older app versions may not read drawings containing this new
optional field; use the updated app when reopening proposed layouts.

`logic/document_repository.dart` validates complete snapshots, names, IDs and
file size before writing. Names are trimmed, whitespace-normalized and unique
case-insensitively. Save updates the current ID; Save As creates an independent
random ID. Rename preserves the saved drawing payload, not unsaved workspace
edits. Unknown formats and invalid geometry are rejected, not repaired silently.

`logic/document_storage.dart` separates persistence from the model. Native
storage uses the installed `path_provider` dependency and an
`easy_floor_documents` folder inside application support. Each save flushes a
temporary `.pending` file then renames it over the `.json` document in the same
directory. Incomplete pending files are never offered as documents. Browser
storage uses a single localStorage value per document under
`buildcalc.easyfloor.`; storage failures propagate to the UI.

`ui/document_workspace.dart` owns modal workflows and dirty state. The screen
captures snapshots and applies a loaded document only after validation and exit
approval. Failed saves keep the original drawing open and prevent switching.
Repeated mutations are guarded while a repository operation is running. No
in-memory fallback pretends that persistence succeeded.

Undo revisions track geometry/text edits, including constraints and calibration.
Relevant settings such as units also mark the plan dirty. Pan, zoom, selection,
label visibility and outline/single-stroke mode do not. These view preferences
are still captured on the next explicit save. Undoing to the saved revision
removes the modified marker; redo restores it. Opening/New resets both history
layers so another document cannot be restored accidentally. Existing Undo/Redo
retains the latest 50 drawing edits; the history chain is not stored on disk.

Save/Discard/Cancel guards apply to New, opening a different document, Close,
back navigation and cancellable native application-exit requests. Uncommitted
strokes/previews must be finished or cancelled before Save. Cancelling a dialog
or failing persistence never replaces the current workspace.

## Verification

Final checks: 240 native-run automated tests and one Chrome persistence test pass.
Analysis has no errors/warnings and 68 pre-existing informational lints. Web and
macOS debug builds succeed. The running macOS app hot-reloads without reported
runtime errors; this is not a manual drawing-interaction test.

The twelve requested scenarios are covered by automated repository/widget tests:

| Scenario | Result |
| --- | --- |
| Save a new named document | Pass |
| Close/reopen and restore drawing | Pass |
| Independent documents | Pass |
| Save updates existing document | Pass |
| Save As keeps independent original | Pass |
| Open with no unsaved work | Pass |
| Open with Save and Continue | Pass |
| Discard and Continue | Pass |
| Cancel preserves the current work | Pass |
| Failed save prevents switching and supports retry | Pass |
| Restore text, dimensions, constraints, connections, all units; fresh undo/redo | Pass |
| Dirty warnings exclude view-only interactions | Pass |

Additional automated checks cover duplicate names, rename/delete confirmation,
corrupt files/versions/IDs, incomplete pending writes, native filesystem
repository recreation, concurrent save rejection, UTF-8 size limits, native exit
request callbacks, and 240x420 dialogs at 1.6 text scale. A real Chrome test
exercises browser persistence, rename and deletion across repository instances.
Repeated serialization also preserves rotated square/rectangle/triangle/L/U/T
outlines, diagonal coordinates and dense shared junctions. The existing drawing
regression suite is also run unchanged in scope.

Commands:

```sh
flutter analyze
flutter test
flutter test --platform chrome test/features/easy_floor/document_browser_test.dart
flutter build web --no-pub
flutter build macos --debug --no-pub
```

## Limits And Unverified Behavior

- Save explicitly: force-killing the app, browser refresh/tab closure, clearing
  browser data or uninstalling the app can lose unsaved work or local documents.
  Browser unload cannot run the custom Save/Discard/Cancel workflow.
- Browser quotas may be lower than the 16 MiB document limit; failure leaves the
  current workspace open. Each serialized collection is limited to 10,000 items.
- Writes are guarded within one repository instance, not across simultaneous
  app processes or browser tabs. Multi-process editing is not supported.
- Native filesystem tests use temporary directories; browser tests use Chrome.
  macOS builds and hot reload pass, but native manual interaction was blocked by
  a locked Mac. Android/iOS physical-device behavior and OS termination dialogs
  have not been manually verified. Extremely large document collections have not
  been performance-benchmarked.
- Browser interop needs Dart 3.3; the current dependency lockfile requires Dart
  3.13 and Flutter 3.38.4 or newer. No dependency was added. Existing macOS
  CocoaPods migration notices are outside this update.
