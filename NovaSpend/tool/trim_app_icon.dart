import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _outputSize = 1024;

/// Removes the white canvas and light fringe around the green app icon.
Future<void> main() async {
  const inputPath = 'assets/branding/app_icon_source.jpg';
  const outputPath = 'assets/branding/app_icon.png';

  final source = img.decodeImage(await File(inputPath).readAsBytes());
  if (source == null) {
    stderr.writeln('Could not decode $inputPath');
    exit(1);
  }

  var minX = source.width;
  var minY = source.height;
  var maxX = 0;
  var maxY = 0;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (_isRemovableBackground(source.getPixel(x, y))) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  final cropW = maxX - minX + 1;
  final cropH = maxY - minY + 1;
  final cropped = img.copyCrop(source, x: minX, y: minY, width: cropW, height: cropH);

  final side = math.max(cropW, cropH);
  final squared = img.Image(width: side, height: side, numChannels: 4);
  img.fill(squared, color: img.ColorRgba8(0, 0, 0, 0));

  final offsetX = (side - cropW) ~/ 2;
  final offsetY = (side - cropH) ~/ 2;
  img.compositeImage(squared, cropped, dstX: offsetX, dstY: offsetY);

  _floodClearBackground(squared);
  for (var i = 0; i < 4; i++) {
    _stripEdgeFringe(squared);
  }
  _shaveOuterLightRing(squared);
  _shaveTopCap(squared);

  final output = side == _outputSize
      ? squared
      : img.copyResize(
          squared,
          width: _outputSize,
          height: _outputSize,
          interpolation: img.Interpolation.cubic,
        );

  await File(outputPath).writeAsBytes(img.encodePng(output));
  stdout.writeln('Wrote $outputPath (${output.width}x${output.height})');
}

bool _isRemovableBackground(img.Pixel p) {
  final r = p.r.toInt();
  final g = p.g.toInt();
  final b = p.b.toInt();

  if (_isSolidIconGreen(p)) return false;
  if (r < 70 && g < 70 && b < 70) return false;

  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;

  if (r > 200 && g > 200 && b > 200) return true;
  if (maxC > 150 && saturation < 0.22) return true;
  if (maxC > 120 && g < r - 4 && g < b - 4) return true;

  return false;
}

bool _isSolidIconGreen(img.Pixel p) {
  final r = p.r.toInt();
  final g = p.g.toInt();
  final b = p.b.toInt();
  return g > 78 && g > r + 10 && g > b + 10;
}

bool _isFringePixel(img.Pixel p) {
  if (_isSolidIconGreen(p)) return false;

  final r = p.r.toInt();
  final g = p.g.toInt();
  final b = p.b.toInt();
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;

  if (r > 188 && g > 188 && b > 188) return true;
  if (maxC > 135 && saturation < 0.24) return true;
  if (g > 60 && g >= r - 6 && g >= b - 6 && maxC < 175) return false;

  return maxC > 115 && (saturation < 0.28 || g < r);
}

bool _isTransparent(img.Image image, int x, int y) {
  if (x < 0 || y < 0 || x >= image.width || y >= image.height) return true;
  return image.getPixel(x, y).a.toInt() == 0;
}

void _floodClearBackground(img.Image image) {
  final w = image.width;
  final h = image.height;
  final visited = List.generate(h, (_) => List.filled(w, false));
  final queue = Queue<(int, int)>();

  void tryAdd(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h || visited[y][x]) return;
    if (!_isRemovableBackground(image.getPixel(x, y))) return;
    visited[y][x] = true;
    queue.add((x, y));
  }

  for (var x = 0; x < w; x++) {
    tryAdd(x, 0);
    tryAdd(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    tryAdd(0, y);
    tryAdd(w - 1, y);
  }

  while (queue.isNotEmpty) {
    final (x, y) = queue.removeFirst();
    image.setPixelRgba(x, y, 0, 0, 0, 0);
    tryAdd(x - 1, y);
    tryAdd(x + 1, y);
    tryAdd(x, y - 1);
    tryAdd(x, y + 1);
  }
}

/// Removes 1px halos still touching transparent pixels (common on the top edge).
void _stripEdgeFringe(img.Image image) {
  final w = image.width;
  final h = image.height;
  final toClear = <(int, int)>[];

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      if (p.a.toInt() == 0 || !_isFringePixel(p)) continue;

      final touchesTransparent = _isTransparent(image, x - 1, y) ||
          _isTransparent(image, x + 1, y) ||
          _isTransparent(image, x, y - 1) ||
          _isTransparent(image, x, y + 1);

      if (touchesTransparent) toClear.add((x, y));
    }
  }

  for (final (x, y) in toClear) {
    image.setPixelRgba(x, y, 0, 0, 0, 0);
  }
}

/// Shaves a thin light ring from each outer edge of the opaque icon bounds.
void _shaveOuterLightRing(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = 0;
  var maxY = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a.toInt() == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX <= minX || maxY <= minY) return;

  for (var x = minX; x <= maxX; x++) {
    _clearIfFringe(image, x, minY);
    _clearIfFringe(image, x, minY + 1);
    _clearIfFringe(image, x, maxY);
    _clearIfFringe(image, x, maxY - 1);
  }
  for (var y = minY; y <= maxY; y++) {
    _clearIfFringe(image, minX, y);
    _clearIfFringe(image, minX + 1, y);
    _clearIfFringe(image, maxX, y);
    _clearIfFringe(image, maxX - 1, y);
  }
}

void _clearIfFringe(img.Image image, int x, int y) {
  if (x < 0 || y < 0 || x >= image.width || y >= image.height) return;
  final p = image.getPixel(x, y);
  if (p.a.toInt() == 0) return;
  if (_isFringePixel(p) || _isRemovableBackground(p)) {
    image.setPixelRgba(x, y, 0, 0, 0, 0);
  }
}

/// The source JPEG leaves a bright 1px halo along the top squircle arc.
void _shaveTopCap(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = 0;
  var maxY = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a.toInt() == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX <= minX || maxY <= minY) return;

  final shaveDepth = ((maxY - minY) * 0.02).ceil().clamp(3, 12);
  for (var y = minY; y <= minY + shaveDepth; y++) {
    for (var x = minX; x <= maxX; x++) {
      final p = image.getPixel(x, y);
      if (p.a.toInt() == 0) continue;
      if (_isSolidIconGreen(p)) continue;
      if (_isLogoInterior(p)) continue;
      image.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }
}

bool _isLogoInterior(img.Pixel p) {
  final r = p.r.toInt();
  final g = p.g.toInt();
  final b = p.b.toInt();
  // White N / bright arrowhead — keep away from the top cap shave band anyway.
  return r > 195 && g > 195 && b > 195;
}
