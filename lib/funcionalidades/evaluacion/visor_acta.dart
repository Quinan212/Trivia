import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../tema/paleta_evaluacion.dart';

class VistaActa extends StatefulWidget {
  const VistaActa({
    super.key,
    required this.bytes,
    required this.nombre,
    required this.paginas,
    this.rasterizar,
    this.onInteraccion,
  }) : assert(paginas > 0);
  final Uint8List bytes;
  final String nombre;
  final int paginas;
  final Future<Uint8List> Function(int pagina)? rasterizar;
  final VoidCallback? onInteraccion;

  @override
  State<VistaActa> createState() => _VistaActaState();
}

class _VistaActaState extends State<VistaActa> {
  final _transformacion = TransformationController();
  final _cache = <int, Future<Uint8List>>{};
  late Future<Uint8List> _imagen;
  int _pagina = 0;
  bool _cargando = true, _ocupada = false;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  void _preparar() {
    final pagina = _pagina;
    _cargando = true;
    _imagen = _cache.putIfAbsent(pagina, () async {
      if (widget.rasterizar != null) return widget.rasterizar!(pagina);
      final raster = await Printing.raster(
        widget.bytes,
        pages: [pagina],
        dpi: 160,
      ).first;
      return raster.toPng();
    });
    _imagen.then(
      (_) => _termino(pagina),
      onError: (Object _, StackTrace _) => _termino(pagina),
    );
    _cache.removeWhere((indice, _) => (indice - pagina).abs() > 1);
  }

  void _termino(int pagina) {
    if (mounted && pagina == _pagina) setState(() => _cargando = false);
  }

  void _ir(int pagina) {
    if (_cargando ||
        pagina < 0 ||
        pagina >= widget.paginas ||
        pagina == _pagina) {
      return;
    }
    setState(() {
      _pagina = pagina;
      _transformacion.value = Matrix4.identity();
      _preparar();
    });
  }

  Future<void> _operar(Future<void> Function() accion) async {
    if (_ocupada) return;
    setState(() => _ocupada = true);
    try {
      await accion();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar la acción. Podés reintentar.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _guardar() async {
    final uri = await FilePicker.saveFile(
      fileName: widget.nombre,
      bytes: widget.bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Guardar informe',
    );
    if (mounted && uri != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe guardado.')));
    }
  }

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  Widget _boton(
    String clave,
    String etiqueta,
    IconData icono,
    VoidCallback? accion, {
    bool principal = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: IconButton(
      key: ValueKey(clave),
      tooltip: etiqueta,
      onPressed: accion == null
          ? null
          : () {
              widget.onInteraccion?.call();
              accion();
            },
      icon: Icon(icono, size: 24),
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: principal
            ? PaletaEvaluacion.of(context).naranja
            : PaletaEvaluacion.of(context).hoja,
        foregroundColor: principal
            ? PaletaEvaluacion.of(context).sobreNaranja
            : PaletaEvaluacion.of(context).naranjaTexto,
        disabledForegroundColor: PaletaEvaluacion.of(context).deshabilitado,
        disabledBackgroundColor: PaletaEvaluacion.of(context)
            .fondoDeshabilitado,
        shape: CircleBorder(
          side: BorderSide(
            color: principal
                ? PaletaEvaluacion.of(context).naranjaTexto
                : PaletaEvaluacion.of(context).borde,
            width: 1.2,
          ),
        ),
      ),
    ),
  );

  Widget _barra() => SizedBox(
    key: const ValueKey('barra-visor'),
    width: 88,
    child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        decoration: BoxDecoration(
          color: PaletaEvaluacion.of(context).hoja,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: PaletaEvaluacion.of(context).borde),
          boxShadow: [
            BoxShadow(
              color: PaletaEvaluacion.of(context).tinta.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _boton(
              'visor-volver',
              'Volver',
              Icons.arrow_back,
              () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 8),
            _boton(
              'visor-anterior',
              'Página anterior',
              Icons.keyboard_arrow_up,
              _pagina > 0 && !_cargando ? () => _ir(_pagina - 1) : null,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                label: 'Página ${_pagina + 1} de ${widget.paginas}',
                child: ExcludeSemantics(
                  child: FittedBox(
                    child: Text(
                      '${_pagina + 1}/${widget.paginas}',
                      key: const ValueKey('visor-pagina'),
                      style: TextStyle(
                        fontSize: 12,
                        color: PaletaEvaluacion.of(context).tenue,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _boton(
              'visor-siguiente',
              'Página siguiente',
              Icons.keyboard_arrow_down,
              _pagina + 1 < widget.paginas && !_cargando
                  ? () => _ir(_pagina + 1)
                  : null,
            ),
            const SizedBox(height: 8),
            _boton(
              'visor-descargar',
              'Guardar PDF',
              Icons.download_outlined,
              _ocupada ? null : () => _operar(_guardar),
              principal: true,
            ),
            _boton(
              'visor-compartir',
              'Compartir PDF',
              Icons.share_outlined,
              _ocupada
                  ? null
                  : () => _operar(() async {
                      await Printing.sharePdf(
                        bytes: widget.bytes,
                        filename: widget.nombre,
                      );
                    }),
            ),
            _boton(
              'visor-imprimir',
              'Imprimir informe',
              Icons.print_outlined,
              _ocupada
                  ? null
                  : () => _operar(() async {
                      await Printing.layoutPdf(
                        onLayout: (_) async => widget.bytes,
                        name: widget.nombre,
                      );
                    }),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _documento() => FutureBuilder<Uint8List>(
    future: _imagen,
    builder: (context, estado) {
      if (estado.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (estado.hasError || !estado.hasData) {
        return Center(
          child: IconButton(
            tooltip: 'Reintentar',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _cache.remove(_pagina);
              _preparar();
            }),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, limites) {
          final alto = math.max(1.0, limites.maxHeight - 32);
          final ancho = math.min(
            math.max(1.0, limites.maxWidth - 32),
            alto / math.sqrt2,
          );
          return InteractiveViewer(
            key: const ValueKey('visor-documento'),
            transformationController: _transformacion,
            minScale: 1,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                width: ancho,
                height: ancho * math.sqrt2,
                decoration: BoxDecoration(
                  color: PaletaEvaluacion.of(context).hoja,
                  boxShadow: [
                    BoxShadow(
                      color: PaletaEvaluacion.of(context).tinta
                          .withValues(alpha: .16),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.memory(
                  estado.data!,
                  key: ValueKey('pagina-pdf-$_pagina'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          );
        },
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PaletaEvaluacion.of(context).salviaClara,
    body: SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 88),
          Expanded(child: _documento()),
          _barra(),
        ],
      ),
    ),
  );
}
