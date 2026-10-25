import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';
import '../../tema/tema_evaluacion.dart';
import 'configuracion.dart';

Future<ConfiguracionEvaluacion?> editarConfiguracion(
  BuildContext context,
  ConfiguracionEvaluacion actual, {
  ValueChanged<ConfiguracionEvaluacion>? onPrevisualizar,
}) => showDialog<ConfiguracionEvaluacion>(
  context: context,
  barrierColor: const Color(0x52000000),
  builder: (_) => _DialogoConfiguracion(actual, onPrevisualizar),
);

class _DialogoConfiguracion extends StatefulWidget {
  const _DialogoConfiguracion(this.actual, this.onPrevisualizar);
  final ConfiguracionEvaluacion actual;
  final ValueChanged<ConfiguracionEvaluacion>? onPrevisualizar;
  @override
  State<_DialogoConfiguracion> createState() => _DialogoConfiguracionState();
}

class _DialogoConfiguracionState extends State<_DialogoConfiguracion> {
  final _formulario = GlobalKey<FormState>();
  late final _materia = TextEditingController(text: widget.actual.materia);
  late final _corto = TextEditingController(text: widget.actual.nombreCorto);
  late final _tema = TextEditingController(text: widget.actual.tema);
  late final _docente = TextEditingController(text: widget.actual.docente);
  late final _ayudante = TextEditingController(text: widget.actual.ayudante);
  late final _comision = TextEditingController(text: widget.actual.comision);
  List<TextEditingController> get _campos => [
    _materia,
    _corto,
    _tema,
    _docente,
    _ayudante,
    _comision,
  ];
  late final _focos = {for (final c in _campos) c: FocusNode()};
  late var _color = widget.actual.color;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    for (final c in _campos) {
      c.addListener(_actualizar);
      _focos[c]!.addListener(_actualizar);
    }
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  String _limpiar(String valor) => valor.trim().replaceAll(RegExp(r'\s+'), ' ');
  bool get _puedeGuardar {
    if (_cerrando ||
        _campos.any((c) => c != _ayudante && c.text.trim().isEmpty)) {
      return false;
    }
    final originales = [
      widget.actual.materia,
      widget.actual.nombreCorto,
      widget.actual.tema,
      widget.actual.docente,
      widget.actual.ayudante,
      widget.actual.comision,
    ];
    return _color != widget.actual.color ||
        [
          for (var i = 0; i < _campos.length; i++)
            _limpiar(_campos[i].text) != originales[i],
        ].any((cambio) => cambio);
  }

  @override
  void dispose() {
    for (final c in _campos) {
      c.removeListener(_actualizar);
      _focos[c]!
        ..removeListener(_actualizar)
        ..dispose();
      c.dispose();
    }
    super.dispose();
  }

  void _cerrar([ConfiguracionEvaluacion? resultado]) {
    if (_cerrando) return;
    setState(() => _cerrando = true);
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(resultado);
  }

