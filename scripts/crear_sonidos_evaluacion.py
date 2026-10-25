"""Efectos originales de Unidad IV: PCM16 mono, síntesis determinista local."""
from pathlib import Path
import array
import json
import math
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/sonidos/evaluacion'
RATE = 22050


def efecto(nombre, duracion, notas=(), ruido=0, barrido=0):
    muestras = [0.0] * round(duracion * RATE)
    rng = random.Random(nombre)
    ultimo = 0.0
    for i in range(len(muestras)):
        t = i / RATE
        # Ruido filtrado y envolvente suaves: movimiento, sin golpes digitales.
        ultimo = .88 * ultimo + .12 * rng.uniform(-1, 1)
        muestras[i] = ruido * ultimo * math.sin(math.pi * t / duracion) ** 2
        if barrido:
            muestras[i] += .14 * math.sin(2 * math.pi * (330*t + barrido*t*t)) * math.sin(math.pi*t/duracion)**2
        for inicio, frecuencia, largo, fuerza in notas:
            u = t - inicio
            if not 0 <= u < largo:
                continue
            ataque = min(1, u / .007)
            cola = (1 - u / largo) ** 2
            tono = math.sin(2 * math.pi * frecuencia * u)
            tono += .22 * math.sin(2 * math.pi * frecuencia * 2.01 * u) * math.exp(-22*u)
            muestras[i] += fuerza * ataque * cola * tono
    pico = max(abs(x) for x in muestras) or 1
    ganancia = min(1, .55 / pico)
    pcm = array.array('h', (round(max(-1, min(1, x * ganancia)) * 32767) for x in muestras))
    if sys.byteorder != 'little':
        pcm.byteswap()
    destino = OUT / f'{nombre}.wav'
    with wave.open(str(destino), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(pcm.tobytes())
    return dict(archivo=destino.name, segundos=duracion, bytes=destino.stat().st_size)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    catalogo = [
        efecto('evaluacionToque', .075, [(0, 660, .075, .28)]),
        efecto('evaluacionInicio', .40, [(0,440,.22,.34),(.12,554,.24,.30),(.22,659,.18,.32)]),
        efecto('evaluacionTiempo', .17, [(0,523,.10,.34),(.07,784,.10,.26)]),
        efecto('evaluacionPausa', .14, [(0,440,.14,.28)]),
        efecto('evaluacionAgotado', .36, [(0,392,.18,.30),(.18,330,.18,.28)]),
        efecto('evaluacionCorrecta', .32, [(0,659,.21,.35),(.105,880,.215,.35)]),
        efecto('evaluacionIncorrecta', .26, [(0,262,.18,.35),(.09,220,.17,.24)]),
        efecto('evaluacionSinRespuesta', .20, [(0,330,.20,.30)]),
        efecto('evaluacionRobo', .29, [(0,440,.12,.32),(.105,587,.185,.33)]),
        efecto('evaluacionCerrar', .17, [(0,294,.17,.28)]),
        efecto('evaluacionDeshacer', .25, [(0,659,.14,.28),(.095,440,.155,.30)]),
        efecto('evaluacionAprobado', .58, [(0,523,.25,.31),(.14,659,.26,.30),(.29,784,.29,.34)]),
        efecto('evaluacionDiez', .78, [(0,523,.26,.29),(.13,659,.27,.29),(.26,784,.28,.29),(.42,1047,.36,.31),(.42,659,.36,.12)]),
        efecto('evaluacionFinal', .66, [(0,523,.25,.25),(.17,659,.27,.26),(.34,784,.32,.29),(.34,523,.32,.13)]),
        efecto('evaluacionNavegar', .23, ruido=.65, barrido=-360),
        efecto('evaluacionMenu', .115, [(0,554,.115,.26)], ruido=.12),
        efecto('evaluacionExplicacion', .23, [(0,494,.13,.21),(.09,587,.14,.23)], ruido=.16),
        efecto('evaluacionPasar', .16, ruido=1.1),
    ]
    evidencia = ROOT / 'qa/evaluacion/audio'
    evidencia.mkdir(parents=True, exist_ok=True)
    (evidencia / 'catalogo-original.json').write_text(json.dumps(catalogo, indent=2), encoding='utf-8')
    print(f'{len(catalogo)} efectos originales: {sum(c["bytes"] for c in catalogo):,} bytes')
