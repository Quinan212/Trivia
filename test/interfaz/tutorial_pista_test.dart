import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/movimiento/coordinador_carta.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/componentes/mazo_preguntas.dart';
import 'package:trivia_antiguedad/tema/tema_trivia_antiguedad.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

class _Feedback implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() {}
}

Finder _clave(String valor) => find.byKey(ValueKey(valor));
CoordinadorCarta _motor(WidgetTester tester) =>
    tester.widget<MazoPreguntas>(find.byType(MazoPreguntas)).coordinador;

Future<void> _entrar(
  WidgetTester tester,
  _Feedback feedback, {
  bool movimiento = true,
}) async {
  await montar(
    tester,
    AlmacenMemoria(),
    animaciones: movimiento,
    respuesta: feedback,
  );
  await tocar(tester, 'ver-tutorial');
  await tocar(tester, 'tutorial-siguiente');
  await tocar(tester, 'tutorial-siguiente');
  feedback.efectos.clear();
}

Future<void> _durantePista(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 520));
  expect(_motor(tester).fase, FaseCarta.pista);
  expect(_motor(tester).desplazamiento, lessThan(-1));
}

void main() {
  testWidgets('la pista sale a la izquierda y vuelve una vez sin avanzar', (
    tester,
  ) async {
    final feedback = _Feedback();
    await _entrar(tester, feedback);
    final guia = tester.getRect(_clave('tutorial-burbuja'));
    final controles = tester.getRect(find.byType(ControlesCarta));
    final carta = tester.getRect(_clave('tarjeta-visible'));
    await _durantePista(tester);
    expect(_motor(tester).desplazamiento, greaterThanOrEqualTo(-12));
    expect(tester.getRect(_clave('tarjeta-visible')).left, greaterThan(0));
    expect(
      tester.getRect(_clave('tarjeta-visible')).left,
      lessThan(carta.left),
    );
    expect(tester.getRect(_clave('tutorial-burbuja')), guia);
    expect(tester.getRect(find.byType(ControlesCarta)), controles);
    expect(
      tester.getRect(_clave('tarjeta-visible')).top,
      greaterThan(carta.top),
    );
    final caja = tester.renderObject<RenderBox>(_clave('tarjeta-visible'));
    final esquinaIzquierda = caja.localToGlobal(Offset.zero);
    final esquinaDerecha = caja.localToGlobal(Offset(caja.size.width, 0));
    expect(esquinaIzquierda.dy - esquinaDerecha.dy, greaterThan(12));
    final borde = tester.widget<DecoratedBox>(_clave('tarjeta-visible'));
    final contorno = (borde.decoration as BoxDecoration).border! as Border;
    expect(contorno.top.width, greaterThan(2.5));
    expect(contorno.top.color.r, greaterThan(contorno.top.color.g + .25));
    expect(contorno.top.color.g, greaterThan(contorno.top.color.b));
    expect(_clave('otra-carta').hitTestable(), findsOneWidget);
    expect(feedback.efectos, [EfectoInterfaz.deslizamiento]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_motor(tester).fase, FaseCarta.pista);
    await tester.pumpAndSettle();
    expect(_motor(tester).fase, FaseCarta.reposo);
    expect(_motor(tester).desplazamiento, 0);
    expect(_motor(tester).intensidadPista, 0);
    expect(tester.getRect(_clave('tarjeta-visible')), carta);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('3 de 6'), findsOneWidget);
    expect(find.textContaining('Así vuelve'), findsNothing);
    expect(feedback.efectos, [EfectoInterfaz.deslizamiento]);
    await tocar(tester, 'tutorial-omitir');
  });

  testWidgets(
    'el contorno y la caída permanecen dentro de la práctica en los tres tamaños',
    (tester) async {
      final feedback = _Feedback();
      await _entrar(tester, feedback);
      for (final size in [
        const Size(320, 640),
        const Size(411, 914),
        const Size(600, 1100),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final motor = _motor(tester);
        expect(motor.mostrarPistaArrastre(), isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        final caja = tester.renderObject<RenderBox>(_clave('tarjeta-visible'));
        final esquinas = [
          caja.localToGlobal(Offset.zero),
          caja.localToGlobal(Offset(caja.size.width, 0)),
          caja.localToGlobal(Offset(0, caja.size.height)),
          caja.localToGlobal(Offset(caja.size.width, caja.size.height)),
        ];
        final accion = tester.getRect(_clave('otra-carta'));
        for (final esquina in esquinas) {
          expect(esquina.dx, greaterThanOrEqualTo(0), reason: '$size');
          expect(esquina.dx, lessThanOrEqualTo(size.width), reason: '$size');
          expect(esquina.dy, lessThan(accion.top), reason: '$size');
        }
        final borde = tester.widget<DecoratedBox>(_clave('tarjeta-visible'));
        final contorno = (borde.decoration as BoxDecoration).border! as Border;
        expect(contorno.top.color, TemaTriviaAntiguedad.naranja);
        await tester.pumpAndSettle();
      }
      await tocar(tester, 'tutorial-omitir');
    },
  );

  testWidgets(
    'Otra carta conserva la pose y el contorno al comenzar la salida',
    (tester) async {
      final feedback = _Feedback();
      await _entrar(tester, feedback);
      await _durantePista(tester);
      final antes = tester.getRect(_clave('tarjeta-visible'));
      final realce = _motor(tester).intensidadPista;
      await tester.tap(_clave('otra-carta'));
      await tester.pump();
      final saliente = tester.getRect(_clave('tarjeta-visible').last);
      expect(saliente.left, closeTo(antes.left, .01));
      expect(saliente.top, closeTo(antes.top, .01));
      expect(_motor(tester).intensidadPista, closeTo(realce, .01));
      await tester.pumpAndSettle();
      expect(find.text('2 de 3'), findsOneWidget);
      expect(_motor(tester).intensidadPista, 0);
      await tocar(tester, 'tutorial-omitir');
    },
  );

  testWidgets(
    'tomar la carta durante la pista conserva su posición y avanza una vez',
    (tester) async {
      final feedback = _Feedback();
      await _entrar(tester, feedback);
      await _durantePista(tester);
      final motor = _motor(tester);
      final desplazamiento = motor.desplazamiento;
      final dedo = await tester.startGesture(
        tester.getRect(_clave('tarjeta-visible')).center,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(motor.desplazamiento, desplazamiento);
      await dedo.moveBy(const Offset(-24, 0));
      await tester.pump();
      expect(motor.fase, FaseCarta.arrastre);
      expect(
        motor.desplazamiento,
        inInclusiveRange(desplazamiento - 24, desplazamiento),
      );
      await dedo.moveBy(const Offset(-150, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await dedo.up();
      await tester.pumpAndSettle();
      expect(find.text('2 de 3'), findsOneWidget);
      expect(feedback.efectos, [
        EfectoInterfaz.deslizamiento,
        EfectoInterfaz.carta,
      ]);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('4 de 6'), findsOneWidget);
      expect(motor.desplazamiento, 0);
      await tocar(tester, 'tutorial-omitir');
    },
  );

  testWidgets(
    'dos dedos pausan la pista hasta soltar ambos; el botón sigue funcionando',
    (tester) async {
      final feedback = _Feedback();
      await _entrar(tester, feedback);
      await _durantePista(tester);
      final motor = _motor(tester);
      final centro = tester.getRect(_clave('tarjeta-visible')).center;
      final a = await tester.startGesture(centro, pointer: 1);
      final b = await tester.startGesture(
        centro + const Offset(25, 0),
        pointer: 2,
      );
      final desplazamiento = motor.desplazamiento;
      await a.up();
      await tester.pump(const Duration(milliseconds: 350));
      expect(motor.desplazamiento, desplazamiento);
      await b.up();
      await tester.pumpAndSettle();
      expect(motor.desplazamiento, 0);
      expect(find.textContaining('Así vuelve'), findsNothing);
      await tocar(tester, 'tutorial-atras');
      await tocar(tester, 'tutorial-siguiente');
      feedback.efectos.clear();
      await _durantePista(tester);
      await tocar(tester, 'otra-carta');
      expect(find.text('2 de 3'), findsOneWidget);
      expect(feedback.efectos, [
        EfectoInterfaz.deslizamiento,
        EfectoInterfaz.carta,
      ]);
      await tocar(tester, 'tutorial-omitir');
    },
  );

  testWidgets(
    'navegar y salir a segundo plano cancelan la pista sin dejar desplazamiento',
    (tester) async {
      final feedback = _Feedback();
      await _entrar(tester, feedback);
      await tocar(tester, 'tutorial-siguiente');
      feedback.efectos.clear();
      await tester.pump(const Duration(seconds: 2));
      expect(_motor(tester).desplazamiento, 0);
      expect(feedback.efectos, isEmpty);
      await tocar(tester, 'tutorial-atras');
      feedback.efectos.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(_motor(tester).desplazamiento, 0);
      expect(feedback.efectos, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _durantePista(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(_motor(tester).desplazamiento, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
      expect(feedback.efectos, [EfectoInterfaz.deslizamiento]);
      expect(find.text('3 de 6'), findsOneWidget);
      expect(find.text('1 de 3'), findsOneWidget);
      await tocar(tester, 'tutorial-omitir');
    },
  );

  testWidgets(
    'tocar antes de la pista o reducir movimiento evita la sugerencia automática',
    (tester) async {
      final feedback = _Feedback();
      await _entrar(tester, feedback);
      await tester.tap(_clave('tarjeta-visible'));
      await tester.pump(const Duration(seconds: 2));
      expect(_motor(tester).desplazamiento, 0);
      expect(feedback.efectos, isEmpty);
      await tocar(tester, 'tutorial-omitir');
      await tester.pumpWidget(const SizedBox.shrink());
      await _entrar(tester, feedback, movimiento: false);
      await tester.pump(const Duration(seconds: 2));
      expect(_motor(tester).fase, FaseCarta.reposo);
      expect(feedback.efectos, isEmpty);
      await tocar(tester, 'otra-carta');
      expect(feedback.efectos, [EfectoInterfaz.carta]);
      await tocar(tester, 'tutorial-omitir');
    },
  );
}
