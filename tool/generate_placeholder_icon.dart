// Generates placeholder app-icon PNGs at:
//   assets/icon/app_icon.png             — solid navy background, orange
//                                            fish icon centered (1024x1024)
//   assets/icon/app_icon_foreground.png  — transparent background, orange
//                                            fish (for adaptive icon mask
//                                            + native splash)
//
// Run once with `dart run tool/generate_placeholder_icon.dart`. Replace
// the outputs with real designer art before shipping. flutter_launcher_icons
// then rasterizes per-platform sizes; flutter_native_splash composes the
// launch screen.
//
// The art is a simple silhouette — three overlapping circles + a triangle
// tail. Good enough as a "we have an app icon" placeholder while waiting
// on designer work.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int _size = 1024;
const int _navyR = 0x10;
const int _navyG = 0x2B;
const int _navyB = 0x47;
const int _orangeR = 0xF0;
const int _orangeG = 0x89;
const int _orangeB = 0x48;

void main() {
  final dir = Directory('assets/icon');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  // 1. Square icon — navy bg + orange fish.
  final solid = img.Image(width: _size, height: _size);
  img.fill(solid, color: img.ColorRgb8(_navyR, _navyG, _navyB));
  _drawFish(solid);
  File('${dir.path}/app_icon.png').writeAsBytesSync(img.encodePng(solid));

  // 2. Foreground-only — transparent bg, same fish (used for the
  //    adaptive-icon foreground layer + native splash logo).
  final fg = img.Image(width: _size, height: _size, numChannels: 4);
  _drawFish(fg);
  File('${dir.path}/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(fg));

  stdout
    ..writeln('Wrote ${dir.path}/app_icon.png')
    ..writeln('Wrote ${dir.path}/app_icon_foreground.png');
}

/// Stylized fish silhouette in orange — body is a horizontal ellipse,
/// tail is a triangle, eye is a tiny navy dot.
void _drawFish(img.Image dst) {
  final orange = img.ColorRgb8(_orangeR, _orangeG, _orangeB);
  final navy = img.ColorRgb8(_navyR, _navyG, _navyB);

  const cx = _size ~/ 2;
  const cy = _size ~/ 2;

  // Body — horizontal ellipse
  img.fillCircle(
    dst,
    x: cx,
    y: cy,
    radius: 220,
    color: orange,
  );

  // Stretch horizontally by drawing two more overlapping circles
  img.fillCircle(
    dst,
    x: cx - 90,
    y: cy,
    radius: 180,
    color: orange,
  );
  img.fillCircle(
    dst,
    x: cx + 90,
    y: cy,
    radius: 180,
    color: orange,
  );

  // Tail — triangle pointing left from the body
  _fillTriangle(
    dst,
    x0: cx - 280,
    y0: cy,
    x1: cx - 420,
    y1: cy - 130,
    x2: cx - 420,
    y2: cy + 130,
    color: orange,
  );

  // Eye — small navy circle on the right side of body
  img.fillCircle(
    dst,
    x: cx + 130,
    y: cy - 40,
    radius: 24,
    color: navy,
  );
}

/// Filled triangle via barycentric scan.
void _fillTriangle(
  img.Image dst, {
  required int x0,
  required int y0,
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required img.Color color,
}) {
  final minX = math.min(x0, math.min(x1, x2));
  final maxX = math.max(x0, math.max(x1, x2));
  final minY = math.min(y0, math.min(y1, y2));
  final maxY = math.max(y0, math.max(y1, y2));

  for (var py = minY; py <= maxY; py++) {
    for (var px = minX; px <= maxX; px++) {
      if (_pointInTriangle(px, py, x0, y0, x1, y1, x2, y2)) {
        if (px >= 0 && py >= 0 && px < dst.width && py < dst.height) {
          dst.setPixel(px, py, color);
        }
      }
    }
  }
}

bool _pointInTriangle(
  int px,
  int py,
  int x0,
  int y0,
  int x1,
  int y1,
  int x2,
  int y2,
) {
  final d1 = (px - x1) * (y0 - y1) - (x0 - x1) * (py - y1);
  final d2 = (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
  final d3 = (px - x0) * (y2 - y0) - (x2 - x0) * (py - y0);
  final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
  final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
  return !(hasNeg && hasPos);
}