  void _guardar() {
    if (!_puedeGuardar || !_formulario.currentState!.validate()) return;
    _cerrar(
      ConfiguracionEvaluacion.fromJson({
        'materia': _materia.text,
        'nombreCorto': _corto.text,
        'tema': _tema.text,
        'docente': _docente.text,
        'ayudante': _ayudante.text,
        'comision': _comision.text,
        'color': _color.name,
      }),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedTheme(
    data: temaEvaluacion(PaletaEvaluacion(_color)),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duracionCambioPaleta,
    curve: curvaCambioPaleta,
    child: Builder(builder: _contenido),
  );

  Widget _contenido(BuildContext context) {
    final p = PaletaEvaluacion.of(context);
    return Dialog(
      key: const ValueKey('dialogo-configuracion'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: p.fondo,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextButton(
                      onPressed: _cerrando ? null : () => _cerrar(),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cancelar', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Configuración',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: p.tinta,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: FilledButton(
                      onPressed: _puedeGuardar ? _guardar : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(100, 44),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Guardar', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('contenido-configuracion'),
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                child: Form(
                  key: _formulario,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _grupo(context, 'Evaluación', [
                        _campo(
                          context,
                          'Materia',
                          'materia',
                          _materia,
                          180,
                          multilinea: true,
                        ),
                        _campo(
                          context,
                          'Nombre corto de la materia',
                          'nombre-corto',
                          _corto,
                          60,
                        ),
                        _campo(context, 'Tema o unidad', 'tema', _tema, 80),
                      ]),
                      const SizedBox(height: 14),
                      _grupo(context, 'Docencia', [
                        _campo(context, 'Docente', 'docente', _docente, 120),
                        _campo(
                          context,
                          'Ayudante de cátedra',
                          'ayudante',
                          _ayudante,
                          120,
                          opcional: true,
                        ),
                        _campo(
                          context,
                          'Curso o comisión',
                          'comision',
                          _comision,
                          40,
                          ultimo: true,
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _grupo(context, 'Apariencia', [
                        _fila(context, 'Paleta de colores', _selectorPaleta()),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grupo(BuildContext context, String titulo, List<Widget> filas) {
    final p = PaletaEvaluacion.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.fondo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.tenue.withValues(alpha: .14), width: .8),
      ),
      padding: const EdgeInsets.all(.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.tinta,
              ),
            ),
          ),
          ColoredBox(
            color: p.hoja,
            child: Column(
              children: [
                for (var i = 0; i < filas.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: .8,
                      thickness: .8,
                      color: p.tenue.withValues(alpha: .12),
                    ),
                  filas[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(
    BuildContext context,
    String titulo,
    Widget contenido, {
    bool enfocada = false,
  }) {
    final p = PaletaEvaluacion.of(context);
    return ColoredBox(
      color: enfocada
          ? Color.alphaBlend(p.naranja.withValues(alpha: .035), p.hoja)
          : p.hoja,
      child: LayoutBuilder(
        builder: (context, limites) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: (limites.maxWidth * .28).clamp(140.0, 186.0),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: ExcludeSemantics(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: enfocada ? p.naranjaTexto : p.tenue,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: SizedBox(
                  width: .8,
                  child: ColoredBox(
                    color: p.tenue.withValues(alpha: enfocada ? .3 : .12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: contenido,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(
    BuildContext context,
    String titulo,
    String clave,
    TextEditingController controlador,
    int limite, {
    bool multilinea = false,
    bool opcional = false,
    bool ultimo = false,
  }) {
    final p = PaletaEvaluacion.of(context);
    return _fila(
      context,
      titulo,
      Semantics(
        label: titulo,
        child: TextFormField(
          key: ValueKey('configuracion-$clave'),
          controller: controlador,
          focusNode: _focos[controlador],
          maxLength: limite,
          minLines: multilinea ? 2 : 1,
          maxLines: multilinea ? null : 2,
          style: TextStyle(fontSize: 16, height: 1.4, color: p.tinta),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (_) {
            if (ultimo) {
              FocusScope.of(context).unfocus();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            filled: false,
            isDense: true,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
          validator: (valor) =>
              !opcional && (valor == null || valor.trim().isEmpty)
              ? 'Completá este campo.'
              : null,
        ),
      ),
      enfocada: _focos[controlador]!.hasFocus,
    );
  }

  Widget _selectorPaleta() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final tipo in ColorEvaluacion.values)
        Padding(
          padding: EdgeInsets.only(
            left: tipo == ColorEvaluacion.values.first ? 0 : 4,
          ),
          child: IconButton(
            key: ValueKey('paleta-${tipo.name}'),
            tooltip: switch (tipo) {
              ColorEvaluacion.rojo => 'Rojo',
              ColorEvaluacion.verde => 'Verde',
              ColorEvaluacion.azul => 'Azul',
              ColorEvaluacion.amarillo => 'Amarillo',
              ColorEvaluacion.naranja => 'Naranja',
            },
            isSelected: _color == tipo,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(44),
              minimumSize: const Size.square(44),
              padding: const EdgeInsets.all(2),
              backgroundColor: Colors.transparent,
              side: BorderSide.none,
              shape: const CircleBorder(),
            ),
            icon: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _color == tipo
                      ? const Color(0xFF0088FF)
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (tipo) {
                      ColorEvaluacion.rojo => const Color(0xFFFF383C),
                      ColorEvaluacion.verde => const Color(0xFF34C759),
                      ColorEvaluacion.azul => const Color(0xFF0088FF),
                      ColorEvaluacion.amarillo => const Color(0xFFFFCC00),
                      ColorEvaluacion.naranja => const Color(0xFFFF8D28),
                    },
                  ),
                  child: const SizedBox.square(dimension: 32),
                ),
              ),
            ),
            onPressed: () {
              setState(() => _color = tipo);
              widget.onPrevisualizar?.call(
                ConfiguracionEvaluacion.fromJson(
                  widget.actual.toJson()..['color'] = tipo.name,
                ),
              );
            },
          ),
        ),
    ],
  );
}
