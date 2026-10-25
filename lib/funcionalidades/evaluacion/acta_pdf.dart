import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../tema/paleta_evaluacion.dart';
import 'modelos.dart';
import 'ornamentos_pdf.dart';

class RecursosActa {
  RecursosActa(this.datos);
  final Map<String, ByteData> datos;
  static Future<RecursosActa>? _carga;
  static Future<RecursosActa> cargar() => _carga ??= _leer();
  static Future<RecursosActa> _leer() async {
    const archivos = {
      'regular': 'assets/fuentes/pdf/LibreBaskerville-Regular.ttf',
      'bold': 'assets/fuentes/pdf/LibreBaskerville-Bold.ttf',
      'italic': 'assets/fuentes/pdf/LibreBaskerville-Italic.ttf',
      'boldItalic': 'assets/fuentes/pdf/LibreBaskerville-BoldItalic.ttf',
      'sans': 'assets/fuentes/Outfit-Regular.ttf',
      'sansBold': 'assets/fuentes/Outfit-Bold.ttf',
      'escudo': 'assets/documentos/escudo-pscs.jpg',
      'portada': 'assets/documentos/portada-original-2026.png',
    };
    return RecursosActa({
      for (final e in archivos.entries) e.key: await rootBundle.load(e.value),
    });
  }
}

class GeneradorActa {
  GeneradorActa(this.recursos);
  final RecursosActa recursos;
  static const crema = PdfColor.fromInt(0xFFFCF8F0);
  static const tinta = PdfColor.fromInt(0xFF342725);
  static const rojo = PdfColor.fromInt(0xFFB2190E);
  static const verde = PdfColor.fromInt(0xFF2D6A4F);
  static const tenue = PdfColor.fromInt(0xFF795D54);
  static const rosa = PdfColor.fromInt(0xFFF5DFD4);
  static const borde = PdfColor.fromInt(0xFFDA8F84);
  Future<Uint8List> crear(
    SesionTrivia sesion,
    BancoTrivia banco, {
    String? alumnoId,
    void Function(int)? alContar,
  }) async {
    final documento = await _crearDocumento(sesion, banco, alumnoId: alumnoId);
    final bytes = await documento.save();
    alContar?.call(documento.document.pdfPageList.pages.length);
    return bytes;
  }

  /// Los mismos informes individuales, con sus portadas y numeración propia.
  /// Se comparten fuentes y documento, sin rasterizar ni añadir dependencias.
  Future<Uint8List> crearCompleto(
    SesionTrivia sesion,
    BancoTrivia banco, {
    void Function(int)? alContar,
  }) async {
    final copia = SesionTrivia.fromJson(sesion.toJson(), banco);
    pw.Document? documento;
    for (final alumno in copia.alumnos) {
      documento = await _crearDocumento(
        copia,
        banco,
        alumnoId: alumno.id,
        destino: documento,
      );
      await Future<void>.delayed(Duration.zero);
    }
    if (documento == null) throw StateError('No hay estudiantes.');
    final bytes = await documento.save(enableEventLoopBalancing: true);
    alContar?.call(documento.document.pdfPageList.pages.length);
    return bytes;
  }

