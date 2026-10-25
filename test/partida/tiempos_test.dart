import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/armador_rondas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/reloj_carta.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/modelos/estado_partida.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/reloj_prueba.dart';

void main() {
  final catalogo = catalogoReal();
  test(
    'suma visitas activas, pausa el reloj y excluye las pasadas del cierre',
    () async {
      final almacen = AlmacenMemoria();
      final reloj = RelojPrueba();
      final container = ProviderContainer(
        overrides: [
          almacenProvider.overrideWithValue(almacen),
          preguntasProvider.overrideWithValue(PreguntasFijas(catalogo)),
          relojCartaProvider.overrideWithValue(reloj),
          intervaloRespaldoProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      await container.read(partidaProvider.future);
      final control = container.read(partidaProvider.notifier);
      await control.empezar();
      final orden = container
          .read(partidaProvider)
          .requireValue
          .partida!
          .cartas;
      control.iniciarMedicion();
      reloj.pasar(4000);
      await control.pausarMedicion();
      reloj.pasar(900000);
      control.iniciarMedicion();
      reloj.pasar(2000);
      await control.avanzar();
      reloj.pasar(20000);
      await control.avanzar(pasar: true);
      reloj.pasar(4000);
      await control.avanzar();
      for (var indice = 3; indice < 12; indice++) {
        await control.avanzar();
      }
      final guardada = (await RepositorioPartida(almacen).cargar(catalogo))
          .partida!;
      expect(guardada.terminada, isTrue);
      expect(guardada.tiemposMs[orden[0]], 6000);
      expect(guardada.tiemposMs[orden[1]], 20000);
      expect(guardada.cartasPasadas, {orden[1]});
      expect(guardada.masConversadas.map((e) => e.key), [orden[0], orden[2]]);
      expect(reloj.activo, isFalse);
    },
  );
  test(
    'las sesiones v1 conservan progreso y pasan a v2 sin inventar tiempos',
    () {
      final ronda = ArmadorRondas.crear(
        catalogo,
        nivel: 2,
        cantidad: 12,
      ).avanzar(pasar: true).avanzar();
      final antigua = {...ronda.toJson(), 'version': 1}
        ..remove('tiemposMs')
        ..remove('cartasPasadas');
      final restaurada = EstadoPartida.fromJson(antigua, catalogo);
      expect(restaurada.indice, 2);
      expect(restaurada.pasadas, 1);
      expect(restaurada.tiemposMs, isEmpty);
      expect(restaurada.masConversadas, isEmpty);
      final nueva = restaurada.avanzar(milisegundos: 3000);
      expect(nueva.toJson()['version'], 2);
      expect(nueva.masConversadas.single.key, ronda.cartas[2]);
    },
  );
  test(
    'rechaza tiempos negativos, cartas futuras y pasadas incoherentes',
    () async {
      final ronda = ArmadorRondas.crear(catalogo, nivel: 2, cantidad: 12);
      for (final cambio in [
        {
          'tiemposMs': {ronda.cartas[0]: -2},
        },
        {
          'tiemposMs': {ronda.cartas[0]: '3000'},
        },
        {
          'tiemposMs': {ronda.cartas[4]: 2000},
        },
        {
          'cartasPasadas': [ronda.cartas[0]],
        },
      ]) {
        final almacen = AlmacenMemoria()
          ..datos[RepositorioPartida.clave] = jsonEncode({
            ...ronda.toJson(),
            ...cambio,
          });
        final carga = await RepositorioPartida(almacen).cargar(catalogo);
        expect(carga.invalida, isTrue);
        expect(carga.partida, isNull);
      }
    },
  );
  test(
    'el respaldo periódico guarda tiempo activo sin avanzar la carta',
    () async {
      final reloj = RelojPrueba();
      final almacen = AlmacenMemoria();
      final container = ProviderContainer(
        overrides: [
          almacenProvider.overrideWithValue(almacen),
          preguntasProvider.overrideWithValue(PreguntasFijas(catalogo)),
          relojCartaProvider.overrideWithValue(reloj),
          intervaloRespaldoProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(partidaProvider.future);
      final control = container.read(partidaProvider.notifier);
      await control.empezar();
      control.iniciarMedicion();
      reloj.pasar(12000);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final carga = (await RepositorioPartida(almacen).cargar(catalogo))
          .partida!;
      expect(carga.indice, 0);
      expect(carga.tiemposMs[carga.cartaActual], 12000);
      await control.pausarMedicion();
    },
  );
}
