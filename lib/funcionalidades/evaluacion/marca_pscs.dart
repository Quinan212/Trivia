import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Marca original con transparencia propia, independiente del fondo y del scroll.
class MarcaPscs extends StatelessWidget {
  const MarcaPscs({super.key, this.ancho = 176});
  final double ancho;
  static ui.Image? _lista;
  static final Future<ui.Image> _imagen = _cargar();

  static Future<ui.Image> _cargar() async {
    final datos = await rootBundle.load(
      'assets/documentos/portada-original-2026.png',
    );
    final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List());
    final cuadro = await codec.getNextFrame();
    codec.dispose();
    final original = cuadro.image;
    final pixeles = (await original.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    const ancho = 500, alto = 170;
    const papel = [252.0, 248.0, 240.0];
    final rgba = Uint8List(ancho * alto * 4);
    for (var y = 0; y < alto; y++) {
      for (var x = 0; x < ancho; x++) {
        final fuente = ((1830 + y) * original.width + 165 + x) * 4;
        final destino = (y * ancho + x) * 4;
        var fondo = 1.0;
        for (var c = 0; c < 3; c++) {
          fondo = math.min(fondo, pixeles.getUint8(fuente + c) / papel[c]);
        }
        final opacidad = (1 - fondo).clamp(0.0, 1.0);
        if (opacidad < .015) continue;
        // RGBA premultiplicado: retirar el papel conserva los bordes suaves.
        for (var c = 0; c < 3; c++) {
          rgba[destino + c] = (pixeles.getUint8(fuente + c) - papel[c] * fondo)
              .round()
              .clamp(0, (255 * opacidad).round());
        }
        rgba[destino + 3] = (255 * opacidad).round();
        if (x >= 175) {
          // Reforzar las mismas siglas originales sin alterar el escudo.
          final alfa = (opacidad * 2.4).clamp(0.0, 1.0);
          rgba[destino] = (44 * alfa).round();
          rgba[destino + 1] = (29 * alfa).round();
          rgba[destino + 2] = (25 * alfa).round();
          rgba[destino + 3] = (255 * alfa).round();
        }
      }
    }
    original.dispose();
    final completado = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      ancho,
      alto,
      ui.PixelFormat.rgba8888,
      completado.complete,
    );
    return _lista = await completado.future;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'PSCS · Escudo institucional y siglas',
    child: SizedBox(
      width: ancho,
      height: ancho * 30 / 88,
      child: FutureBuilder<ui.Image>(
        initialData: _lista,
        future: _imagen,
        builder: (context, estado) => estado.hasData
            ? RawImage(
                image: estado.data,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              )
            : const SizedBox.shrink(),
      ),
    ),
  );
}
