import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/migraciones/migrador_preferencias.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_ajustes.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/armador_rondas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/modelos/estado_partida.dart';

import '../apoyo/base_pruebas.dart';

void main() {
  final catalogo = catalogoReal();
  test('recupera orden, posición y conteos con un repositorio nuevo', () async {
    final almacen = AlmacenMemoria();
    final ronda = ArmadorRondas.crear(
      catalogo,
      nivel: 3,
      cantidad: 25,
    ).avanzar(pasar: true).avanzar();
    await RepositorioPartida(almacen).guardar(ronda, catalogo);
    final carga = await RepositorioPartida(almacen).cargar(catalogo);
    expect(carga.partida!.cartas, ronda.cartas);
    expect(carga.partida!.indice, 2);
    expect(carga.partida!.pasadas, 1);
    expect(carga.recuperada, isFalse);
  });
  test('registro roto recupera el respaldo y lo informa', () async {
    final almacen = AlmacenMemoria();
    final repo = RepositorioPartida(almacen);
    final ronda = ArmadorRondas.crear(catalogo, nivel: 2, cantidad: 12);
    await repo.guardar(ronda, catalogo);
    await repo.guardar(ronda.avanzar(), catalogo);
    almacen.datos[RepositorioPartida.clave] = '{cortado';
    final carga = await repo.cargar(catalogo);
    expect(carga.recuperada, isTrue);
    expect(carga.partida!.indice, 0);
    expect(carga.partida!.cartas, ronda.cartas);
  });
  test('rechaza estados incoherentes, versiones e IDs desconocidos', () async {
    final ronda = ArmadorRondas.crear(catalogo, nivel: 1, cantidad: 12);
    for (final cambio in [
      {'indice': 99},
      {'pasadas': 3},
      {'version': 99},
      {'contenido': 'otro-catálogo'},
      {
        'contenido': '0.2-complicidad-cotidiana',
        'cartas': ['A26', ...ronda.cartas.skip(1)],
      },
      {
        'textosCompartidos': {'A01': 'Carta futura sin conversar'},
      },
      {'cartas': List.filled(12, 'A01')},
      {
        'cartas': ['desconocida', ...ronda.cartas.skip(1)],
      },
    ]) {
      final almacen = AlmacenMemoria();
      almacen.datos[RepositorioPartida.clave] = jsonEncode({
        ...ronda.toJson(),
        ...cambio,
      });
      final carga = await RepositorioPartida(almacen).cargar(catalogo);
      expect(carga.partida, isNull);
      expect(carga.invalida, isTrue);
    }
  });
  test(
    'actualiza una ronda anterior sin perder su historia ni su orden',
    () async {
      for (final edicion in catalogo.textosAnteriores.keys) {
        for (final nivel in [0, 1, 2, 3]) {
          final almacen = AlmacenMemoria();
          final ronda =
              ArmadorRondas.crear(
                    catalogo,
                    nivel: nivel,
                    cantidad: nivel == 0 ? 15 : 12,
                  )
                  .avanzar(milisegundos: 3200)
                  .avanzar(pasar: true, milisegundos: 1700);
          final anterior = ronda.toJson()
            ..['contenido'] = edicion
            ..remove('textosCompartidos');
          final raw = jsonEncode(anterior);
          almacen.datos[RepositorioPartida.clave] = raw;
          final repo = RepositorioPartida(almacen);
          final carga = await repo.cargar(catalogo);
          final migrada = carga.partida!;
          expect(carga.invalida, isFalse);
          expect(migrada.versionContenido, catalogo.version);
          expect(migrada.cartas, ronda.cartas);
          expect(migrada.indice, 2);
          expect(migrada.pasadas, 1);
          expect(migrada.tiemposMs, ronda.tiemposMs);
          expect(migrada.cartasPasadas, ronda.cartasPasadas);
          final id = ronda.cartas.first;
          expect(
            migrada.textosCompartidos[id],
            catalogo.textosAnteriores[edicion]![id],
          );
          expect(
            migrada.textosCompartidos[id],
            isNot(catalogo.porId[id]!.texto),
          );
          // Leer una actualización no reescribe el registro del usuario.
          expect(almacen.datos[RepositorioPartida.clave], raw);
          final actual = migrada.cartaActual!;
          final siguiente = migrada.avanzar(
            milisegundos: 4000,
            textoCompartido: catalogo.porId[actual]!.texto,
          );
          await repo.guardar(siguiente, catalogo);
          final reabierta = (await repo.cargar(catalogo)).partida!;
          expect(
            reabierta.textosCompartidos[id],
            migrada.textosCompartidos[id],
          );
          expect(
            reabierta.textosCompartidos[actual],
            catalogo.porId[actual]!.texto,
          );
          expect(reabierta.indice, 3);
          expect(reabierta.versionContenido, catalogo.version);
        }
      }
    },
  );
  test('historial inválido no permite recuperar una sesión', () {
    final ronda = ArmadorRondas.crear(
      catalogo,
      nivel: 1,
      cantidad: 12,
    ).avanzar(milisegundos: 2000);
    for (final textos in [
      {'desconocida': 'Un título'},
      {ronda.cartas[1]: 'Una carta aún no conversada'},
      {ronda.cartas[0]: '   '},
    ]) {
      expect(
        () => EstadoPartida.fromJson({
          ...ronda.toJson(),
          'textosCompartidos': textos,
        }, catalogo),
        throwsFormatException,
      );
    }
  });
  test('preferencias corruptas tienen valores utilizables', () async {
    final almacen = AlmacenMemoria();
    almacen.datos[RepositorioAjustes.clave] = '{"nivel":99}';
    final ajustes = await RepositorioAjustes(almacen).cargar();
    expect(ajustes.nivel, 2);
    expect(ajustes.cantidad, 12);
  });
  test(
    'migración idempotente preserva claves y reconoce versión futura',
    () async {
      final almacen = AlmacenMemoria();
      almacen.datos['otra_clave'] = 'ñ, ¿y vos?';
      await MigradorPreferencias.ejecutar(almacen);
      await MigradorPreferencias.ejecutar(almacen);
      expect(almacen.escrituras, 1);
      expect(almacen.datos['otra_clave'], 'ñ, ¿y vos?');
      almacen.datos[MigradorPreferencias.claveVersion] = '99';
      await expectLater(
        MigradorPreferencias.ejecutar(almacen),
        throwsFormatException,
      );
    },
  );
}
