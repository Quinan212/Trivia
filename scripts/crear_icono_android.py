"""Adapta mecánicamente el original generado a los recursos nativos Android."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def generar():
    fuente = Image.open(ROOT / 'assets/identidad/icono-trivia-dialogo-original.png').convert('RGBA')
    # Ignorar píxeles casi transparentes aislados al medir el margen exterior.
    limites = fuente.getchannel('A').point(lambda alfa: 255 if alfa >= 32 else 0).getbbox()
    marca = fuente.crop(limites)
    res = ROOT / 'android/app/src/main/res'
    salida = res / 'drawable-nodpi'
    salida.mkdir(parents=True, exist_ok=True)
    # La marca completa permanece dentro de la zona segura del icono adaptativo.
    for nombre, proporcion, fondo in (
        ('trivia_dialogo_foreground.png', .58, (0, 0, 0, 0)),
        ('trivia_dialogo_legacy.png', .80, '#FCF8F0'),
    ):
        lienzo = Image.new('RGBA', (432, 432), fondo)
        miniatura = marca.copy()
        limite = round(432 * proporcion)
        miniatura.thumbnail((limite, limite), Image.Resampling.LANCZOS)
        lienzo.alpha_composite(miniatura, ((432-miniatura.width)//2, (432-miniatura.height)//2))
        lienzo.save(salida / nombre, optimize=True)
        if nombre == 'trivia_dialogo_legacy.png':
            preview = ROOT / 'output/imagegen/icono-trivia-dialogo.png'
            preview.parent.mkdir(parents=True, exist_ok=True)
            lienzo.save(preview, optimize=True)
            for densidad, tamano in (('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)):
                carpeta = res / f'mipmap-{densidad}'
                carpeta.mkdir(parents=True, exist_ok=True)
                lienzo.resize((tamano,tamano), Image.Resampling.LANCZOS).save(carpeta/'ic_launcher.png', optimize=True)


if __name__ == '__main__':
    generar()
