# Evaluación nativa y documentos de Unidad IV

La integración aprobada conserva el banco literal y aprovecha el motor visual y el audio del clon Flutter. Reglas y persistencia evaluativa están separadas de la partida de conversación heredada.

## Documentos

La portada utiliza como base la imagen original conservada en assets/documentos/portada-original-2026.png. Se sustituyen el título principal por Unidad IV, el tipo de documento por Informe de evaluación y el crédito por Docente: Javier Patricio Borche. El nombre completo de la materia queda como identificación secundaria. Son superposiciones de composición del PDF; el PSCS de contorno, el escudo y los dibujos se conservan exactamente, sin editar la imagen fuente. El interior utiliza ornamentos vectoriales, texto justificado en Libre Baskerville y tablas, rótulos y pies en Outfit. La aplicación conserva Outfit.

La denominación visible de la materia es Procesos sociales, políticos, económicos y culturales de la Antigüedad, en escritura normal; 1B · 2026 se muestra aparte. La propuesta de cátedra identifica a Javier Patricio Borche como docente. Los informes no atribuyen ese papel al autor de la herramienta ni muestran su nombre. La identificación 1B (2026) indicada por el usuario prevalece sobre los encabezados antiguos del programa. La nota corresponde exclusivamente a esta actividad.

Libre Baskerville proviene del repositorio oficial google/fonts (ofl/librebaskerville), con su licencia OFL en assets/fuentes/pdf/OFL-LibreBaskerville.txt. Se generaron instancias estáticas regular, negrita, cursiva y negrita cursiva para incrustarlas en el PDF y conservar los macrones. No hay descarga de fuentes al usar la aplicación. Los archivos del escudo y de la portada suministrados se conservan sin edición.

La planilla distingue presentes/ausentes, informe parcial y cierre anticipado. El registro individual conserva diez preguntas, el orden real de alternativas, la respuesta del titular, la clave y los intentos de robo. Los encabezados identifican al estudiante en cada página, las preguntas mantienen juntas sus cuatro opciones y cada robo identifica el número de su pregunta y a su titular. Los códigos internos del banco no se muestran en cartas, consulta docente ni PDF; se conservan en los respaldos para compatibilidad. Los títulos acompañan a su primer bloque. Los informes de QA están marcados como muestras con datos simulados.

La vista previa carga una página por vez a 120 dpi y permite recorrer todas las páginas con Anterior/Siguiente. Guardar, compartir e imprimir utilizan el PDF completo. Esto evita rasterizar simultáneamente actas extensas en el heap limitado de Android. Los PDF internos se escriben en serie y se conserva una caché acotada de ocho informes generados.

## Persistencia

Formato trivia-antiguedad-evaluacion v1, ligado al SHA-256 del banco exacto. El controlador sincroniza el reloj activo antes de aceptar cada acción. Pausa en segundo plano y recuperación pausada. Guardado por acción y cada cinco segundos de tiempo activo, archivo temporal, copia anterior válida e historial. La lectura no sobrescribe archivos dañados; se preservan en una carpeta de recuperación al volver a guardar. Los respaldos React del ZIP no se importan como si fueran sesiones nativas.

## Reproducción de verificaciones

- flutter analyze --no-pub
- flutter test --no-pub
- flutter build apk --release
- python -X utf8 scripts/validar_pdf_evaluacion.py
- Inspección Android por etiquetas observadas con scripts/qa_evaluacion_android.py, en un AVD de QA separado, solo cuando esté autorizado levantarlo.

No ejecutar pruebas y compilación Flutter simultáneamente. Las pruebas de PDF crean muestras, no actas reales. La auditoría textual comprueba las 200 preguntas con sus cuatro opciones en la misma página, numeración y caracteres fuera del lienzo; el render se revisa visualmente. Los WAV y el JSON del banco se comparan por bytes con sus fuentes.

## Lectura y tiempo manual

Cada pregunta propia y cada intento de robo se crean con pausada=true y restanteMs=60000. La lectura en voz alta no hace avanzar el reloj ni permite registrar una alternativa por accidente. El docente habilita la respuesta mediante Iniciar tiempo, y luego puede pausar y reanudar desde el panel de controles lateral o integrado en la página vertical. No cambian el formato de respaldo, el cálculo de puntos ni la duración disponible. La recuperación conserva el reloj detenido.

La cabecera de turno reserva altura y ancho para estudiante, fase, número y reloj. El área desplazable tiene identidad y controlador estables: responder o cambiar al participante del robo no vuelve al principio. Una pregunta nueva sí comienza arriba. Se verifica con las alternativas más extensas, texto hasta escala 2 y un robo completo.

La entrada completa desde la bienvenida debe probarse además de la pantalla aislada. La nómina permanece oculta hasta Comenzar y se revela con el reloj de PuertaBienvenida; al terminar desaparece la cortina y queda un solo botón de sonido. Se comprueban gestos de desplazamiento con animaciones y con movimiento reducido.

Nómina, resultados y banco incluyen cabecera y pie dentro del desplazamiento. El banco utiliza slivers para mantener la creación diferida de las doscientas tarjetas; títulos y filtros salen del campo visible al deslizar. FundidoBordeScroll aplica el fundido original a cada página con un controlador independiente. AnimatedSwitcher anima el cambio de sección. La pregunta horizontal reúne nombre, puntos, respuestas, reloj y controles en una columna lateral; toda la composición comparte un único recorrido vertical, sin barras fijas que tapen contenido.

En los PDF cada alternativa conserva su letra según el orden presentado. La clave lleva círculo verde y tilde vectorial; una opción elegida incorrectamente lleva círculo rojo y cruz vectorial. Las letras siguen siendo texto seleccionable y las marcas no dependen de glifos especiales. Se incluye leyenda y se identifican también las alternativas elegidas en robos.

MazoEvaluacion adapta la composición de MazoPreguntas del juego original y utiliza su mismo CoordinadorCarta sin modificar el original. Conserva la cara saliente mediante una clave de estado propia: sale opaca hacia la izquierda en 220 ms, mientras la siguiente permanece debajo; luego se asienta en 160 ms. La pregunta se confirma una sola vez al tocar Siguiente, y los controles quedan bloqueados durante la transición. Movimiento reducido elimina traslación y giro. El scroll se restablece al retirar la carta saliente, no al confirmar el dominio. Durante cambios de fase de la misma pregunta se conserva una altura mínima para evitar que el cierre del panel de robo fuerce un salto por reducción del recorrido.


En el informe, el círculo verde con tilde identifica la clave directamente entre las alternativas. Se eliminó la repetición de «Alternativa correcta» seguida de la misma opción y su texto debajo de cada pregunta. El resumen conserva el resultado del estudiante y el tiempo activo; se mantienen el círculo rojo con cruz y las marcas de los robos.
