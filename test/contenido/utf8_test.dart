import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fuentes y contenido son UTF-8 válido sin secuencias dañadas', () {
    final sospechosas = [0xFFFD, 0x00C3, 0x00C2].map(String.fromCharCode);
    for (final carpeta in ['lib', 'assets/contenido']) {
      for (final archivo in Directory(
        carpeta,
      ).listSync(recursive: true).whereType<File>()) {
        if (!archivo.path.endsWith('.dart') &&
            !archivo.path.endsWith('.json')) {
          continue;
        }
        final texto = utf8.decode(
          archivo.readAsBytesSync(),
          allowMalformed: false,
        );
        for (final token in sospechosas) {
          expect(texto.contains(token), isFalse, reason: archivo.path);
        }
      }
    }
  });
}
