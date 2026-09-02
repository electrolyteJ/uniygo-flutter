import 'package:duel_room1/field/util/camera_viewport_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectFiniteLayout(CameraViewportLayout layout) {
    for (final value in [
      layout.viewport.width,
      layout.viewport.height,
      layout.safePadding.left,
      layout.safePadding.top,
      layout.safePadding.right,
      layout.safePadding.bottom,
      layout.hudInsets.left,
      layout.hudInsets.top,
      layout.hudInsets.right,
      layout.hudInsets.bottom,
      layout.visibleRect.left,
      layout.visibleRect.top,
      layout.visibleRect.right,
      layout.visibleRect.bottom,
      layout.center.dx,
      layout.center.dy,
    ]) {
      expect(value.isFinite, isTrue, reason: '$value must be finite');
    }
    expect(layout.availableSize.width, greaterThanOrEqualTo(1));
    expect(layout.availableSize.height, greaterThanOrEqualTo(1));
  }

  group('CameraViewportLayout.resolve', () {
    test('reserves safe padding before scaled HUD in a phone viewport', () {
      final layout = CameraViewportLayout.resolve(
        const Size(844, 390),
        safePadding: const EdgeInsets.fromLTRB(44, 0, 21, 16),
        hudInsets: const EdgeInsets.fromLTRB(24, 138, 24, 69.6),
      );

      expect(layout.visibleRect, const Rect.fromLTRB(68, 138, 799, 304.4));
      expect(layout.availableSize.width, 731);
      expect(layout.availableSize.height, closeTo(166.4, 1e-9));
      expect(layout.center.dx, 433.5);
      expect(layout.center.dy, closeTo(221.2, 1e-9));
    });

    test('compresses only HUD insets in an extremely short viewport', () {
      final layout = CameraViewportLayout.resolve(
        const Size(640, 120),
        safePadding: const EdgeInsets.symmetric(vertical: 10),
        hudInsets: const EdgeInsets.fromLTRB(24, 138, 24, 69.6),
      );

      expect(layout.safePadding, const EdgeInsets.symmetric(vertical: 10));
      expect(layout.visibleRect.height, closeTo(1, 1e-9));
      expect(layout.visibleRect.top, greaterThanOrEqualTo(10));
      expect(layout.visibleRect.bottom, lessThanOrEqualTo(110));
      expect(layout.availableSize.width, 592);
    });

    test('clamps negative and oversized safe padding to the viewport', () {
      final layout = CameraViewportLayout.resolve(
        const Size(100, 80),
        safePadding: const EdgeInsets.fromLTRB(-5, 200, 120, -3),
      );

      expect(layout.safePadding, const EdgeInsets.fromLTRB(0, 79, 99, 0));
      expect(layout.visibleRect, const Rect.fromLTWH(0, 79, 1, 1));
    });

    test('normalizes a zero viewport to a usable one-pixel rectangle', () {
      final layout = CameraViewportLayout.resolve(
        Size.zero,
        safePadding: const EdgeInsets.all(20),
        hudInsets: const EdgeInsets.all(20),
      );

      expect(layout.viewport, const Size(1, 1));
      expect(layout.visibleRect, const Rect.fromLTWH(0, 0, 1, 1));
      expect(layout.availableSize, const Size(1, 1));
    });

    test('reports the center of asymmetric horizontal reservations', () {
      final layout = CameraViewportLayout.resolve(
        const Size(500, 300),
        safePadding: const EdgeInsets.fromLTRB(40, 10, 10, 20),
        hudInsets: const EdgeInsets.fromLTRB(60, 30, 20, 40),
      );

      expect(layout.visibleRect, const Rect.fromLTRB(100, 40, 470, 240));
      expect(layout.center, const Offset(285, 140));
    });

    test('safe content exposes the hand bar width and asymmetric center', () {
      final layout = CameraViewportLayout.resolve(
        const Size(844, 390),
        safePadding: const EdgeInsets.fromLTRB(44, 0, 21, 16),
      );

      expect(layout.safeRect, const Rect.fromLTRB(44, 0, 823, 374));
      expect(layout.safeRect.center.dx, 433.5);
    });

    test('keeps every output finite for non-finite and huge insets', () {
      for (final insets in [
        const EdgeInsets.fromLTRB(
          double.nan,
          double.infinity,
          double.negativeInfinity,
          double.nan,
        ),
        const EdgeInsets.all(double.maxFinite),
      ]) {
        expectFiniteLayout(
          CameraViewportLayout.resolve(
            const Size(844, 390),
            safePadding: insets,
            hudInsets: insets,
          ),
        );
      }
    });

    test('compresses asymmetric horizontal HUD while preserving its ratio', () {
      final layout = CameraViewportLayout.resolve(
        const Size(100, 80),
        hudInsets: const EdgeInsets.fromLTRB(120, 0, 60, 0),
      );

      expect(layout.availableSize.width, closeTo(1, 1e-9));
      expect(layout.hudInsets.left, closeTo(66, 1e-9));
      expect(layout.hudInsets.right, closeTo(33, 1e-9));
      expectFiniteLayout(layout);
    });

    test('computes asymmetric camera fit and world center', () {
      final layout = CameraViewportLayout.resolve(
        const Size(500, 300),
        safePadding: const EdgeInsets.fromLTRB(40, 10, 10, 20),
        hudInsets: const EdgeInsets.fromLTRB(60, 30, 20, 40),
      );

      final fit = CameraViewportFit.resolve(
        layout: layout,
        contentSize: const Size(370, 100),
        minZoom: 0.1,
        maxZoom: 2.6,
      );

      expect(fit.zoom, 1);
      expect(fit.worldCenter, const Offset(-35, 10));
    });

    test('clamps final zoom absolutely and handles invalid input', () {
      expect(clampCameraZoom(0.5, 10, minZoom: 0.1, maxZoom: 2.6), 2.6);
      expect(clampCameraZoom(0.05, 1, minZoom: 0.1, maxZoom: 2.6), 0.1);
      expect(
        clampCameraZoom(
          double.nan,
          double.infinity,
          minZoom: 0.1,
          maxZoom: 2.6,
        ),
        0.1,
      );
    });
  });
}
