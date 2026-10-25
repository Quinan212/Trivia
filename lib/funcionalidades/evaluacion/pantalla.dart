import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../compartido/componentes/boton_sonido.dart';
import '../../compartido/componentes/entrada_inicio.dart';
import '../../compartido/movimiento/coordinador_carta.dart';
import '../../compartido/movimiento/movimiento.dart';
import '../../compartido/sonidos/respuesta_interfaz.dart';
import '../../tema/paleta_evaluacion.dart';
import 'acta_pdf.dart';
import 'controlador.dart';
import 'configuracion.dart';
import 'preferencias_evaluacion.dart';
import 'dialogo_configuracion.dart';
import 'dialogo_estudiante.dart';
import 'estudiantes_json.dart';
import 'modelos.dart';
import 'mazo_evaluacion.dart';
import 'marca_pscs.dart';
import 'iconos_unidad_iv.dart';
import 'visor_acta.dart';
import 'barra_turno.dart';
import 'contorno_respuesta.dart';
import 'escenario_evaluacion.dart';
import 'sonidos_evaluacion.dart';
import 'repositorio.dart' show cargarContenidoTrivia;

class MarcaEvaluacion extends ConsumerWidget {
  const MarcaEvaluacion({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c =
        ref.watch(configuracionEvaluacionProvider).value ??
        const ConfiguracionEvaluacion();
    final p = PaletaEvaluacion.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          c.nombreCorto,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.tinta,
            fontSize: 38,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          c.tema,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.naranja,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          c.materia,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: p.tenue, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(c.comision, style: TextStyle(fontSize: 13, color: p.tenue)),
        const SizedBox(height: 20),
        const MarcaPscs(),
      ],
    );
  }
}

class PantallaEvaluacion extends ConsumerStatefulWidget {
  const PantallaEvaluacion({super.key, this.controlador});
  final ControladorEvaluacion? controlador;
  @override
  ConsumerState<PantallaEvaluacion> createState() => _PantallaEvaluacionState();
}

