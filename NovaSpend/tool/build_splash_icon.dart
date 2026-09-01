import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Composites the transparent icon onto the splash green for a crisp display asset.
Future<void> main() async {
  const iconPath = 'assets/branding/app_icon.png';
  const outputPath = 'assets/branding/app_icon_splash.png';
  final bg = img.ColorRgba8(13, 74, 50, 255); // #0D4A32

  final icon = img.decodeImage(await File(iconPath).readAsBytes());
  if (icon == null) {
    stderr.writeln('Could not decode $iconPath');
    exit(1);
  }

  final size = math.max(icon.width, icon.height);
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: bg);
  img.compositeImage(
    canvas,
    icon,
    dstX: (size - icon.width) ~/ 2,
    dstY: (size - icon.height) ~/ 2,
  );

  await File(outputPath).writeAsBytes(img.encodePng(canvas));
  stdout.writeln('Wrote $outputPath (${canvas.width}x${canvas.height})');
}
