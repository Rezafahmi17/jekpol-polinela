import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Membuat ikon marker kustom (lingkaran berwarna + ikon) untuk peta.
class MarkerFactory {
  MarkerFactory._();
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> icon(IconData icon, Color color, {double px = 120, double width = 46}) async {
    final key = '${icon.codePoint}-${color.toARGB32()}-$px';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(px / 2, px / 2);
    final r = px / 2 - 8;

    canvas.drawCircle(c.translate(0, 3), r, Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(c, r - 7, Paint()..color = color);

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: px * 0.42, fontFamily: icon.fontFamily, package: icon.fontPackage, color: Colors.white),
      )
      ..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));

    final img = await recorder.endRecording().toImage(px.toInt(), px.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final d = BitmapDescriptor.bytes(Uint8List.fromList(bytes), width: width);
    _cache[key] = d;
    return d;
  }
}

