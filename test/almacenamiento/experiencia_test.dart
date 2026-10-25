import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivia_antiguedad/compartido/almacenamiento/proveedores_almacenamiento.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/controladores/controlador_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';

import '../apoyo/base_pruebas.dart';

import 'dart:convert';

void main() {
  test(
    'v1 conserva silencio y tutorial; vibración independiente migra a v2',
    () async {
      final almacen = AlmacenMemoria()
        ..datos[RepositorioExperiencia.clave] =
            '{"version":1,"tutorialVisto":true,"sonidos":false}';
      final container = ProviderContainer(
        overrides: [almacenProvider.overrideWithValue(almacen)],
      );
      addTearDown(container.dispose);
      final inicial = await container.read(experienciaProvider.future);
      expect(inicial.vibracion, isTrue);
      expect(inicial.sonidos, isFalse);
      expect(inicial.tutorialVisto, isTrue);
      await container.read(experienciaProvider.notifier).alternarVibracion();
      final json = jsonDecode(almacen.datos[RepositorioExperiencia.clave]!);
      expect(json['version'], 2);
      expect(json['sonidos'], isFalse);
      expect(json['vibracion'], isFalse);
      await container.read(experienciaProvider.notifier).alternarSonidos();
      final guardadas = await RepositorioExperiencia(almacen).cargar();
      expect(guardadas.sonidos, isTrue);
      expect(guardadas.vibracion, isFalse);
    },
  );
  test(
    'primera bienvenida y sonido se guardan con cambios rápidos en orden',
    () async {
      final almacen = AlmacenMemoria()
        ..demora = const Duration(milliseconds: 2);
      final container = ProviderContainer(
        overrides: [almacenProvider.overrideWithValue(almacen)],
      );
      addTearDown(container.dispose);
      final inicial = await container.read(experienciaProvider.future);
      expect(inicial.tutorialVisto, isFalse);
      expect(inicial.sonidos, isTrue);
      final control = container.read(experienciaProvider.notifier);
      await control.marcarTutorialVisto();
      await Future.wait(List.generate(9, (_) => control.alternarSonidos()));
      final guardadas = await RepositorioExperiencia(almacen).cargar();
      expect(guardadas.tutorialVisto, isTrue);
      expect(guardadas.sonidos, isFalse);
      almacen.fallar = true;
      await control.alternarSonidos();
      expect(container.read(experienciaProvider).requireValue.aviso, isNotNull);
    },
  );
}