  Future<pw.Document> _crearDocumento(
    SesionTrivia sesion,
    BancoTrivia banco, {
    String? alumnoId,
    pw.Document? destino,
  }) async {
    sesion.validar(banco);
    final s = SesionTrivia.fromJson(sesion.toJson(), banco);
    final configuracion = s.configuracion;
    final nombreMateria = configuracion.materia;
    final nombreDocente = configuracion.docente;
    final nombreAyudante = configuracion.ayudante;
    final comisionMateria = configuracion.comision;
    final tituloUnidad = configuracion.titulo;
    final nombreAplicacion = configuracion.titulo;
    final p = PaletaEvaluacion(configuracion.color);
    PdfColor pdfColor(int valor) => PdfColor.fromInt(valor);
    final crema = pdfColor(p.fondo.toARGB32());
    final tinta = pdfColor(p.tinta.toARGB32());
    final rojo = pdfColor(p.naranjaTexto.toARGB32());
    final tenue = pdfColor(p.tenue.toARGB32());
    final rosa = pdfColor(p.salviaClara.toARGB32());
    final borde = pdfColor(p.borde.toARGB32());
    String hex(int v) => '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    String ornamento(String svg) {
      final colores = {
        '#FCF8F0': p.fondo,
        '#F1D3C7': p.salviaClara,
        '#F5DFD4': p.salviaClara,
        '#EDC7B9': p.salviaMedia,
        '#C24A3F': p.naranjaTexto,
        '#DA8F84': p.borde,
      };
      return svg.replaceAllMapped(
        RegExp(r'#[A-Fa-f0-9]{6}'),
        (m) =>
            colores.containsKey(m[0]) ? hex(colores[m[0]]!.toARGB32()) : m[0]!,
      );
    }

