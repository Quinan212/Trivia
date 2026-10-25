# Paleta de la portada Historia Antigua

Pedido del 21 de octubre de 2026: trasladar únicamente los colores de la portada proporcionada por Alan, sin cambiar letras, formas, tamaños, distribución, animaciones ni contenido del juego.

| Uso | Color muestreado de la portada |
|---|---|
| Fondo y superficies claras | Crema `#FCF8F0` |
| Texto e iconos | Marrón oscuro `#342725` |
| Texto secundario | Marrón `#795D54` |
| Botones, enlaces y marcas | Rojo `#B2190E` |
| Bordes | Terracota `#DA8F84` |
| Selección y figuras del fondo | Rosa `#F1D3C7` |
| Cartas en rotación | `#F5DFD4`, `#F1D3C7`, `#EDC7B9`, `#FCF8F0` |

Los filtros de color existentes del fondo y el logo se recalcularon para esta paleta. Los PNG permanecen idénticos, con la misma textura, geometría, transparencia y letras. El color de apertura nativo Android acompaña el fondo crema. La tipografía sigue siendo Outfit y los iconos Phosphor Bold.

Solo cambian dos archivos de producción: `lib/tema/tema_trivia_antiguedad.dart` y `android/app/src/main/res/values/colors.xml`. Los nombres históricos de los roles de color se conservan para evitar cambios ajenos al pedido.

`qa/paleta-tableta/` contiene la referencia, los respaldos de color, el inventario anterior y la comprobación de alcance. Los informes de `qa/clonacion/` documentan la etapa anterior de la copia, antes de esta nueva paleta.

## Tableta

AVD independiente `Trivia_Antiguedad_Tablet_API_36`, perfil Pixel Tablet, Android 16/API 36, x86_64, pantalla 2560 × 1600, densidad 320 dpi y 3 GB de RAM. Reutiliza la imagen Android ya instalada. Se abre en `emulator-5558`; no reemplaza ni modifica los AVD anteriores.

Esta etapa prepara el entorno de tableta y conserva la distribución actual de la app. La adaptación de sus medidas y organización para tableta es el trabajo siguiente.
