import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/armador_rondas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/modelos/estado_partida.dart';

import '../apoyo/base_pruebas.dart';

void main() {
  final catalogo = catalogoReal();
  test(
    'contenido completo, original y con caracteres españoles preservados',
    () {
      expect(catalogo.cartas.length, 159);
      expect(catalogo.porId.length, 159);
      expect(catalogo.deNivel(0).length, 15);
      for (var nivel = 1; nivel <= 3; nivel++) {
        expect(catalogo.deNivel(nivel).length, greaterThanOrEqualTo(25));
        expect(
          catalogo
              .deNivel(nivel)
              .every((c) => c.repregunta?.isNotEmpty ?? false),
          isTrue,
        );
      }
      expect(
        catalogo.porId['B01']!.texto,
        '¿Qué tiene que pasar para que alguien deje de ser «un conocido» y empieces a decirle amigo?',
      );
    },
  );
  for (var nivel = 1; nivel <= 3; nivel++) {
    for (final cantidad in [12, 25]) {
      test(
        'ronda $nivel / $cantidad: sin repetidas y con temas alternados',
        () {
          final ronda = ArmadorRondas.crear(
            catalogo,
            nivel: nivel,
            cantidad: cantidad,
          );
          expect(ronda.cartas.length, cantidad);
          expect(ronda.cartas.toSet().length, cantidad);
          expect(
            ronda.cartas.every((id) => catalogo.porId[id]!.nivel == nivel),
            isTrue,
          );
          final temas = ronda.cartas
              .take(5)
              .map((id) => catalogo.porId[id]!.tema);
          expect(temas.toSet().length, 5);
        },
      );
    }
  }
  test('rondas sucesivas recorren todo el nivel antes de repetir cartas', () {
    for (final nivel in [1, 2, 3]) {
      for (final cantidad in [12, 25]) {
        final ids = catalogo.deNivel(nivel).map((carta) => carta.id).toSet();
        final vistas = <String>[];
        for (var ronda = 0; vistas.length < ids.length; ronda++) {
          vistas.addAll(
            ArmadorRondas.crear(
              catalogo,
              nivel: nivel,
              cantidad: cantidad,
              ronda: ronda,
            ).cartas,
          );
        }
        expect(vistas.take(ids.length).toSet(), ids);
        expect(vistas.take(ids.length).toSet().length, ids.length);
      }
    }
  });
  test('pasar, avanzar y terminar producen el resumen correcto', () {
    var ronda = ArmadorRondas.crear(catalogo, nivel: 1, cantidad: 12);
    ronda = ronda.avanzar(pasar: true).avanzar(pasar: true);
    for (var i = 0; i < 10; i++) {
      ronda = ronda.avanzar();
    }
    expect(ronda.terminada, isTrue);
    expect(ronda.compartidas, 10);
    expect(ronda.pasadas, 2);
    expect(ronda.cartaActual, isNull);
    expect(ronda.avanzar(pasar: true), same(ronda));
    final restaurada = EstadoPartida.fromJson(ronda.toJson(), catalogo);
    expect(restaurada.terminada, isTrue);
    expect(restaurada.compartidas, 10);
  });
  test('consignas y entradas fuera de rango', () {
    final ronda = ArmadorRondas.crear(catalogo, nivel: 0, cantidad: 15);
    expect(ronda.cartas.toSet().length, 15);
    expect(
      () => ArmadorRondas.crear(catalogo, nivel: 9, cantidad: 12),
      throwsArgumentError,
    );
    expect(
      () => ArmadorRondas.crear(catalogo, nivel: 1, cantidad: 13),
      throwsArgumentError,
    );
  });
}
