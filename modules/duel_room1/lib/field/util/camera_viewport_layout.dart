import 'package:flutter/widgets.dart';

@immutable
class CameraViewportLayout {
  const CameraViewportLayout._({
    required this.viewport,
    required this.safePadding,
    required this.hudInsets,
    required this.visibleRect,
  });

  final Size viewport;
  final EdgeInsets safePadding;
  final EdgeInsets hudInsets;
  final Rect visibleRect;

  Offset get center => visibleRect.center;
  Size get availableSize => visibleRect.size;
  Rect get safeRect => Rect.fromLTRB(
    safePadding.left,
    safePadding.top,
    viewport.width - safePadding.right,
    viewport.height - safePadding.bottom,
  );

  factory CameraViewportLayout.resolve(
    Size rawViewport, {
    EdgeInsets safePadding = EdgeInsets.zero,
    EdgeInsets hudInsets = EdgeInsets.zero,
  }) {
    final viewport = Size(
      _validDimension(rawViewport.width),
      _validDimension(rawViewport.height),
    );
    final safe = _clampInsets(safePadding, viewport);
    final safeSize = Size(
      viewport.width - safe.horizontal,
      viewport.height - safe.vertical,
    );
    final hud = _compressInsets(_nonNegative(hudInsets), safeSize);

    return CameraViewportLayout._(
      viewport: viewport,
      safePadding: safe,
      hudInsets: hud,
      visibleRect: Rect.fromLTRB(
        safe.left + hud.left,
        safe.top + hud.top,
        viewport.width - safe.right - hud.right,
        viewport.height - safe.bottom - hud.bottom,
      ),
    );
  }
}

@immutable
class CameraViewportFit {
  const CameraViewportFit({required this.zoom, required this.worldCenter});

  final double zoom;
  final Offset worldCenter;

  factory CameraViewportFit.resolve({
    required CameraViewportLayout layout,
    required Size contentSize,
    required double minZoom,
    required double maxZoom,
  }) {
    final contentWidth = _validDimension(contentSize.width);
    final contentHeight = _validDimension(contentSize.height);
    final widthZoom = layout.availableSize.width / contentWidth;
    final heightZoom = layout.availableSize.height / contentHeight;
    final zoom = clampCameraZoom(
      widthZoom < heightZoom ? widthZoom : heightZoom,
      1,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    return CameraViewportFit(
      zoom: zoom,
      worldCenter: Offset(
        (layout.viewport.width / 2 - layout.center.dx) / zoom,
        (layout.viewport.height / 2 - layout.center.dy) / zoom,
      ),
    );
  }
}

double clampCameraZoom(
  double fitZoom,
  double userZoom, {
  required double minZoom,
  required double maxZoom,
}) {
  final minimum = minZoom.isFinite && minZoom > 0 ? minZoom : 0.1;
  final maximum = maxZoom.isFinite && maxZoom >= minimum ? maxZoom : minimum;
  if (!fitZoom.isFinite ||
      !userZoom.isFinite ||
      fitZoom <= 0 ||
      userZoom <= 0) {
    return minimum;
  }
  final result = fitZoom * userZoom;
  if (!result.isFinite) return maximum;
  return result.clamp(minimum, maximum);
}

double _validDimension(double value) => value.isFinite && value > 0 ? value : 1;

double _validInset(double value) => value.isFinite && value > 0 ? value : 0;

EdgeInsets _nonNegative(EdgeInsets value) => EdgeInsets.fromLTRB(
  _validInset(value.left),
  _validInset(value.top),
  _validInset(value.right),
  _validInset(value.bottom),
);

EdgeInsets _clampInsets(EdgeInsets raw, Size viewport) {
  final value = _nonNegative(raw);
  final left = value.left.clamp(0.0, viewport.width - 1);
  final right = value.right.clamp(0.0, viewport.width - left - 1);
  final top = value.top.clamp(0.0, viewport.height - 1);
  final bottom = value.bottom.clamp(0.0, viewport.height - top - 1);
  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

EdgeInsets _compressInsets(EdgeInsets value, Size safeSize) {
  final horizontal = _compressAxis(value.left, value.right, safeSize.width);
  final vertical = _compressAxis(value.top, value.bottom, safeSize.height);
  return EdgeInsets.fromLTRB(
    horizontal.$1,
    vertical.$1,
    horizontal.$2,
    vertical.$2,
  );
}

// Divide before multiplying so two finite max values cannot overflow their sum
// and cannot reach the Infinity * 0 => NaN path.
(double, double) _compressAxis(double leading, double trailing, double extent) {
  final maximum = extent - 1;
  if (leading <= maximum - trailing) return (leading, trailing);
  if (maximum <= 0) return (0, 0);
  final largest = leading > trailing ? leading : trailing;
  if (largest <= 0) return (0, 0);
  final leadingRatio = leading / largest;
  final trailingRatio = trailing / largest;
  final unit = maximum / (leadingRatio + trailingRatio);
  return (leadingRatio * unit, trailingRatio * unit);
}