    final regular =
        destino?.theme?.defaultTextStyle.fontNormal ??
        pw.Font.ttf(recursos.datos['regular']!);
    final bold =
        destino?.theme?.defaultTextStyle.fontBold ??
        pw.Font.ttf(recursos.datos['bold']!);
    final italic =
        destino?.theme?.defaultTextStyle.fontItalic ??
        pw.Font.ttf(recursos.datos['italic']!);
    final boldItalic =
        destino?.theme?.defaultTextStyle.fontBoldItalic ??
        pw.Font.ttf(recursos.datos['boldItalic']!);
    final sans = pw.Font.ttf(recursos.datos['sans']!);
    final sansBold = pw.Font.ttf(recursos.datos['sansBold']!);
    final portada = pw.MemoryImage(
      recursos.datos['portada']!.buffer.asUint8List(),
    );
    final tema = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );
    final alumno = alumnoId == null ? null : s.alumno(alumnoId);
    final evaluacionCerrada =
        s.finalizada || (alumno != null && s.terminoAlumno(alumno.id));
    final titulo = alumno == null
        ? 'Informe de evaluación general'
        : 'Informe de evaluación';
    final documento =
        destino ??
        pw.Document(
          theme: tema,
          title: '$tituloUnidad · $titulo',
          author: nombreAyudante.isEmpty
              ? nombreDocente
              : '$nombreDocente; $nombreAyudante',
          subject: '$nombreMateria · $comisionMateria · ${configuracion.tema}',
          creator: nombreAplicacion,
          compress: true,
        );
    final inicioInforme = documento.document.pdfPageList.pages.length;
    var finInforme = inicioInforme + 1;
    pw.TextStyle estilo(
      double size, {
      bool fuerte = false,
      PdfColor? color,
      bool etiqueta = false,
    }) => pw.TextStyle(
      font: etiqueta ? (fuerte ? sansBold : sans) : (fuerte ? bold : regular),
      fontSize: size,
      color: color ?? tinta,
      lineSpacing: 1.8,
    );
    pw.Widget texto(
      String t, {
      double size = 10.2,
      PdfColor? color,
      bool fuerte = false,
      bool justificar = true,
    }) => pw.Text(
      t,
      textAlign: justificar ? pw.TextAlign.justify : pw.TextAlign.left,
      style: estilo(size, fuerte: fuerte, color: color),
    );
    pw.Widget marcaOpcion(
      String letra, {
      bool correcta = false,
      bool incorrecta = false,
    }) {
      final marcada = correcta || incorrecta;
      final color = correcta ? verde : GeneradorActa.rojo;
      final trazo = correcta
          ? '<path d="M2 6 L5 9 L10 2"/>'
          : '<path d="M2 2 L10 10 M10 2 L2 10"/>';
      return pw.SizedBox(
        width: 36,
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 16,
              height: 16,
              alignment: pw.Alignment.center,
              decoration: marcada
                  ? pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: color, width: 1.2),
                    )
                  : null,
              child: pw.Text(
                letra,
                style: estilo(
                  9.2,
                  fuerte: true,
                  color: marcada ? color : tinta,
                  etiqueta: true,
                ),
              ),
            ),
            if (marcada) ...[
              pw.SizedBox(width: 3),
              pw.SvgImage(
                width: 10,
                height: 10,
                svg:
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12"><g fill="none" stroke="${correcta ? '#2D6A4F' : '#B2190E'}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">$trazo</g></svg>',
              ),
            ],
          ],
        ),
      );
    }

    pw.Widget rotulo(String t) => pw.Text(
      t.toUpperCase(),
      style: estilo(8.2, fuerte: true, color: rojo, etiqueta: true),
    );
    pw.Widget marcaIntento(IntentoTrivia intento) => intento.opcion == null
        ? pw.SizedBox.shrink()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                marcaOpcion(
                  'ABCD'[intento.opcion!],
                  correcta: intento.correcto,
                  incorrecta: !intento.correcto,
                ),
              ],
            ),
          );
    pw.Widget tituloSeccion(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 15, bottom: 10),
      child: pw.Text(t, style: estilo(18, color: rojo)),
    );
    documento.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            // El PSCS, el escudo y los dibujos originales permanecen intactos.
            // La identidad principal corresponde a la Unidad IV, fuente de
            // esta actividad; el nombre de la materia queda en segundo nivel.
            pw.Positioned.fill(
              child: pw.SvgImage(
                svg: ornamento(ornamentosPortada),
                fit: pw.BoxFit.fill,
              ),
            ),
            pw.Positioned(
              left: 65,
              bottom: 37,
              child: pw.ClipRect(
                child: pw.SizedBox(
                  width: 160,
                  height: 55,
                  child: pw.Stack(
                    children: [
                      pw.Positioned(
                        left: -52.8,
                        top: -585.6,
                        child: pw.Image(
                          portada,
                          width: 497.92,
                          height: 704,
                          fit: pw.BoxFit.fill,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: 62,
              top: 55,
              child: pw.Container(width: 220, height: 20, color: crema),
            ),
            pw.Positioned(
              left: 65,
              top: 59,
              child: pw.Text(
                configuracion.nombreCorto,
                style: estilo(10.5, fuerte: true, color: rojo, etiqueta: true),
              ),
            ),
            pw.Positioned(
              left: 45,
              top: 110,
              child: pw.Container(width: 350, height: 135, color: crema),
            ),
            pw.Positioned(
              left: 65,
              top: 114,
              child: pw.SizedBox(
                width: 430,
                height: 125,
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.SizedBox(
                    width: 430,
                    child: pw.Text(
                      configuracion.tema,
                      style: pw.TextStyle(
                        font: boldItalic,
                        fontSize: 49,
                        color: tinta,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: 62,
              top: 260,
              child: pw.Container(width: 330, height: 31, color: crema),
            ),
            pw.Positioned(
              left: 65,
              top: 266,
              child: pw.Text(titulo, style: estilo(17, etiqueta: true)),
            ),
            pw.Positioned(
              left: 65,
              top: 303,
              child: pw.SizedBox(
                width: 420,
                height: 44,
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.topLeft,
                  child: pw.SizedBox(
                    width: 420,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          nombreMateria,
                          style: estilo(10, fuerte: true, etiqueta: true),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          comisionMateria,
                          style: estilo(9, etiqueta: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: 65,
              top: 356,
              child: pw.Container(
                width: 420,
                height: 30,
                alignment: pw.Alignment.topLeft,
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.topLeft,
                  child: pw.SizedBox(
                    width: 420,
                    child: pw.Text(
                      alumno?.completo ?? 'Registro de la comisión',
                      style: estilo(20, fuerte: true, etiqueta: true),
                    ),
                  ),
                ),
              ),
            ),
            if (s.id.startsWith('IV_SIMULACION'))
              pw.Positioned(
                left: 65,
                top: 380,
                child: pw.Text(
                  'MUESTRA DE DISEÑO · DATOS SIMULADOS',
                  style: estilo(8.4, fuerte: true, color: rojo, etiqueta: true),
                ),
              ),
            pw.Positioned(
              left: 65,
              top: 399,
              child: pw.Text(
                '${fechaArgentina(s.fecha)}  ·  ${evaluacionCerrada ? 'EVALUACIÓN FINALIZADA' : 'INFORME PARCIAL'}',
                style: estilo(8.4, color: tenue, etiqueta: true),
              ),
            ),
            pw.Positioned(
              left: 62,
              top: 607,
              child: pw.Container(width: 330, height: 23, color: crema),
            ),
            pw.Positioned(
              left: 65,
              top: 612,
              child: pw.SizedBox(
                width: 420,
                height: nombreAyudante.isEmpty ? 42 : 96,
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.topLeft,
                  child: pw.SizedBox(
                    width: 420,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Docente: $nombreDocente',
                          style: estilo(13, fuerte: true, etiqueta: true),
                        ),
                        if (nombreAyudante.isNotEmpty) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Ayudante de cátedra: $nombreAyudante',
                            style: estilo(11.5, etiqueta: true),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    pw.PageTheme interior() => pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(54, 42, 54, 45),
      buildBackground: (_) => pw.FullPage(
        ignoreMargins: true,
        child: pw.SvgImage(
          svg: ornamento(ornamentosInterior),
          fit: pw.BoxFit.fill,
        ),
      ),
    );
    pw.Widget cabecera(pw.Context c, [String? estudiante]) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 19),
      padding: const pw.EdgeInsets.only(bottom: 9),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: borde, width: .5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                rotulo(tituloUnidad),
                pw.SizedBox(height: 3),
                pw.Text(
                  estudiante ?? titulo,
                  style: estilo(8.3, color: tenue, etiqueta: true),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.ClipRect(
            child: pw.SizedBox(
              width: 88,
              height: 30,
              child: pw.Stack(
                children: [
                  pw.Positioned(
                    left: -29.04,
                    top: -322.08,
                    child: pw.Image(
                      portada,
                      width: 273.856,
                      height: 387.2,
                      fit: pw.BoxFit.fill,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    pw.Widget pie(pw.Context c) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 17),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borde, width: .4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'PSCS · Concordia',
            style: estilo(7, color: tenue, etiqueta: true),
          ),
          pw.Text(
            '${(c.pageNumber - inicioInforme).toString().padLeft(2, '0')} / ${(finInforme - inicioInforme).toString().padLeft(2, '0')}',
            style: estilo(7.5, fuerte: true, color: tenue, etiqueta: true),
          ),
        ],
      ),
    );
    void paginas(List<pw.Widget> widgets, {String? estudiante}) =>
        documento.addPage(
          pw.MultiPage(
            pageTheme: interior(),
            header: (c) => cabecera(c, estudiante),
            footer: pie,
            maxPages: 300,
            build: (_) => widgets,
          ),
        );
    pw.Widget cifras(List<(String, String)> valores) => pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 14),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: rosa,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          for (final v in valores)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    v.$1,
                    style: estilo(
                      17,
                      fuerte: true,
                      color: rojo,
                      etiqueta: true,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(v.$2, style: estilo(8, color: tenue, etiqueta: true)),
                ],
              ),
            ),
        ],
      ),
    );
    if (alumno == null) {
      final presentes = s.alumnos.where((a) => a.presente).toList();
      final aprobados = presentes
          .where((a) => s.resultado(a.id).aprobado)
          .length;
      final filas = <List<String>>[
        [
          'Estudiante',
          'Asistencia',
          'Correctas',
          'Robos acertados',
          'Puntos',
          'Nota',
          'Resultado',
        ],
        for (final a in s.alumnos)
          [
            a.completo,
            a.presente ? 'Presente' : 'Ausente',
            '${s.resultado(a.id).propias}',
            '${s.resultado(a.id).robos}',
            a.presente ? '${s.resultado(a.id).puntos}' : '—',
            a.presente ? '${s.resultado(a.id).nota}/10' : '—',
            !a.presente
                ? 'AUSENTE'
                : !s.finalizada
                ? 'EN CURSO'
                : s.resultado(a.id).aprobado
                ? 'APROBADO'
                : 'NO APROBADO',
          ],
      ];
      paginas([
        rotulo('Informe general'),
        pw.SizedBox(height: 10),
        pw.Text('Registro de evaluación', style: estilo(26)),
        pw.SizedBox(height: 14),
        texto(
          'Este informe documenta la evaluación de ${configuracion.tema}, realizada el ${fechaArgentina(s.fecha)} mediante $nombreAplicacion. Docente: $nombreDocente.${nombreAyudante.isEmpty ? '' : ' Ayudante de cátedra: $nombreAyudante.'} La asignatura se identifica a continuación. Se conservan los estudiantes, la asistencia, las preguntas asignadas, las alternativas en su orden de presentación y cada respuesta o intento de robo registrado.',
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '$nombreMateria · $comisionMateria',
          style: estilo(9, fuerte: true, etiqueta: true),
        ),
        cifras([
          ('${s.alumnos.length}', 'estudiantes'),
          ('${presentes.length}', 'presentes'),
          ('${s.alumnos.length - presentes.length}', 'ausentes'),
          (
            s.finalizada ? '$aprobados' : '—',
            s.finalizada ? 'aprobados' : 'evaluación en curso',
          ),
        ]),
        tituloSeccion('Criterios de calificación'),
        texto(
          'Cada estudiante dispone de diez preguntas, con sesenta segundos para cada respuesta. El docente inicia ese tiempo manualmente después de leer en voz alta la pregunta y sus alternativas; el tiempo de lectura no se descuenta. Una respuesta correcta suma un punto y un robo correcto suma dos. Los errores no descuentan puntos. Se aprueba desde siete puntos; el puntaje acumulado se conserva y la nota se expresa sobre diez, con un máximo de diez.',
        ),
        pw.SizedBox(height: 10),
        pw.SizedBox(height: 10),
        texto(
          !s.finalizada
              ? 'Este documento es un informe parcial. Las calificaciones y los registros pueden cambiar mientras continúe la evaluación.'
              : s.cierreAnticipado
              ? 'La evaluación se cerró antes de completar todas las preguntas de los estudiantes presentes. Las que no llegaron a plantearse se identifican expresamente como «No presentada al cerrar»; no se confunden con una respuesta incorrecta.'
              : 'La evaluación se encuentra finalizada. Las preguntas reservadas para estudiantes ausentes se conservan a efectos de trazabilidad; su ausencia no se transforma en una calificación.',
        ),
        tituloSeccion('Planilla de resultados'),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: rosa, width: .5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.1),
            1: const pw.FlexColumnWidth(1.05),
            2: const pw.FlexColumnWidth(.75),
            3: const pw.FlexColumnWidth(.75),
            4: const pw.FlexColumnWidth(.75),
            5: const pw.FlexColumnWidth(.8),
            6: const pw.FlexColumnWidth(1.6),
          },
          children: [
            for (var i = 0; i < filas.length; i++)
              pw.TableRow(
                repeat: i == 0,
                decoration: i == 0 ? pw.BoxDecoration(color: rosa) : null,
                children: [
                  for (var c = 0; c < filas[i].length; c++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 8,
                      ),
                      child: pw.Text(
                        filas[i][c],
                        textAlign: c >= 2 && c <= 5
                            ? pw.TextAlign.center
                            : pw.TextAlign.left,
                        style: estilo(
                          i == 0 ? 7.8 : 8.0,
                          fuerte: i == 0,
                          color: i == 0 ? rojo : tinta,
                          etiqueta: true,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ]);
    }
    for (final a in alumno == null ? s.alumnos : [alumno]) {
      final resultado = s.resultado(a.id);
      final intentos = <IntentoTrivia>[
        for (final r in resultado.registros)
          if (r.propio != null &&
              r.propio!.estado != EstadoIntento.noPresentada)
            r.propio!,
        for (final p in resultado.participaciones)
          if (p.intento.estado != EstadoIntento.cancelado) p.intento,
      ];
      final correctas = intentos.where((i) => i.correcto).length;
      final incorrectas = intentos
          .where((i) => i.estado == EstadoIntento.respondido && !i.correcto)
          .length;
      final sinRespuesta = intentos
          .where((i) => i.estado != EstadoIntento.respondido)
          .length;
      final terminada = s.finalizada || s.terminoAlumno(a.id);
      const notas = [
        'cero',
        'uno',
        'dos',
        'tres',
        'cuatro',
        'cinco',
        'seis',
        'siete',
        'ocho',
        'nueve',
        'diez',
      ];
      final resumen = !a.presente
          ? 'Ausente.'
          : 'Se registraron ${intentos.length} preguntas: '
                '$correctas ${correctas == 1 ? 'respuesta correcta' : 'respuestas correctas'}, '
                '$incorrectas ${incorrectas == 1 ? 'incorrecta' : 'incorrectas'}'
                '${sinRespuesta > 0 ? ' y $sinRespuesta sin responder' : ''}.'
                ' '
                '${terminada ? 'Resultado: ${resultado.aprobado ? 'Aprobado' : 'No aprobado'}. Nota final' : 'Evaluación en curso. Nota parcial'}: '
                '${resultado.nota} (${notas[resultado.nota]}).';

      final bloques = <pw.Widget>[
        rotulo('Registro individual'),
        pw.SizedBox(height: 10),
        pw.Text(a.completo, style: estilo(25)),
        pw.SizedBox(height: 10),
        pw.Text(
          '$nombreMateria · $comisionMateria',
          style: estilo(8.5, etiqueta: true),
        ),
        cifras([
          ('$correctas', 'correctas'),
          ('$incorrectas', 'incorrectas'),
          ('$sinRespuesta', 'sin responder'),
          (a.presente ? '${resultado.nota}/10' : '—', 'nota'),
        ]),
        texto(resumen),
      ];
      bloques.add(pw.SizedBox(height: 12));
      bloques.add(
        pw.Row(
          children: [
            marcaOpcion('', correcta: true),
            pw.Expanded(
              child: texto(
                'Alternativa correcta',
                size: 8.3,
                color: verde,
                justificar: false,
              ),
            ),
            marcaOpcion('', incorrecta: true),
            pw.Expanded(
              child: texto(
                'Elegida incorrectamente',
                size: 8.3,
                color: GeneradorActa.rojo,
                justificar: false,
              ),
            ),
          ],
        ),
      );
      void agregar(pw.Widget w, {String? titulo}) => bloques.add(
        pw.Inseparable(
          child: titulo == null
              ? w
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [tituloSeccion(titulo), w],
                ),
        ),
      );
      final ids = (s.paquetes[a.id] ?? <String>[]).where((id) {
        final intento = s.registros[id]!.propio;
        return intento != null && intento.estado != EstadoIntento.noPresentada;
      }).toList();
      for (var n = 0; n < ids.length; n++) {
        final r = s.registros[ids[n]]!;
        final p = banco.porId[r.preguntaId]!;
        final intento = r.propio;
        final seleccion = intento?.opcion == null
            ? ''
            : ' · Opción ${'ABCD'[intento!.opcion!]}';
        agregar(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borde, width: .45),
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                rotulo('${(n + 1).toString().padLeft(2, '0')} · ${p.tema}'),
                pw.SizedBox(height: 5),
                pw.Text(
                  p.subtema,
                  style: estilo(8, color: tenue, etiqueta: true),
                ),
                pw.SizedBox(height: 8),
                texto(p.texto, size: 10.6, fuerte: true),
                pw.SizedBox(height: 10),
                for (var i = 0; i < 4; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        marcaOpcion(
                          'ABCD'[i],
                          correcta: i == r.indiceCorrecto(banco),
                          incorrecta:
                              intento?.opcion == i &&
                              !(intento?.correcto ?? false),
                        ),
                        pw.Expanded(
                          child: texto(p.opciones[r.orden[i]], size: 9.2),
                        ),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 5),
                pw.Container(height: .4, color: rosa),
                pw.SizedBox(height: 8),
                texto(
                  'Respuesta del estudiante: ${etiquetaIntento(intento)}$seleccion.${intento?.correcto == true ? ' +${s.puntosOtorgados(intento!)} ${s.puntosOtorgados(intento) == 1 ? 'punto' : 'puntos'}.' : ''}${intento == null || intento.estado == EstadoIntento.noPresentada ? '' : ' Tiempo activo: ${(intento.tiempoMs / 1000).toStringAsFixed(1)} s.'}',
                  size: 8.8,
                  color: tenue,
                ),
              ],
            ),
          ),
          titulo: n == 0 ? 'Preguntas' : null,
        );
        if (r.robos.isNotEmpty) {
          for (var i = 0; i < r.robos.length; i++) {
            final at = r.robos[i];
            final persona = s.alumno(at.alumnoId);
            agregar(
              pw.Container(
                margin: const pw.EdgeInsets.only(left: 13, bottom: 7),
                padding: const pw.EdgeInsets.fromLTRB(11, 8, 11, 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: borde, width: 1.4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: rotulo(
                        '${at.correcto ? 'Robo' : 'Respuesta'} · Pregunta ${n + 1}',
                      ),
                    ),
                    marcaIntento(at),
                    texto(
                      '${persona.completo}: ${etiquetaIntento(at)}${at.opcion == null ? '' : ' · Opción ${'ABCD'[at.opcion!]}'}${at.correcto ? ' · +${s.puntosOtorgados(at)} ${s.puntosOtorgados(at) == 1 ? 'punto' : 'puntos'}' : ''}.',
                      size: 9.0,
                    ),
                  ],
                ),
              ),
            );
          }
          agregar(pw.SizedBox(height: 8));
        }
      }
      if (resultado.participaciones.isNotEmpty) {
        var primeraParticipacion = true;
        for (final participacion in resultado.participaciones) {
          if (participacion.intento.estado == EstadoIntento.cancelado) continue;
          final r = participacion.registro,
              at = participacion.intento,
              p = banco.porId[r.preguntaId]!;
          agregar(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: rosa,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  rotulo(
                    'Pregunta ${s.paquetes[r.titularId]!.indexOf(r.preguntaId) + 1} · Titular: ${s.alumno(r.titularId).completo}',
                  ),
                  pw.SizedBox(height: 8),
                  texto(p.texto, size: 9.8, fuerte: true),
                  pw.SizedBox(height: 7),
                  marcaIntento(at),
                  texto(
                    '${at.correcto ? 'Robo: ' : ''}${etiquetaIntento(at)}.${at.opcion == null ? '' : ' Alternativa elegida: ${'ABCD'[at.opcion!]} — ${p.opciones[r.orden[at.opcion!]]}.'}${at.correcto ? ' +${s.puntosOtorgados(at)} ${s.puntosOtorgados(at) == 1 ? 'punto' : 'puntos'}.' : ''}',
                    size: 9.2,
                  ),
                  pw.SizedBox(height: 5),
                  texto(
                    'Respuesta correcta: ${'ABCD'[r.indiceCorrecto(banco)]}. ${p.opciones[p.correcta]}',
                    size: 9.0,
                    color: verde,
                  ),
                ],
              ),
            ),
            titulo: primeraParticipacion
                ? 'Participaciones en preguntas de otros estudiantes'
                : null,
          );
          primeraParticipacion = false;
        }
      }
      paginas(bloques, estudiante: a.completo);
    }
    finInforme = documento.document.pdfPageList.pages.length;
    return documento;
  }
}
