import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trivia_antiguedad/app.dart';
import 'package:trivia_antiguedad/compartido/movimiento/movimiento.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/controladores/controlador_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';

import '../test/apoyo/base_pruebas.dart';

class _AudioAndroid extends RespuestaSonora {
  _AudioAndroid(super.habilitado, super.vibracion);
  final efectos = <EfectoInterfaz>[];
  final tiempos = <DateTime>[];
  @override
  void emitir(EfectoInterfaz efecto) {
    efectos.add(efecto);
    tiempos.add(DateTime.now());
    super.emitir(efecto);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const comenzar = ValueKey('comenzar-bienvenida');
  const cortina = ValueKey('cortina-inicial');
  late _AudioAndroid audio;
  ProviderContainer? containerActual;
  setUpAll(() async {
    audio = _AudioAndroid(() {
      try {
        return containerActual?.read(experienciaProvider).value?.sonidos ??
            false;
      } on Object {
        return false;
      }
    }, () => false);
    await audio.preparar();
  });
  setUp(() {
    containerActual = null;
    audio.silenciar();
    audio.efectos.clear();
    audio.tiempos.clear();
  });
  tearDownAll(() => audio.cerrar());

  Future<void> captura(WidgetTester tester, String nombre) async {
    debugPrint('QA-CAPTURA:$nombre');
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'apertura Android: espera, sonido real, silencio y una sola entrada',
    (tester) async {
      final almacen = AlmacenMemoria()
        ..datos[RepositorioExperiencia.clave] =
            '{"version":2,"tutorialVisto":true,"sonidos":true,"vibracion":false}';
      late ProviderContainer container;
      final inicio = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            almacenProvider.overrideWithValue(almacen),
            respuestaInterfazProvider.overrideWithValue(audio),
          ],
          child: const TriviaAntiguedadApp(modoConversacion: true),
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(TriviaAntiguedadApp)),
      );
      containerActual = container;
      await tester.pumpAndSettle();
      expect(audio.efectos, [EfectoInterfaz.bienvenida]);
      final espera = audio.tiempos.single.difference(inicio).inMilliseconds;
      expect(espera, greaterThanOrEqualTo(2000));
      debugPrint('QA-APERTURA:espera-real-ms=$espera');
      expect(find.byKey(comenzar).hitTestable(), findsOneWidget);
      await captura(tester, '01-comenzar-visible');
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(cortina), findsOneWidget);
      expect(audio.efectos, [EfectoInterfaz.bienvenida]);
      await tester.tap(find.byTooltip('Silenciar sonidos').hitTestable());
      await tester.pumpAndSettle();
      expect(container.read(experienciaProvider).value!.sonidos, isFalse);
      await tester.tap(find.byTooltip('Activar sonidos').hitTestable());
      await tester.pumpAndSettle();
      expect(container.read(experienciaProvider).value!.sonidos, isTrue);
      final punto = tester.getCenter(find.byKey(comenzar));
      final toque = DateTime.now();
      await tester.tapAt(punto);
      await tester.tapAt(punto);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1701));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('retiro-comenzar')))
            .opacity,
        closeTo(0, .001),
      );
      expect(find.byKey(cortina), findsOneWidget);
      final esperaSalida = tester
          .widget<EntradaInicio>(
            find.byKey(const ValueKey('entrada-pantalla-inicial')),
          )
          .progreso;
      expect(esperaSalida, 0);
      await captura(tester, '02-pausa-de-salida');
      await tester.pumpAndSettle();
      expect(audio.efectos, [
        EfectoInterfaz.bienvenida,
        EfectoInterfaz.activarSonido,
        EfectoInterfaz.comenzar,
        EfectoInterfaz.entradaInicio,
      ]);
      final llegada = audio
          .tiempos[audio.efectos.indexOf(EfectoInterfaz.entradaInicio)]
          .difference(toque)
          .inMilliseconds;
      expect(llegada, greaterThanOrEqualTo(1850));
      debugPrint('QA-APERTURA:llegada-real-ms=$llegada');
      expect(find.byKey(cortina), findsNothing);
      expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
      await captura(tester, '02-menu-despues-de-comenzar');
      await tester.pump(const Duration(seconds: 1));
      debugPrint('QA-AUDIO-REPOSO');
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('primera entrada Android abre la guía sin sonido duplicado', (
    tester,
  ) async {
    final almacen = AlmacenMemoria();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          almacenProvider.overrideWithValue(almacen),
          respuestaInterfazProvider.overrideWithValue(audio),
        ],
        child: const TriviaAntiguedadApp(modoConversacion: true),
      ),
    );
    containerActual = ProviderScope.containerOf(
      tester.element(find.byType(TriviaAntiguedadApp)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(comenzar));
    await tester.pumpAndSettle();
    expect(find.text('1 de 6'), findsOneWidget);
    expect(audio.efectos, [
      EfectoInterfaz.bienvenida,
      EfectoInterfaz.comenzar,
      EfectoInterfaz.entradaInicio,
    ]);
    await captura(tester, '03-primera-visita-guia');
    await tester.tap(find.byKey(const ValueKey('tutorial-omitir')));
    await tester.pumpAndSettle();
    expect(
      (await RepositorioExperiencia(almacen).cargar()).tutorialVisto,
      isTrue,
    );
  });

  testWidgets(
    'Android con movimiento reducido y sonido desactivado conserva la espera',
    (tester) async {
      final almacen = AlmacenMemoria()
        ..datos[RepositorioExperiencia.clave] =
            '{"version":2,"tutorialVisto":true,"sonidos":false,"vibracion":true}';
      final inicio = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            almacenProvider.overrideWithValue(almacen),
            respuestaInterfazProvider.overrideWithValue(audio),
            permitirMovimientoProvider.overrideWithValue(false),
          ],
          child: const TriviaAntiguedadApp(modoConversacion: true),
        ),
      );
      containerActual = ProviderScope.containerOf(
        tester.element(find.byType(TriviaAntiguedadApp)),
      );
      await tester.pumpAndSettle();
      expect(
        DateTime.now().difference(inicio).inMilliseconds,
        greaterThanOrEqualTo(2000),
      );
      expect(find.byKey(comenzar).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(comenzar));
      await tester.pumpAndSettle();
      expect(audio.efectos, isEmpty);
      expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
      await captura(tester, '04-menu-sin-movimiento-ni-sonido');
    },
  );
}
