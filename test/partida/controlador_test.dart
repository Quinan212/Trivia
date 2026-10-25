import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';

import '../apoyo/base_pruebas.dart';

void main() {
  test('toques concurrentes guardan el último progreso en orden', () async {
    final almacen = AlmacenMemoria()..demora = const Duration(milliseconds: 1);
    final catalogo = catalogoReal();
    final container = ProviderContainer(
      overrides: [
        almacenProvider.overrideWithValue(almacen),
        preguntasProvider.overrideWithValue(PreguntasFijas(catalogo)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(partidaProvider.future);
    final controlador = container.read(partidaProvider.notifier);
    await controlador.empezar();
    await Future.wait(
      List.generate(10, (i) => controlador.avanzar(pasar: i < 2)),
    );
    final guardada = (await RepositorioPartida(almacen).cargar(catalogo))
        .partida!;
    expect(guardada.indice, 10);
    expect(guardada.pasadas, 2);
    expect(container.read(partidaProvider).requireValue.partida!.indice, 10);
  });
  test('fallo de guardado no bloquea juego y permite reintentar', () async {
    final almacen = AlmacenMemoria();
    final catalogo = catalogoReal();
    final container = ProviderContainer(
      overrides: [
        almacenProvider.overrideWithValue(almacen),
        preguntasProvider.overrideWithValue(PreguntasFijas(catalogo)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(partidaProvider.future);
    final controlador = container.read(partidaProvider.notifier);
    await controlador.empezar();
    almacen.fallar = true;
    await controlador.avanzar(pasar: true);
    expect(container.read(partidaProvider).requireValue.partida!.indice, 1);
    expect(container.read(partidaProvider).requireValue.aviso, isNotNull);
    almacen.fallar = false;
    await controlador.reintentarGuardado();
    expect(container.read(partidaProvider).requireValue.aviso, isNull);
    expect(
      (await RepositorioPartida(almacen).cargar(catalogo)).partida!.pasadas,
      1,
    );
  });
}