class _PantallaEvaluacionState extends ConsumerState<PantallaEvaluacion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ControladorEvaluacion? _c;
  String? _error;
  int _vista = 0;
  bool _ocupada = false;
  bool _editandoEstudiante = false;
  bool _previsualizandoConfiguracion = false;
  bool _avisoPuntajeAbierto = false;
  EstadoSonoroEvaluacion? _estadoSonoro;
  bool _silenciarCambioSonoro = false;
  String _busqueda = '', _tema = 'Todos';
  final _escenario = GlobalKey<EscenarioEvaluacionState>();
  final _barraTurno = GlobalKey();
  final _giro = ValueNotifier<int>(0);
  bool _reverso = false;
  String? _candidatoRobo;
  final Map<String, Future<({Uint8List bytes, int paginas})>> _pdfs = {};
  final _apellido = TextEditingController(), _nombre = TextEditingController();
  late final CoordinadorCarta _avanceCarta;
  final _scrollNomina = ScrollController();
  final _scrollResultados = ScrollController();
  final _scrollBanco = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _avanceCarta = CoordinadorCarta(vsync: this)
      ..alConfirmar = (_) {
        _hacer((m) => m.siguiente());
      }
      ..alEstabilizar = () {
        if (mounted) setState(() {});
      };
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    try {
      await ref.read(configuracionEvaluacionProvider.future);
      if (!mounted) return;
      final c = widget.controlador ?? await ControladorEvaluacion.abrir();
      if (!mounted) {
        if (widget.controlador == null) c.dispose();
        return;
      }
      ref
          .read(configuracionEvaluacionProvider.notifier)
          .mostrar(c.sesion.configuracion);
      _estadoSonoro = EstadoSonoroEvaluacion(c.sesion);
      c.addListener(_escucharEvaluacion);
      setState(() {
        _c = c;
        _vista = c.sesion.iniciada ? 1 : 0;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la trivia. $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _c?.pausar();
      _avanceCarta.estabilizar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c?.removeListener(_escucharEvaluacion);
    if (widget.controlador == null) _c?.dispose();
    _avanceCarta.dispose();
    _giro.dispose();
    _scrollNomina.dispose();
    _scrollResultados.dispose();
    _scrollBanco.dispose();
    _apellido.dispose();
    _nombre.dispose();
    super.dispose();
  }

  void _sonido(EfectoInterfaz efecto) =>
      ref.read(respuestaInterfazProvider).emitir(efecto);
  VoidCallback? _toque(VoidCallback? accion) => accion == null
      ? null
      : () {
          _sonido(EfectoInterfaz.evaluacionToque);
          accion();
        };
  void _escucharEvaluacion() {
    final configuracion = _c!.sesion.configuracion;
    if (!_previsualizandoConfiguracion &&
        jsonEncode(ref.read(configuracionEvaluacionProvider).value?.toJson()) !=
            jsonEncode(configuracion.toJson())) {
      ref.read(configuracionEvaluacionProvider.notifier).mostrar(configuracion);
    }
    final actual = EstadoSonoroEvaluacion(_c!.sesion);
    final efecto = _estadoSonoro == null
        ? null
        : actual.cambioDesde(_estadoSonoro!);
    _estadoSonoro = actual;
    if (mounted && !_silenciarCambioSonoro && efecto != null) _sonido(efecto);
  }

  void _hacer(void Function(MotorEvaluacion) fn) {
    try {
      final anterior = _c!.sesion.actualId;
      _c!.accion(fn);
      if (anterior != _c!.sesion.actualId ||
          _c!.sesion.fase == FaseEvaluacion.esperaRobo) {
        _candidatoRobo = null;
      }
      if (_c!.sesion.fase != FaseEvaluacion.revision) _reverso = false;
    } on Object catch (e) {
      _aviso(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _configurar() async {
    if (_previsualizandoConfiguracion) return;
    _c!.pausar();
    _previsualizandoConfiguracion = true;
    final preferencias = ref.read(configuracionEvaluacionProvider.notifier);
    try {
      final nueva = await editarConfiguracion(
        context,
        _c!.sesion.configuracion,
        onPrevisualizar: (configuracion) {
          if (mounted) preferencias.mostrar(configuracion);
        },
      );
      if (nueva == null || !mounted) return;
      setState(() => _ocupada = true);
      await _c!.configurar(nueva);
      if (!mounted) return;
      preferencias.mostrar(nueva);
      try {
        await preferencias.guardar(nueva);
      } on Object {
        /* La configuración ya está guardada con la evaluación. */
      }
      _pdfs.clear();
    } on Object {
      _aviso('No se pudo guardar la configuración. Reintentá.');
    } finally {
      _previsualizandoConfiguracion = false;
      if (mounted) {
        preferencias.mostrar(_c!.sesion.configuracion);
        setState(() => _ocupada = false);
      }
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _programarAvisoPuntaje() {
    final s = _c!.sesion;
    final id = s.avisoPuntajeId;
    if (id == null || _avisoPuntajeAbierto) return;
    _avisoPuntajeAbierto = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !identical(s, _c?.sesion) || s.avisoPuntajeId != id) {
        _avisoPuntajeAbierto = false;
        return;
      }
      final puntos = s.resultado(id).puntos;
      final completo = puntos >= 10;
      final nombre = s.alumno(id).completo;
      final finalizar = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: PaletaEvaluacion.of(context).tinta.withValues(alpha: .4),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        transitionBuilder: (context, entrada, salida, child) => FadeTransition(
          opacity: entrada,
          child: ScaleTransition(
            scale: Tween(begin: .94, end: 1.0).animate(
              CurvedAnimation(parent: entrada, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
        pageBuilder: (ctx, _, _) => PopScope(
          canPop: false,
          child: AlertDialog(
            scrollable: true,
            backgroundColor: PaletaEvaluacion.of(context).fondo,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: PaletaEvaluacion.of(context).borde),
            ),
            contentPadding: const EdgeInsets.fromLTRB(32, 30, 32, 18),
            actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
            content: SizedBox(
              width: 510,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFF246447),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    completo
                        ? 'El alumno $nombre alcanzó los 10 puntos.'
                        : 'El alumno $nombre aprobó con $puntos puntos. ¿Querés continuar evaluándolo para que pueda mejorar su nota o finalizar su evaluación con este puntaje?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.35,
                      color: PaletaEvaluacion.of(context).tinta,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!completo)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 52),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Finalizar'),
                ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      );
      if (mounted && identical(s, _c?.sesion) && s.avisoPuntajeId == id) {
        _hacer((m) => m.resolverAvisoPuntaje(finalizar: finalizar ?? false));
      }
      _avisoPuntajeAbierto = false;
    });
  }

  Future<bool> _confirmar(
    String titulo,
    String contenido,
    String boton,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titulo),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(contenido),
          ),
          actions: [
            TextButton(
              onPressed: _toque(() => Navigator.pop(ctx, false)),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: _toque(() => Navigator.pop(ctx, true)),
              child: Text(boton),
            ),
          ],
        ),
      ) ??
      false;
  void _cambiarVista(int v) {
    _escenario.currentState?.cambiarVista(v);
  }

  Future<void> _iniciar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final n = _c!.sesion.alumnos.where((a) => a.presente).length;
    if (await _confirmar(
      'Iniciar evaluación',
      'Se asignarán diez preguntas exclusivas por estudiante. Hay $n presentes. Los turnos se sortearán de forma equilibrada.',
      'Iniciar',
    )) {
      _hacer((m) => m.iniciar());
      if (_c!.sesion.iniciada) setState(() => _vista = 1);
    }
  }

  String _nombrePdf(SesionTrivia s, String? id) {
    if (id == null) return 'Informes_completos.pdf';
    final a = s.alumno(id);
    final limpio = '${a.apellido}_${a.nombre}'
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return 'Informe_$limpio.pdf';
  }

  Future<({Uint8List bytes, int paginas})> _generar(
    SesionTrivia s,
    String? id,
  ) {
    final clave = '${sha256.convert(utf8.encode(jsonEncode(s.toJson())))}_$id';
    if (!_pdfs.containsKey(clave) && _pdfs.length >= 8) {
      _pdfs.remove(_pdfs.keys.first);
    }
    return _pdfs.putIfAbsent(clave, () async {
      var paginas = 0;
      final generador = GeneradorActa(await RecursosActa.cargar());
      final bytes = id == null
          ? await generador.crearCompleto(
              s,
              _c!.banco,
              alContar: (n) => paginas = n,
            )
          : await generador.crear(
              s,
              _c!.banco,
              alumnoId: id,
              alContar: (n) => paginas = n,
            );
      return (bytes: bytes, paginas: paginas);
    });
  }

  Future<void> _verPdf([String? alumno]) async {
    if (_ocupada) return;
    _c!.pausar();
    _sonido(EfectoInterfaz.evaluacionMenu);
    setState(() => _ocupada = true);
    try {
      final s = SesionTrivia.fromJson(_c!.sesion.toJson(), _c!.banco);
      final acta = await _generar(s, alumno);
      await _c!.repositorio.guardarInforme(_nombrePdf(s, alumno), acta.bytes);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VistaActa(
            bytes: acta.bytes,
            nombre: _nombrePdf(s, alumno),
            paginas: acta.paginas,
            onInteraccion: () => _sonido(EfectoInterfaz.evaluacionToque),
          ),
        ),
      );
    } on Object {
      _aviso(
        'No se pudo preparar el PDF. Reintentá; la evaluación sigue guardada.',
      );
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _nueva() async {
    _c!.pausar();
    if (await _confirmar(
      'Nueva evaluación',
      'Se conservarán los estudiantes. Las respuestas y los puntos de la nueva evaluación comenzarán desde cero.',
      'Crear evaluación',
    )) {
      _c!.nuevaSesion();
      setState(() => _vista = 0);
    }
  }

  Future<void> _cargarBancoJson() async {
    if (_ocupada || !_c!.puedeSeleccionarBanco) return;
    _c!.pausar();
    _sonido(EfectoInterfaz.evaluacionMenu);
    setState(() => _ocupada = true);
    try {
      final archivo = await FilePicker.pickFile(
        dialogTitle: 'Cargar banco de preguntas',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (archivo == null || !mounted) return;
      final bytes = BytesBuilder(copy: false);
      await for (final bloque in archivo.readAsByteStream()) {
        if (bytes.length + bloque.length > 2 * 1024 * 1024) {
          throw const FormatException('El archivo JSON no puede superar 2 MB.');
        }
        bytes.add(bloque);
      }
      final banco = BancoTrivia.importar(utf8.decode(bytes.takeBytes()));
      if (!mounted) return;
      final reemplaza = _c!.sesion.iniciada && !_c!.sesion.finalizada;
      if (!await _confirmar(
        'Cargar banco',
        '${banco.nombre}\n${banco.preguntas.length} preguntas · ${banco.temas.length} temas'
            '${reemplaza ? '\n\nSe iniciará una nueva evaluación con estos estudiantes y los puntos en cero. La evaluación actual quedará guardada.' : ''}',
        reemplaza ? 'Crear evaluación' : 'Cargar',
      )) {
        return;
      }
      if (!mounted) return;
      await _c!.cambiarBanco(banco, crearNuevaEvaluacion: reemplaza);
      if (mounted) {
        setState(() {
          _tema = 'Todos';
          _busqueda = '';
          _pdfs.clear();
        });
      }
    } on Object catch (e) {
      _aviso(
        e is FormatException
            ? e.message
            : e is StateError
            ? e.message
            : 'No se pudo cargar el banco.',
      );
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _aplicarEstudiantes(
    List<AlumnoTrivia> alumnos,
    String titulo,
  ) async {
    final iniciada = _c!.sesion.iniciada;
    if (!await _confirmar(
      titulo,
      '${alumnos.length} estudiantes · ${alumnos.where((a) => a.presente).length} presentes'
      '\n\nSe reemplazará la lista actual.'
      '${iniciada ? '\nSe creará una nueva evaluación con puntos en cero. La anterior quedará guardada.' : ''}',
      iniciada ? 'Crear evaluación' : 'Cargar',
    )) {
      return;
    }
    if (!mounted) return;
    await _c!.cambiarEstudiantes(alumnos, crearNuevaEvaluacion: iniciada);
    if (mounted) {
      setState(() {
        _pdfs.clear();
        _apellido.clear();
        _nombre.clear();
        _candidatoRobo = null;
      });
    }
  }

  Future<void> _cargarEstudiantesJson() async {
    if (_ocupada || !_c!.puedeSeleccionarBanco) return;
    _c!.pausar();
    _sonido(EfectoInterfaz.evaluacionMenu);
    setState(() => _ocupada = true);
    try {
      final archivo = await FilePicker.pickFile(
        dialogTitle: 'Cargar estudiantes',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (archivo == null || !mounted) return;
      final bytes = BytesBuilder(copy: false);
      await for (final bloque in archivo.readAsByteStream()) {
        if (bytes.length + bloque.length > EstudiantesJson.maxBytes) {
          throw const FormatException(
            'El archivo de estudiantes no puede superar 256 KB.',
          );
        }
        bytes.add(bloque);
      }
      final alumnos = EstudiantesJson.importar(utf8.decode(bytes.takeBytes()));
      if (mounted) await _aplicarEstudiantes(alumnos, 'Cargar estudiantes');
    } on Object catch (e) {
      _aviso(
        e is FormatException
            ? e.message
            : e is StateError
            ? e.message
            : 'No se pudieron cargar los estudiantes.',
      );
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _guardarPlantillaEstudiantes() async {
    if (_ocupada) return;
    setState(() => _ocupada = true);
    _sonido(EfectoInterfaz.evaluacionMenu);
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Guardar plantilla de estudiantes',
        fileName: 'Plantilla-estudiantes.json',
        bytes: Uint8List.fromList(
          utf8.encode(EstudiantesJson.plantilla(_c!.sesion.alumnos)),
        ),
        mimeType: 'application/json',
      );
    } on Object {
      _aviso('No se pudo guardar la plantilla de estudiantes.');
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _restaurarEstudiantes() async {
    if (_ocupada || !_c!.puedeSeleccionarBanco) return;
    _c!.pausar();
    setState(() => _ocupada = true);
    try {
      final alumnos = (await cargarContenidoTrivia()).alumnos;
      if (mounted) {
        await _aplicarEstudiantes(alumnos, 'Estudiantes predeterminados');
      }
    } on Object catch (e) {
      _aviso(
        e is StateError
            ? e.message
            : 'No se pudieron restaurar los estudiantes.',
      );
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _editarEstudiante(AlumnoTrivia alumno) async {
    if (_ocupada || _editandoEstudiante) return;
    _c!.pausar();
    _sonido(EfectoInterfaz.evaluacionMenu);
    _editandoEstudiante = true;
    try {
      final cambio = await editarEstudiante(
        context,
        alumno,
        puedeEliminar: !_c!.sesion.iniciada && _c!.sesion.alumnos.length > 1,
        iniciada: _c!.sesion.iniciada,
      );
      if (cambio == null || !mounted) return;
      _hacer(
        (m) => cambio.eliminar
            ? m.eliminarAlumno(alumno.id)
            : m.editarAlumno(alumno.id, cambio.apellido, cambio.nombre),
      );
      _pdfs.clear();
    } finally {
      _editandoEstudiante = false;
    }
  }

  Widget _accionesEstudiantes() => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      for (final accion in [
        (
          'cargar-estudiantes-json',
          'Cargar estudiantes',
          Icons.upload_file_outlined,
          _cargarEstudiantesJson,
        ),
        (
          'guardar-plantilla-estudiantes',
          'Descargar plantilla de estudiantes',
          Icons.file_download_outlined,
          _guardarPlantillaEstudiantes,
        ),
        (
          'restaurar-estudiantes',
          'Restaurar estudiantes predeterminados',
          Icons.restart_alt,
          _restaurarEstudiantes,
        ),
      ])
        IconButton(
          key: ValueKey(accion.$1),
          tooltip: accion.$2,
          onPressed: _ocupada ? null : accion.$4,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(44),
            minimumSize: const Size.square(44),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(accion.$3),
        ),
    ],
  );

  Future<void> _guardarPlantillaJson() async {
    if (_ocupada) return;
    _sonido(EfectoInterfaz.evaluacionMenu);
    setState(() => _ocupada = true);
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Guardar plantilla de preguntas',
        fileName: 'Plantilla-preguntas.json',
        bytes: Uint8List.fromList(utf8.encode(_c!.banco.plantillaJson())),
        mimeType: 'application/json',
      );
    } on Object {
      _aviso('No se pudo guardar la plantilla.');
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _restaurarBanco() async {
    if (_ocupada || !_c!.puedeCambiarBanco) return;
    if (!await _confirmar(
      'Banco predeterminado',
      '¿Usar el banco de preguntas de Unidad IV?',
      'Usar banco',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _ocupada = true);
    try {
      await _c!.cambiarBanco((await cargarContenidoTrivia()).banco);
      if (mounted) {
        setState(() {
          _tema = 'Todos';
          _busqueda = '';
          _pdfs.clear();
        });
      }
    } on Object catch (e) {
      _aviso(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _ayuda() async {
    _c?.pausar();
    _sonido(EfectoInterfaz.evaluacionMenu);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cómo evaluar'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 580),
            child: Text(
              '${_c!.sesion.configuracion.materia}\n${_c!.sesion.configuracion.comision}\n\n1. Revisá los nombres y marcá presentes y ausentes.\n\n2. Iniciá la evaluación y sorteá un turno. Cada estudiante tiene diez preguntas distintas de las de los demás.\n\n3. Leé la pregunta y las opciones en voz alta; luego tocá «Iniciar tiempo» para habilitar los 60 segundos y registrar la alternativa elegida. Una respuesta correcta suma 1 punto; el error no resta.\n\n4. Si no acierta o se agota el tiempo, elegí otro estudiante para robar. Cada persona tiene un intento por pregunta. Un robo correcto suma 2 puntos.\n\n5. Podés cerrar los robos y revisar la respuesta y la explicación antes de avanzar. La nota máxima es 10 y se aprueba desde 7 puntos.\n\nLos informes individuales se abren desde Resultados.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _toque(() => Navigator.pop(ctx)),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Material(
        color: Colors.transparent,
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(_error!),
                ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.sesion;
        _programarAvisoPuntaje();
        final activa = s.actual != null && !s.finalizada;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: EscenarioEvaluacion(
              key: _escenario,
              vista: _vista,
              enPregunta: activa,
              esperandoSorteo:
                  _vista == 1 && s.iniciada && !s.finalizada && !activa,
              cabecera: _cabecera(),
              herramientas: _herramientas(),
              datosTurno: activa
                  ? DatosTurnoVertical(sesion: s, candidato: _candidatoRobo)
                  : const SizedBox.shrink(),
              anchoBarra: activa
                  ? BarraTurno.anchoPreferido(
                      context,
                      s,
                      candidato: _candidatoRobo,
                    )
                  : 752,
              altoBarraVertical: activa
                  ? BarraTurno.altoPreferidoVertical(
                      context,
                      s,
                      candidato: _candidatoRobo,
                    )
                  : 600,
              onSalir: () {
                _silenciarCambioSonoro = true;
                c.pausar();
                _silenciarCambioSonoro = false;
                FocusManager.instance.primaryFocus?.unfocus();
                _sonido(EfectoInterfaz.evaluacionNavegar);
              },
              onVista: (v) {
                setState(() => _vista = v);
              },
              onRebote: () => _sonido(EfectoInterfaz.evaluacionToque),
              onSortear: () => _hacer((m) => m.siguiente()),
              contenidoSorteo: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shuffle,
                    size: 42,
                    color: PaletaEvaluacion.of(context).naranjaTexto,
                  ),
                  SizedBox(height: 20),
                  Text(
                    '¡Ya arrancamos!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              pregunta: activa ? _preguntaActual() : const SizedBox.shrink(),
              barra: (datos, controles) => activa
                  ? BarraTurno(
                      key: _barraTurno,
                      vertical:
                          MediaQuery.orientationOf(context) ==
                          Orientation.portrait,
                      sesion: s,
                      motor: c.motor,
                      datos: datos,
                      controles: controles,
                      reverso: _reverso,
                      candidato: _candidatoRobo,
                      onCandidato: (id) {
                        _sonido(EfectoInterfaz.evaluacionToque);
                        setState(() => _candidatoRobo = id);
                      },
                      onAbrirSelector: () =>
                          _sonido(EfectoInterfaz.evaluacionMenu),
                      accion: (fn) => _hacer(fn),
                      siguiente: () {
                        _reverso = false;
                        _avanceCarta.ejecutar(AccionCarta.avanzar);
                      },
                      explicacion: () {
                        if (_c!.sesion.fase != FaseEvaluacion.revision ||
                            _c!.sesion.actual?.estado !=
                                EstadoPregunta.cerrada ||
                            _avanceCarta.ocupado) {
                          return;
                        }
                        _giro.value++;
                      },
                    )
                  : const SizedBox.shrink(),
              pagina: switch (_vista) {
                0 => _paginaCompleta(
                  _nomina(),
                  clave: const PageStorageKey('nomina-evaluacion'),
                  controlador: _scrollNomina,
                ),
                1 => _juego(),
                2 => _paginaCompleta(
                  _resultados(),
                  clave: const PageStorageKey('resultados-evaluacion'),
                  controlador: _scrollResultados,
                ),
                _ => _banco(),
              },
            ),
          ),
        );
      },
    );
  }

  Widget _avisoGuardado() => _c!.aviso == null
      ? const SizedBox.shrink()
      : _banner(
          _c!.aviso!,
          action: TextButton(
            onPressed: _c!.reintentar,
            child: const Text('Reintentar guardado'),
          ),
        );

  Widget _paginaCompleta(
    Widget contenido, {
    required PageStorageKey<String> clave,
    required ScrollController controlador,
  }) {
    return Scrollbar(
      controller: controlador,
      child: SingleChildScrollView(
        key: clave,
        controller: controlador,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _avisoGuardado(),
            if (_ocupada) const LinearProgressIndicator(minHeight: 2),
            contenido,
          ],
        ),
      ),
    );
  }

  Widget _herramientas() {
    final p = PaletaEvaluacion.of(context);
    final estilo = Theme.of(context).iconButtonTheme.style?.copyWith(
      fixedSize: const WidgetStatePropertyAll(Size.square(52)),
      minimumSize: const WidgetStatePropertyAll(Size.square(52)),
      maximumSize: const WidgetStatePropertyAll(Size.square(52)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Container(
      key: const ValueKey('herramientas-seccion'),
      padding: const EdgeInsets.all(10.5),
      decoration: BoxDecoration(
        color: p.hoja,
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: p.borde, width: 1.5),
      ),
      child: IconButtonTheme(
        data: IconButtonThemeData(style: estilo),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Cómo evaluar',
              onPressed: _ayuda,
              icon: const Icon(Icons.help_outline, size: 28),
            ),
            IconButton(
              key: const ValueKey('configuracion-evaluacion'),
              tooltip: 'Configuración',
              onPressed: _ocupada ? null : _configurar,
              icon: const Icon(Icons.settings_outlined, size: 28),
            ),
            Opacity(
              opacity: EntradaInicio.of(context)?.ocultarSonido == true ? 0 : 1,
              child: const BotonSonido(tamanoIcono: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marcaPagina(String titulo, {Widget? accion}) => LayoutBuilder(
    builder: (context, limites) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 28,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: PaletaEvaluacion.of(context).tinta,
            ),
          ),
        ),
        if (accion != null) ...[accion, const SizedBox(width: 12)],
        const SizedBox(width: 20),
        MarcaPscs(ancho: limites.maxWidth >= 600 ? 128 : 96),
      ],
    ),
  );

  Widget _cabecera() => LayoutBuilder(
    builder: (context, limites) => Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          _c!.sesion.configuracion.titulo,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: limites.maxWidth < 760 ? 22 : 28,
            fontWeight: FontWeight.w700,
            color: PaletaEvaluacion.of(context).tinta,
          ),
        ),
      ),
    ),
  );
  Widget _banner(String t, {Widget? action}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: PaletaEvaluacion.of(context).salviaClara,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            t,
            style: TextStyle(
              color: PaletaEvaluacion.of(context).tinta,
              fontSize: 14,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(28),
    Color? color,
    bool discreto = false,
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? PaletaEvaluacion.of(context).hoja,
      border: Border.all(
        color: discreto
            ? PaletaEvaluacion.of(context).tenue.withValues(alpha: .22)
            : PaletaEvaluacion.of(context).borde,
      ),
      borderRadius: BorderRadius.circular(25),
      boxShadow: discreto
          ? null
          : [
              BoxShadow(
                color: PaletaEvaluacion.of(context).tinta
                    .withValues(alpha: .035),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
    ),
    child: child,
  );
  Widget _boton(
    String texto,
    VoidCallback? accion, {
    IconData icono = Icons.arrow_forward,
    bool secundario = false,
    Color? borde,
    Key? key,
  }) => ToqueConRebote(
    child: secundario
        ? OutlinedButton.icon(
            key: key,
            onPressed: _toque(accion),
            icon: Icon(icono, size: 19),
            label: Text(texto),
            style: OutlinedButton.styleFrom(
              side: borde == null ? null : BorderSide(color: borde),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              textStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : FilledButton.icon(
            key: key,
            onPressed: _toque(accion),
            icon: Icon(icono, size: 19),
            label: Text(texto),
            style: FilledButton.styleFrom(
              foregroundColor: PaletaEvaluacion.of(context).sobreNaranja,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              textStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
  );
  Widget _nomina() {
    final s = _c!.sesion;
    final p = PaletaEvaluacion.of(context);
    final presentes = s.alumnos.where((a) => a.presente).length;
    final lista = _panel(
      discreto: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntradaSeccion(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _marcaPagina('Estudiantes', accion: _accionesEstudiantes()),
                const SizedBox(height: 14),
                Text(
                  '${s.configuracion.materia}\n${s.configuracion.comision}',
                  style: TextStyle(fontSize: 14, color: p.tenue, height: 1.4),
                ),
                const SizedBox(height: 20),
                Text(
                  '${s.alumnos.length} ${s.alumnos.length == 1 ? 'estudiante' : 'estudiantes'} · $presentes ${presentes == 1 ? 'presente' : 'presentes'}',
                  key: const ValueKey('resumen-asistencia'),
                  style: TextStyle(fontSize: 16, color: p.tenue),
                ),
              ],
            ),
          ),
          if (!s.iniciada) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => _hacer((m) {
                    for (final a in m.sesion.alumnos) {
                      m.asistencia(a.id, true);
                    }
                  }),
                  child: const Text('Marcar presentes'),
                ),
                TextButton(
                  onPressed: () => _hacer((m) {
                    for (final a in m.sesion.alumnos) {
                      m.asistencia(a.id, false);
                    }
                  }),
                  child: const Text('Marcar ausentes'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            key: const ValueKey('lista-estudiantes'),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: p.hoja,
              border: Border.all(color: p.tenue.withValues(alpha: .22)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (var i = 0; i < s.alumnos.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: p.tenue.withValues(alpha: .14),
                      ),
                    ),
                  EntradaSeccion(
                    orden: i,
                    child: _FilaAlumno(
                      key: ValueKey('fila-${s.alumnos[i].id}'),
                      alumno: s.alumnos[i],
                      onEditar: () => _editarEstudiante(s.alumnos[i]),
                      onPresencia: (v) =>
                          _hacer((m) => m.asistencia(s.alumnos[i].id, v)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!s.iniciada && s.alumnos.length < 20) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: _apellido,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 120,
                    buildCounter: (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: TextField(
                    controller: _nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 120,
                    buildCounter: (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                  ),
                ),
                _boton(
                  'Añadir',
                  () {
                    _hacer(
                      (m) => m.agregarAlumno(_apellido.text, _nombre.text),
                    );
                    _apellido.clear();
                    _nombre.clear();
                  },
                  icono: Icons.add,
                  secundario: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
    final reglas = _panel(
      discreto: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _boton(
            s.iniciada ? 'Ir a la evaluación' : 'Iniciar evaluación',
            s.iniciada
                ? () => _cambiarVista(1)
                : s.alumnos.any((a) => a.presente)
                ? _iniciar
                : null,
            key: const ValueKey('iniciar-evaluacion'),
            icono: Icons.play_arrow,
          ),
          const SizedBox(height: 12),
          _boton(
            'Nueva evaluación',
            _nueva,
            key: const ValueKey('nueva-evaluacion-estudiantes'),
            icono: Icons.restart_alt,
            secundario: true,
            borde: p.naranjaTexto,
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: p.tenue.withValues(alpha: .18)),
          for (final r in [
            ('10', 'preguntas por estudiante'),
            ('60 s', 'para responder'),
            ('+1', 'por respuesta correcta'),
            ('+2', 'por robo correcto'),
            ('7', 'puntos para aprobar'),
          ])
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 63,
                        child: Text(
                          r.$1,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: p.naranjaTexto,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          r.$2,
                          style: TextStyle(
                            color: p.tenue,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: p.tenue.withValues(alpha: .14)),
              ],
            ),
          const SizedBox(height: 18),
          Text(
            '${_c!.banco.preguntas.length} preguntas · ${_c!.banco.temas.length} ${_c!.banco.temas.length == 1 ? 'tema' : 'temas'}',
            style: TextStyle(fontSize: 13, color: p.tenue, height: 1.4),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (ctx, l) =>
          l.maxWidth / MediaQuery.textScalerOf(ctx).scale(1) >= 940
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: EntradaSeccion(orden: 1, child: lista),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 315,
                  child: EntradaSeccion(orden: 3, child: reglas),
                ),
              ],
            )
          : Column(
              children: [
                EntradaSeccion(orden: 1, child: lista),
                const SizedBox(height: 24),
                EntradaSeccion(orden: 3, child: reglas),
              ],
            ),
    );
  }

  Widget _juego() {
    final s = _c!.sesion;
    if (!s.iniciada) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: _panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconoUnidadIV(indice: 1, tamano: 58),
                const SizedBox(height: 20),
                const Text(
                  'Prepará la evaluación',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Revisá los estudiantes antes de asignar las preguntas.',
                ),
                const SizedBox(height: 25),
                _boton(
                  'Ver estudiantes',
                  () => _cambiarVista(0),
                  icono: Icons.people_outline,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (s.finalizada) {
      return Center(
        child: _panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconoUnidadIV(indice: 2, tamano: 58),
              const SizedBox(height: 20),
              const Text(
                'Evaluación finalizada',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _boton(
                    'Ver resultados',
                    () => _cambiarVista(2),
                    icono: Icons.assessment_outlined,
                  ),
                  _boton(
                    'Nueva evaluación',
                    _nueva,
                    key: const ValueKey('nueva-evaluacion-finalizada'),
                    icono: Icons.restart_alt,
                    secundario: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _preguntaActual() {
    final s = _c!.sesion;
    final r = s.actual!;
    return MazoEvaluacion(
      coordinador: _avanceCarta,
      preguntaId: r.preguntaId,
      indice: s.registros.keys.toList().indexOf(r.preguntaId),
      alMostrarSiguiente: () {
        _reverso = false;
        if (mounted) setState(() {});
      },
      child: _CartaEvaluacion(
        key: ValueKey(r.preguntaId),
        giro: _giro,
        reversoInicial: _reverso,
        banco: _c!.banco,
        registro: r,
        cerrada: s.fase == FaseEvaluacion.revision,
        indice: s.registros.keys.toList().indexOf(r.preguntaId),
        onGiro: (reverso) {
          _sonido(EfectoInterfaz.evaluacionExplicacion);
          setState(() => _reverso = reverso);
        },
      ),
    );
  }

  Widget _celdaResultado(AlumnoTrivia alumno, Widget child) =>
      EntradaSeccion(orden: _c!.sesion.alumnos.indexOf(alumno), child: child);

  Widget _resultados() {
    final s = _c!.sesion;
    final p = PaletaEvaluacion.of(context);
    return _panel(
      discreto: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EntradaSeccion(
            child: _marcaPagina(
              'Resultados',
              accion: IconButton(
                key: const ValueKey('todos-informes-pdf'),
                tooltip: 'Todos los informes (PDF)',
                onPressed: s.iniciada && !_ocupada ? () => _verPdf() : null,
                icon: const Icon(Icons.file_download_outlined),
              ),
            ),
          ),
          if (!s.iniciada) ...[
            const SizedBox(height: 12),
            _banner('Todavía no se inició la evaluación.'),
          ],
          if (s.cierreAnticipado) ...[
            const SizedBox(height: 12),
            _banner(
              'Cierre anticipado: el informe identifica las preguntas que no llegaron a plantearse.',
            ),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, limites) {
              final escala = MediaQuery.textScalerOf(context).scale(1);
              Widget celda(
                Widget contenido, {
                bool izquierda = false,
                double? margenHorizontal,
              }) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: margenHorizontal ?? (izquierda ? 20 : 8),
                  vertical: 10,
                ),
                child: Align(
                  alignment: izquierda
                      ? Alignment.centerLeft
                      : Alignment.center,
                  child: contenido,
                ),
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  width: math.max(limites.maxWidth, 930 * escala),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: p.tenue.withValues(alpha: .18)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: {
                      0: const FlexColumnWidth(),
                      1: FixedColumnWidth(108 * escala),
                      2: FixedColumnWidth(88 * escala),
                      3: FixedColumnWidth(62 * escala),
                      4: FixedColumnWidth(65 * escala),
                      5: FixedColumnWidth(65 * escala),
                      6: FixedColumnWidth(100 * escala),
                      7: FixedColumnWidth(60 * escala),
                    },
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: p.tenue.withValues(alpha: .14),
                      ),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: p.fondo),
                        children: [
                          for (final titulo in [
                            'Estudiante',
                            'Asistencia',
                            'Correctas',
                            'Robos',
                            'Puntos',
                            'Nota',
                            'Resultado',
                            'PDF',
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: celda(
                                Text(
                                  titulo,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: p.tenue,
                                  ),
                                ),
                                izquierda:
                                    titulo == 'Estudiante' ||
                                    titulo == 'Asistencia',
                                margenHorizontal: titulo == 'Estudiante'
                                    ? 20
                                    : 8,
                              ),
                            ),
                        ],
                      ),
                      for (final a in s.alumnos)
                        TableRow(
                          children: [
                            _celdaResultado(
                              a,
                              celda(
                                Text(
                                  a.completo,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                izquierda: true,
                              ),
                            ),
                            _celdaResultado(
                              a,
                              celda(
                                Text(
                                  a.presente ? 'Presente' : 'Ausente',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: p.tenue,
                                  ),
                                ),
                                izquierda: true,
                                margenHorizontal: 8,
                              ),
                            ),
                            _celdaResultado(
                              a,
                              celda(Text('${s.resultado(a.id).propias}')),
                            ),
                            _celdaResultado(
                              a,
                              celda(Text('${s.resultado(a.id).robos}')),
                            ),
                            _celdaResultado(
                              a,
                              celda(
                                Text(
                                  a.presente
                                      ? '${s.resultado(a.id).puntos}'
                                      : '—',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: a.presente
                                        ? p.naranjaTexto
                                        : p.tenue,
                                  ),
                                ),
                              ),
                            ),
                            _celdaResultado(
                              a,
                              celda(
                                Text(
                                  a.presente
                                      ? '${s.resultado(a.id).nota}/10'
                                      : '—',
                                ),
                              ),
                            ),
                            _celdaResultado(
                              a,
                              celda(
                                Text(
                                  !a.presente
                                      ? 'Ausente'
                                      : !s.finalizada
                                      ? 'En curso'
                                      : s.resultado(a.id).aprobado
                                      ? 'Aprobado'
                                      : 'No aprobado',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: !a.presente
                                        ? p.tenue
                                        : !s.finalizada
                                        ? p.naranjaTexto
                                        : s.resultado(a.id).aprobado
                                        ? p.correcto
                                        : p.error,
                                  ),
                                ),
                              ),
                            ),
                            _celdaResultado(
                              a,
                              celda(
                                IconButton(
                                  onPressed: s.iniciada && !_ocupada
                                      ? () => _verPdf(a.id)
                                      : null,
                                  tooltip: 'PDF de ${a.completo}',
                                  style: IconButton.styleFrom(
                                    fixedSize: const Size.square(44),
                                    minimumSize: const Size.square(44),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: const CircleBorder(),
                                  ),
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _banco() {
    final banco = _c!.banco;
    final p = PaletaEvaluacion.of(context);
    final texto = _busqueda.toLowerCase();
    final lista = banco.preguntas
        .where(
          (q) =>
              (_tema == 'Todos' || 'tema:${q.tema}' == _tema) &&
              ('${q.texto} ${q.subtema} ${q.opciones.join(' ')}')
                  .toLowerCase()
                  .contains(texto),
        )
        .toList();
    final temaVisible = _tema == 'Todos'
        ? '${banco.temas.length} ${banco.temas.length == 1 ? 'tema' : 'temas'}'
        : _tema.substring(5);
    InputDecoration campo({String? etiqueta, IconData? icono}) =>
        InputDecoration(
          labelText: etiqueta,
          hintText: etiqueta,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          prefixIcon: icono == null ? null : Icon(icono, size: 23),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          filled: true,
          fillColor: p.fondo,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.tenue.withValues(alpha: .22)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.tenue.withValues(alpha: .22)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.naranjaTexto),
          ),
        );
    final buscar = TextField(
      key: ValueKey('buscar-banco-${banco.huella}'),
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: campo(
        etiqueta: 'Buscar por texto o subtema',
        icono: Icons.search,
      ),
    );
    final temas = DropdownButtonFormField<String>(
      key: ValueKey('temas-banco-${banco.huella}'),
      initialValue: _tema,
      isExpanded: true,
      borderRadius: BorderRadius.circular(18),
      dropdownColor: p.hoja,
      items: [
        const DropdownMenuItem(value: 'Todos', child: Text('Todos')),
        ...banco.temas.map(
          (t) => DropdownMenuItem(
            value: 'tema:$t',
            child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) {
        _sonido(EfectoInterfaz.evaluacionToque);
        setState(() => _tema = v ?? 'Todos');
      },
      decoration: campo(etiqueta: 'Tema'),
    );
    final acciones = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('cargar-banco-json'),
          tooltip: 'Cargar banco JSON',
          onPressed: !_ocupada && _c!.puedeSeleccionarBanco
              ? _cargarBancoJson
              : null,
          icon: const Icon(Icons.upload_file_outlined),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const ValueKey('guardar-plantilla-json'),
          tooltip: 'Descargar plantilla JSON',
          onPressed: !_ocupada ? _guardarPlantillaJson : null,
          icon: const Icon(Icons.download_outlined),
        ),
        if (banco.personalizado) ...[
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('restaurar-banco-unidad-iv'),
            tooltip: 'Usar banco predeterminado',
            onPressed: !_ocupada && _c!.puedeCambiarBanco
                ? _restaurarBanco
                : null,
            icon: const Icon(Icons.restore),
          ),
        ],
      ],
    );
    return Scrollbar(
      controller: _scrollBanco,
      child: CustomScrollView(
        controller: _scrollBanco,
        key: const PageStorageKey('banco-evaluacion'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 24, bottom: 18),
            sliver: SliverToBoxAdapter(
              child: _panel(
                discreto: true,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _avisoGuardado(),
                    if (_ocupada) const LinearProgressIndicator(minHeight: 2),
                    EntradaSeccion(child: _marcaPagina('Banco de preguntas')),
                    const SizedBox(height: 8),
                    Text(
                      '${banco.nombre} · ${lista.length} preguntas · $temaVisible',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: p.tenue,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, limites) {
                        if (limites.maxWidth /
                                MediaQuery.textScalerOf(context).scale(1) >=
                            850) {
                          return Row(
                            children: [
                              Expanded(child: buscar),
                              const SizedBox(width: 12),
                              SizedBox(width: 240, child: temas),
                              const SizedBox(width: 12),
                              acciones,
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buscar,
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: math.min(280, limites.maxWidth),
                                  child: temas,
                                ),
                                acciones,
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList.separated(
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 18),
              itemBuilder: (_, i) {
                final q = lista[i];
                return EntradaSeccion(
                  orden: i,
                  child: _panel(
                    discreto: true,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${q.tema} · ${q.subtema}',
                          style: TextStyle(
                            fontSize: 14,
                            color: p.naranjaTexto,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          q.texto,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (var n = 0; n < 4; n++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: n == q.correcta
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                          color: p.naranjaTexto,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${'ABCD'[n]}. ${q.opciones[n]}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: n == q.correcta
                                          ? p.naranjaTexto
                                          : p.tenue,
                                      fontWeight: n == q.correcta
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Divider(
                          height: 28,
                          color: p.tenue.withValues(alpha: .18),
                        ),
                        Text(
                          q.explicacion,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: p.tenue,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaAlumno extends StatelessWidget {
  const _FilaAlumno({
    super.key,
    required this.alumno,
    required this.onPresencia,
    required this.onEditar,
  });
  final AlumnoTrivia alumno;
  final ValueChanged<bool> onPresencia;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final p = PaletaEvaluacion.of(context);
      final compacto =
          limites.maxWidth / MediaQuery.textScalerOf(context).scale(1) < 480;
      final estado = Text(
        alumno.presente ? 'Presente' : 'Ausente',
        style: TextStyle(
          fontSize: 13,
          color: alumno.presente ? p.naranjaTexto : p.tenue,
        ),
      );
      return Material(
        color: alumno.presente
            ? Color.alphaBlend(p.naranja.withValues(alpha: .07), p.hoja)
            : p.hoja,
        child: InkWell(
          onLongPress: onEditar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alumno.completo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (compacto) ...[const SizedBox(height: 4), estado],
                      ],
                    ),
                  ),
                  if (!compacto) ...[const SizedBox(width: 14), estado],
                  const SizedBox(width: 14),
                  Semantics(
                    label: 'Asistencia de ${alumno.completo}',
                    child: Switch(
                      key: ValueKey('asistencia-${alumno.id}'),
                      value: alumno.presente,
                      onChanged: onPresencia,
                      inactiveTrackColor: Color.alphaBlend(
                        p.tenue.withValues(alpha: .12),
                        p.hoja,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CartaEvaluacion extends StatefulWidget {
  const _CartaEvaluacion({
    super.key,
    required this.banco,
    required this.registro,
    required this.cerrada,
    required this.indice,
    required this.onGiro,
    required this.giro,
    required this.reversoInicial,
  });
  final BancoTrivia banco;
  final RegistroTrivia registro;
  final bool cerrada;
  final int indice;
  final ValueChanged<bool> onGiro;
  final ValueNotifier<int> giro;
  final bool reversoInicial;
  @override
  State<_CartaEvaluacion> createState() => _CartaEvaluacionState();
}

class _CartaEvaluacionState extends State<_CartaEvaluacion>
    with SingleTickerProviderStateMixin {
  late final CoordinadorCarta _motor = CoordinadorCarta(vsync: this)
    ..hayRepregunta = true
    ..reverso = widget.reversoInicial
    ..alConfirmar = (_) => widget.onGiro(!_motor.reverso);

  @override
  void initState() {
    super.initState();
    widget.giro.addListener(_girar);
  }

  @override
  void didUpdateWidget(_CartaEvaluacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.cerrada && _motor.reverso) {
      _motor.estabilizar();
      _motor.reverso = false;
    }
  }

  void _girar() => _motor.ejecutar(AccionCarta.girar);

  @override
  void dispose() {
    widget.giro.removeListener(_girar);
    _motor.dispose();
    super.dispose();
  }

  Widget _alternativa(int i) {
    final p = widget.banco.porId[widget.registro.preguntaId]!;
    final r = widget.registro;
    final ultimo = r.robos.lastOrNull ?? r.propio;
    final marcada = ultimo?.opcion == i;
    final correcta = marcada && ultimo!.correcto;
    return ContornoRespuesta(
      key: ValueKey('tarjeta-opcion-$i'),
      color: marcada
          ? (correcta
                ? const Color(0xFF246447)
                : PaletaEvaluacion.of(context).error)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22 * MediaQuery.textScalerOf(context).scale(1),
              child: Column(
                children: [
                  Text(
                    '${'ABCD'[i]}.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: marcada
                          ? (correcta
                                ? PaletaEvaluacion.of(context).correcto
                                : PaletaEvaluacion.of(context).error)
                          : PaletaEvaluacion.of(context).naranjaTexto,
                    ),
                  ),
                  if (marcada)
                    Icon(
                      correcta
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 19,
                      color: correcta
                          ? const Color(0xFF246447)
                          : PaletaEvaluacion.of(context).error,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                p.opciones[r.orden[i]],
                key: ValueKey('trivia-opcion-$i'),
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _altoTexto(String texto, TextStyle estilo, double ancho) {
    final medida = TextPainter(
      text: TextSpan(
        text: texto,
        style: DefaultTextStyle.of(context).style.merge(estilo),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: ancho);
    final alto = medida.height;
    medida.dispose();
    return alto;
  }

  double _altoPreferido(double ancho, double altoSubtema) {
    final p = widget.banco.porId[widget.registro.preguntaId]!;
    const pregunta = TextStyle(
      fontSize: 25,
      height: 1.25,
      fontWeight: FontWeight.w700,
    );
    const opcion = TextStyle(
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w500,
    );
    final columnas =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        ancho / MediaQuery.textScalerOf(context).scale(1) >= 560;
    final anchoTexto = (columnas ? (ancho - 12) / 2 : ancho) - 76;
    final opciones = [
      for (final i in widget.registro.orden)
        math.max(
          124.0,
          _altoTexto(p.opciones[i], opcion, anchoTexto).ceilToDouble() + 40,
        ),
    ];
    final altoOpciones = columnas
        ? math.max(opciones[0], opciones[1]) +
              12 +
              math.max(opciones[2], opciones[3])
        : opciones.reduce((a, b) => a + b) + 36;
    // 468 es la altura del boceto. Solo crece si el texto real lo necesita,
    // hasta el margen de la barra; las preguntas extensas conservan el scroll.
    return math.max(
      468.0,
      54 +
          MediaQuery.textScalerOf(context).scale(16) * 1.25 +
          6 +
          altoSubtema +
          22 +
          _altoTexto(p.texto, pregunta, ancho) +
          22 +
          altoOpciones +
          4,
    );
  }

  Widget _frente() {
    final p = widget.banco.porId[widget.registro.preguntaId]!;
    final estiloPregunta = TextStyle(
      fontSize: 25,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: PaletaEvaluacion.of(context).tinta,
    );
    return LayoutBuilder(
      builder: (context, limites) {
        final dos =
            MediaQuery.orientationOf(context) == Orientation.landscape &&
            limites.maxWidth / MediaQuery.textScalerOf(context).scale(1) >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.texto, style: estiloPregunta),
            const SizedBox(height: 22),
            if (!dos)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _alternativa(i),
                  ],
                ],
              )
            else
              Column(
                children: [
                  for (var fila = 0; fila < 2; fila++) ...[
                    if (fila > 0) const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 124),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _alternativa(fila * 2)),
                            const SizedBox(width: 12),
                            Expanded(child: _alternativa(fila * 2 + 1)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _cara(bool reverso, {double? altoDisponible}) {
    final altoMinimo = altoDisponible == null
        ? 0.0
        : math.max(0.0, altoDisponible - 4);
    final contenido = ConstrainedBox(
      constraints: BoxConstraints(minHeight: altoMinimo),
      child: reverso
          ? Text(
              widget.banco.porId[widget.registro.preguntaId]!.explicacion,
              style: TextStyle(
                fontSize: 25,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: PaletaEvaluacion.of(context).tinta,
              ),
            )
          : _frente(),
    );
    if (altoDisponible == null) return contenido;
    return SingleChildScrollView(
      key: ValueKey(
        reverso
            ? 'scroll-explicacion-evaluacion'
            : 'scroll-opciones-evaluacion',
      ),
      primary: false,
      padding: const EdgeInsets.only(bottom: 4),
      child: contenido,
    );
  }

  @override
  Widget build(BuildContext context) {
    _motor.reducido = MediaQuery.disableAnimationsOf(context);
    final p = widget.banco.porId[widget.registro.preguntaId]!;
    return LayoutBuilder(
      builder: (context, limites) => AnimatedBuilder(
        animation: _motor,
        builder: (context, _) {
          final giro = _motor.fase == FaseCarta.giro;
          final angulo = giro
              ? math.pi *
                    (_motor.reverso ? 1 - _motor.progreso : _motor.progreso)
              : (_motor.reverso ? math.pi : 0.0);
          final reverso = _motor.reducido
              ? _motor.caraReversa
              : angulo > math.pi / 2;
          final acotada = limites.hasBoundedHeight;
          final estiloSubtema = TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: PaletaEvaluacion.of(context).tenue,
          );
          final altoLineaSubtema =
              MediaQuery.textScalerOf(context).scale(16) * 1.35;
          final altoSubtema = math
              .max(
                _altoTexto(
                  p.subtema,
                  estiloSubtema,
                  math.max(1, limites.maxWidth - 56),
                ),
                _altoTexto(
                  'Explicación del banco',
                  estiloSubtema,
                  math.max(1, limites.maxWidth - 56),
                ),
              )
              .clamp(altoLineaSubtema, altoLineaSubtema * 2)
              .toDouble();
          final caras = IndexedStack(
            index: reverso ? 1 : 0,
            alignment: Alignment.topLeft,
            sizing: acotada ? StackFit.expand : StackFit.loose,
            children: [
              if (acotada)
                LayoutBuilder(
                  builder: (context, espacio) =>
                      _cara(false, altoDisponible: espacio.maxHeight),
                )
              else
                _cara(false),
              if (acotada)
                LayoutBuilder(
                  builder: (context, espacio) =>
                      _cara(true, altoDisponible: espacio.maxHeight),
                )
              else
                _cara(true),
            ],
          );
          return SizedBox(
            height: acotada
                ? MediaQuery.orientationOf(context) == Orientation.portrait
                      ? limites.maxHeight
                      : math.min(
                          limites.maxHeight,
                          _altoPreferido(limites.maxWidth - 58, altoSubtema),
                        )
                : null,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateY(_motor.reducido ? 0 : angulo),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(
                  !_motor.reducido && reverso ? math.pi : 0,
                ),
                child: Container(
                  width: double.infinity,
                  key: const ValueKey('superficie-pregunta'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 26,
                  ),
                  decoration: BoxDecoration(
                    color: PaletaEvaluacion.of(context).hoja,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: PaletaEvaluacion.of(context).borde,
                    ),
                  ),
                  child: IgnorePointer(
                    ignoring: _motor.ocupado,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.tema.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: PaletaEvaluacion.of(context).naranjaTexto,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: altoSubtema,
                          child: Text(
                            reverso ? 'Explicación del banco' : p.subtema,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: estiloSubtema,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (acotada) Expanded(child: caras) else caras,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
