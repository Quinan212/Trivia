import 'dart:async';
import 'dart:io';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';

class _Plataforma extends AudioplayersPlatformInterface {
  final eventos = <String, StreamController<AudioEvent>>{};
  final llamadas = <(String, String)>[];
  final contextos = <String, AudioContext>{};
  Completer<void>? esperaResume;
  Completer<void>? esperaCatalogo;
  bool catalogoEsperando = false;
  final catalogoIniciado = Completer<void>.sync();
  @override
  Future<void> create(String id) async {
    eventos[id] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Stream<AudioEvent> getEventStream(String id) => eventos[id]!.stream;
  @override
  Future<void> setPlayerMode(String id, PlayerMode mode) async {}
  @override
  Future<void> setReleaseMode(String id, ReleaseMode mode) async {}
  @override
  Future<void> setAudioContext(String id, AudioContext context) async {
    contextos[id] = context;
  }

  @override
  Future<void> setVolume(String id, double volume) async {}
  @override
  Future<void> emitError(String id, String code, String message) async {}
  @override
  Future<void> emitLog(String id, String message) async {}
  @override
  Future<int?> getCurrentPosition(String id) async => 0;
  @override
  Future<int?> getDuration(String id) async => 0;
  @override
  Future<void> pause(String id) async {}
  @override
  Future<void> seek(String id, Duration position) async {}
  @override
  Future<void> setBalance(String id, double balance) async {}
  @override
  Future<void> setPlaybackRate(String id, double rate) async {}
  @override
  Future<void> setSourceBytes(
    String id,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    eventos[id]!.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceUrl(
    String id,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    if (url.contains('nivelSuave') && esperaCatalogo != null) {
      catalogoEsperando = true;
      if (!catalogoIniciado.isCompleted) catalogoIniciado.complete();
      await esperaCatalogo!.future;
    }
    eventos[id]!.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> resume(String id) async {
    llamadas.add(('resume', id));
    await esperaResume?.future;
  }

  @override
  Future<void> stop(String id) async => llamadas.add(('stop', id));
  @override
  Future<void> release(String id) async {}
  @override
  Future<void> dispose(String id) async => eventos[id]!.close();
}

class _Global extends GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
  @override
  Future<void> init() async {}
  @override
  Future<void> emitGlobalError(String code, String message) async {}
  @override
  Future<void> emitGlobalLog(String message) async {}
  @override
  Future<void> setGlobalAudioContext(AudioContext context) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'la apertura reproduce aunque el catálogo secundario siga cargando',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path,
          );
      await tester.runAsync(() async {
        final plataforma = _Plataforma();
        AudioplayersPlatformInterface.instance = plataforma;
        GlobalAudioplayersPlatformInterface.instance = _Global();
        plataforma.esperaCatalogo = Completer<void>();
        final respuesta = RespuestaSonora(() => true, () => false);
        final completa = respuesta.preparar();
        try {
          await respuesta.prepararApertura();
          await plataforma.catalogoIniciado.future.timeout(
            const Duration(seconds: 5),
          );
          expect(plataforma.catalogoEsperando, isTrue);
          respuesta.emitir(EfectoInterfaz.bienvenida);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.map((c) => c.$1), ['resume']);
          respuesta.emitir(EfectoInterfaz.comenzar);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.map((c) => c.$1), [
            'resume',
            'stop',
            'resume',
          ]);
        } finally {
          plataforma.esperaCatalogo!.complete();
          await completa;
          await respuesta.cerrar();
        }
      });
    },
  );
  testWidgets(
    'precarga, reemplazo, mute durante resume, pulsaciones rápidas y segundo plano',
    (tester) async {
      final plataforma = _Plataforma();
      AudioplayersPlatformInterface.instance = plataforma;
      GlobalAudioplayersPlatformInterface.instance = _Global();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path,
          );
      var habilitado = true;
      await tester.runAsync(() async {
        final respuesta = RespuestaSonora(() => habilitado, () => false);
        try {
          await respuesta.preparar();
          final cantidad = EfectoInterfaz.values.fold<int>(
            0,
            (n, e) => n + cantidadVariantes(e),
          );
          expect(plataforma.eventos.length, cantidad);
          expect(plataforma.contextos.length, cantidad);
          for (final contexto in plataforma.contextos.values) {
            expect(contexto.android.usageType, AndroidUsageType.media);
            expect(contexto.android.audioMode, AndroidAudioMode.normal);
            expect(contexto.android.isSpeakerphoneOn, isFalse);
            expect(contexto.android.audioFocus, AndroidAudioFocus.none);
          }
          respuesta.emitir(EfectoInterfaz.bienvenida);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          final primero = plataforma.llamadas.single.$2;
          respuesta.emitir(EfectoInterfaz.carta);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.map((c) => c.$1), [
            'resume',
            'stop',
            'resume',
          ]);
          expect(plataforma.llamadas[1].$2, primero);
          plataforma.llamadas.clear();
          respuesta.emitir(EfectoInterfaz.giro);
          respuesta.emitir(EfectoInterfaz.pasar);
          respuesta.emitir(EfectoInterfaz.volverCarta);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.map((c) => c.$1), ['stop', 'resume']);
          plataforma.llamadas.clear();
          plataforma.esperaResume = Completer<void>();
          respuesta.emitir(EfectoInterfaz.cierre);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          habilitado = false;
          respuesta.silenciar();
          plataforma.esperaResume!.complete();
          plataforma.esperaResume = null;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.last.$1, 'stop');
          plataforma.llamadas.clear();
          respuesta.emitir(EfectoInterfaz.carta);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(plataforma.llamadas, isEmpty);
          habilitado = true;
          respuesta.emitir(EfectoInterfaz.activarSonido);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.single.$1, 'resume');
          plataforma.llamadas.clear();
          final variantes = <String>[];
          for (var i = 0; i < 5; i++) {
            respuesta.emitir(EfectoInterfaz.carta);
            await Future<void>.delayed(const Duration(milliseconds: 20));
            variantes.add(plataforma.llamadas.last.$2);
          }
          expect(variantes.take(4).toSet().length, 4);
          expect(variantes[0], variantes[4]);
          for (var i = 1; i < variantes.length; i++) {
            expect(variantes[i], isNot(variantes[i - 1]));
          }
          habilitado = false;
          respuesta.emitir(EfectoInterfaz.carta);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          habilitado = true;
          respuesta.emitir(EfectoInterfaz.carta);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.last.$2, variantes[1]);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(plataforma.llamadas.last.$1, 'stop');
          plataforma.llamadas.clear();
          respuesta.emitir(EfectoInterfaz.carta);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(plataforma.llamadas, isEmpty);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          respuesta.emitir(EfectoInterfaz.carta);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(plataforma.llamadas.single.$1, 'resume');
        } finally {
          await respuesta.cerrar();
        }
      });
    },
  );
}
