enum WallResizeAnchor { start, end, center }

extension WallResizeLabel on WallResizeAnchor {
  String get label => switch (this) {
        WallResizeAnchor.start => 'Keep A fixed',
        WallResizeAnchor.end => 'Keep B fixed',
        WallResizeAnchor.center => 'Move both sides equally',
      };
}
