"""Inspecciona el APK de release sin acceder a contraseñas de firma."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SDK = Path.home() / 'AppData/Local/Android/Sdk'
TOOLS = SDK / 'build-tools/36.0.0'
APK = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
OUT = ROOT / 'qa/evaluacion'
ORIGINAL = Path(r'C:\Users\alan\Desktop\JUEGO CONTAME\contame-android')


def ejecutar(*args):
    return subprocess.run(list(map(str, args)), check=True, capture_output=True).stdout.decode('utf-8', errors='replace')


if __name__ == '__main__':
    badging = ejecutar(TOOLS / 'aapt.exe', 'dump', 'badging', APK)
    (OUT / 'apk-badging.txt').write_text(badging, encoding='utf-8')
    assert "package: name='ar.maillet.triviaantiguedad'" in badging
    version = re.search(r'^version: (\S+)', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'), re.M).group(1)
    nombre_version, codigo_version = version.split('+')
    assert f"versionCode='{codigo_version}'" in badging
    assert f"versionName='{nombre_version}'" in badging
    assert "application-label:'Trivia · Unidad IV'" in badging
    assert "launchable-activity: name='ar.maillet.triviaantiguedad.MainActivity'" in badging
    firma = ejecutar(TOOLS / 'apksigner.bat', 'verify', '--verbose', '--print-certs', APK)
    (OUT / 'apk-firma.txt').write_text(firma, encoding='utf-8')
    certificado = re.search(r'Signer #1 certificate SHA-256 digest: (\w+)', firma).group(1)
    original = ORIGINAL / 'build/app/outputs/flutter-apk/app-release.apk'
    certificado_original = None
    if original.exists():
        anterior = ejecutar(TOOLS / 'apksigner.bat', 'verify', '--print-certs', original)
        certificado_original = re.search(r'Signer #1 certificate SHA-256 digest: (\w+)', anterior).group(1)
        assert certificado != certificado_original, 'La firma debe ser independiente.'
    recursos = []
    iconos_reducidos = []
    declarados = set(re.findall(r'- (assets/[^\s]+)', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')))
    with zipfile.ZipFile(APK) as zip_apk:
        for carpeta in ('assets/contenido', 'assets/imagenes', 'assets/sonidos', 'assets/documentos', 'assets/fuentes'):
            for recurso in (ROOT / carpeta).rglob('*'):
                if recurso.is_file():
                    ruta = recurso.relative_to(ROOT).as_posix()
                    empaquetado = 'assets/flutter_assets/' + ruta
                    if empaquetado not in zip_apk.namelist():
                        assert ruta not in declarados and (
                            carpeta == 'assets/imagenes'
                            or (carpeta == 'assets/fuentes' and recurso.suffix == '.txt')
                        ), ruta
                        continue
                    contenido = zip_apk.read(empaquetado)
                    if ruta == 'assets/fuentes/Phosphor-Bold.ttf':
                        # Flutter conserva en release solo los glifos de iconos usados.
                        assert contenido[:4] == b'\x00\x01\x00\x00'
                        assert 0 < len(contenido) <= recurso.stat().st_size
                        iconos_reducidos.append(ruta)
                        continue
                    assert contenido == recurso.read_bytes(), ruta
                    recursos.append(ruta)
    sonidos = list((ROOT / 'assets/sonidos').rglob('*.wav'))
    assert len(sonidos) == 43
    for sonido in sonidos:
        assert sonido.read_bytes() == (ORIGINAL / sonido.relative_to(ROOT)).read_bytes()
    entrega = ROOT / f'output/Trivia-Unidad-IV-{nombre_version}.apk'
    shutil.copy2(APK, entrega)
    pruebas = re.findall(r'\+(\d+): All tests passed!', (OUT / f'pruebas-{nombre_version}.log').read_text(encoding='utf-8'))
    assert pruebas, 'Falta el registro de las comprobaciones para esta versión.'
    informe = dict(paquete='ar.maillet.triviaantiguedad', nombre='Trivia · Unidad IV', version=version, firma_verificada=True, certificado_sha256=certificado, certificado_original_sha256=certificado_original, recursos_empaquetados_identicos=len(recursos), fuentes_iconos_reducidas_por_flutter=iconos_reducidos, sonidos_originales_identicos=len(sonidos), bytes=APK.stat().st_size, sha256=hashlib.sha256(APK.read_bytes()).hexdigest(), apk=str(entrega), solo_tabletas=True, lado_menor_minimo_dp=600, inicio_tiempo_manual=True, controles_tiempo='columna lateral horizontal o recorrido de la página vertical', paginas_sin_franjas_fijas=True, panel_turno='nombre, reloj, puntos y respuestas', aviso_lectura_visible=False, transicion_pregunta='CoordinadorCarta: salida opaca 220 ms y asentamiento 160 ms', circulos_y_marcas_en_informes=True, codigos_internos_visibles=False, banco_literal_conservado=True, pruebas_flutter=int(pruebas[-1]), instalado_en_emulador=False)
    informe['alcance_verificacion'] = 'Muestra PDF puntual y compilación, sin suite completa' if '--rapida' in sys.argv else 'Suite de pruebas registrada y compilación'
    (OUT / 'entrega.json').write_text(json.dumps(informe, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (ROOT / 'output/SHA256.txt').write_text(f"{informe['sha256']}  {entrega.name}\n", encoding='utf-8')
    print(json.dumps(informe, ensure_ascii=False))
