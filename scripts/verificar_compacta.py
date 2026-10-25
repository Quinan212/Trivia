"""Verifica presupuesto, integridad y recursos conservados de la APK ARM64."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.search(r'^version: ([^+]+)', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)[1]
CODIGO = int(re.search(r'^version: [^+]+\+(\d+)', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)[1])
APK = ROOT / f'output/Trivia-Unidad-IV-{VERSION}-arm64.apk'
BASE = ROOT / 'output/Trivia-Unidad-IV-1.1.45.apk'
TOOLS = Path.home() / 'AppData/Local/Android/Sdk/build-tools/36.0.0'


def ejecutar(*args):
    return subprocess.run([str(a) for a in args], check=True, capture_output=True).stdout.decode('utf-8', errors='replace')


if __name__ == '__main__':
    assert APK.stat().st_size <= 15_000_000, 'Supera 15 MB decimales.'
    with zipfile.ZipFile(BASE) as base, zipfile.ZipFile(APK) as actual:
        assert actual.testzip() is None
        conservados = [p for p in base.namelist() if p.startswith((
            'assets/flutter_assets/assets/contenido/',
            'assets/flutter_assets/assets/sonidos/',
            'assets/flutter_assets/assets/fuentes/',
        )) or p.endswith(('portada-original-2026.png', 'escudo-pscs.jpg'))]
        for p in conservados:
            assert base.read(p) == actual.read(p), f'Recurso modificado: {p}'
        sonidos = [p for p in conservados if p.endswith('.wav')]
        assert len(sonidos) == 43
        nuevos_sonidos = sorted((ROOT / 'assets/sonidos/evaluacion').glob('*.wav'))
        assert len(nuevos_sonidos) == 18
        assert not any('evaluacionSorteo' in p for p in actual.namelist())
        for sonido in nuevos_sonidos:
            ruta = 'assets/flutter_assets/' + sonido.relative_to(ROOT).as_posix()
            assert actual.read(ruta) == sonido.read_bytes(), f'Sonido ausente o alterado: {ruta}'
        for nombre in ('libapp.so', 'libflutter.so'):
            p = f'lib/arm64-v8a/{nombre}'
            assert actual.getinfo(p).compress_type == zipfile.ZIP_DEFLATED
        assert not any(p.startswith('lib/') and p.endswith('.so') and not p.startswith('lib/arm64-v8a/') for p in actual.namelist())
        assert not any(p.endswith(('portada-referencia.png', 'trivia-simbolo-v11.png')) for p in actual.namelist())
    badging = ejecutar(TOOLS / 'aapt.exe', 'dump', 'badging', APK)
    assert "name='ar.maillet.triviaantiguedad'" in badging
    assert f"versionName='{VERSION}'" in badging
    assert f"versionCode='{CODIGO}'" in badging, 'El código Android no coincide con pubspec.'
    assert "application-label:'Trivia'" in badging, 'Nombre Android incorrecto.'
    assert 'application-debuggable' not in badging
    recursos_android = ejecutar(TOOLS / 'aapt.exe', 'dump', 'resources', APK)
    assert 'drawable/trivia_dialogo_foreground' in recursos_android, 'Falta el icono de diálogo multicolor.'
    assert 'drawable/unidad_iv_foreground' not in recursos_android, 'Se conserva el icono IV anterior.'
    assert 'drawable/trivia_simbolo_v11' not in recursos_android, 'Se conserva el icono antiguo en distribución.'
    firmas = [ejecutar(TOOLS / 'apksigner.bat', 'verify', '--print-certs', p) for p in (BASE, APK)]
    digests = [re.search(r'Signer #1 certificate SHA-256 digest: (\w+)', f)[1] for f in firmas]
    assert digests[0] == digests[1], 'Cambió la firma de actualización.'
    informe = dict(version=VERSION, codigo_android=CODIGO, bytes=APK.stat().st_size,
                   MB_decimales=round(APK.stat().st_size / 1_000_000, 3),
                   sha256=hashlib.sha256(APK.read_bytes()).hexdigest(),
                   recursos_originales_identicos=len(conservados), sonidos_identicos=len(sonidos), nuevos_sonidos=len(nuevos_sonidos),
                   firma_actualizacion_conservada=True, icono_dialogo_multicolor=True, release=True, arquitectura='arm64-v8a')
    salida = ROOT / 'qa/evaluacion/optimizacion'
    salida.mkdir(parents=True, exist_ok=True)
    (salida / f'verificacion-{VERSION}.json').write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(informe, ensure_ascii=False, indent=2))
