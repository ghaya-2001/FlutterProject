import 'dart:io';

import 'package:image/image.dart';

Future<void> main() async {
  const size = 1024;
  final image = Image(width: size, height: size);

  fill(image, color: ColorRgba8(220, 245, 224, 255));
  drawCircle(
    image,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: 430,
    color: ColorRgba8(34, 139, 58, 255),
  );

  drawCircle(
    image,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: 330,
    color: ColorRgba8(40, 158, 69, 255),
  );

  final leaf = [
    Point(512, 300),
    Point(700, 420),
    Point(630, 700),
    Point(512, 610),
    Point(396, 700),
    Point(326, 420),
  ];
  drawPolygon(
    image,
    vertices: leaf,
    color: ColorRgba8(255, 255, 255, 255),
    thickness: 1,
  );
  drawLine(
    image,
    x1: 512,
    y1: 300,
    x2: 512,
    y2: 700,
    color: ColorRgba8(36, 128, 62, 255),
    thickness: 24,
  );

  drawLine(
    image,
    x1: 740,
    y1: 310,
    x2: 740,
    y2: 715,
    color: ColorRgba8(255, 255, 255, 255),
    thickness: 30,
  );
  drawLine(
    image,
    x1: 700,
    y1: 285,
    x2: 780,
    y2: 285,
    color: ColorRgba8(255, 255, 255, 255),
    thickness: 26,
  );
  drawCircle(
    image,
    x: 740,
    y: 780,
    radius: 42,
    color: ColorRgba8(255, 255, 255, 255),
  );

  final directory = Directory('assets/icon');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  final file = File('${directory.path}/app_icon.png');
  file.writeAsBytesSync(encodePng(image));

  stdout.writeln('Created ${file.path}');
}
