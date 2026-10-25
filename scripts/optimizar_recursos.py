"""Genera recursos de distribución; conserva los PNG originales como fuentes."""
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]


def convertir(origen, destino, limite=None):
    fuente = ROOT / origen
    salida = ROOT / destino
    salida.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(fuente) as imagen:
        imagen = imagen.convert('RGBA')
        if limite:
            imagen.thumbnail((limite, limite), Image.Resampling.LANCZOS)
        if salida.suffix == '.webp':
            imagen.save(salida, lossless=True, method=6)
        else:
            imagen.save(salida, optimize=True, compress_level=9)
        with Image.open(salida) as decodificada:
            assert decodificada.size == imagen.size
            decodificada = decodificada.convert('RGBA')
            assert ImageChops.difference(imagen.getchannel('A'), decodificada.getchannel('A')).getbbox() is None
            # RGB bajo alfa cero no se ve; comparar composición, no esos bytes.
            for fondo in ('black', 'white'):
                base = Image.new('RGBA', imagen.size, fondo)
                antes = Image.alpha_composite(base, imagen)
                despues = Image.alpha_composite(base, decodificada)
                assert ImageChops.difference(antes, despues).getbbox(alpha_only=False) is None
    print(f'{origen}: {fuente.stat().st_size:,} -> {salida.stat().st_size:,} bytes')


if __name__ == '__main__':
    for nombre in ('conversation-background-v2', 'trivia-antiguedad-logo', 'marcas-naranjas'):
        convertir(f'assets/imagenes/{nombre}.png', f'assets/imagenes/optimizadas/{nombre}.webp')
    for nombre in ('estudiantes', 'evaluacion', 'resultados', 'banco'):
        convertir(f'assets/imagenes/iconos-unidad-iv/{nombre}.png',
                  f'assets/imagenes/iconos-unidad-iv/optimizados/{nombre}.webp', 256)
    from crear_icono_android import generar
    generar()
