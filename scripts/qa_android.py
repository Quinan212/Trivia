"""Captura la copia instalada en el AVD de QA y toca etiquetas observadas."""
from pathlib import Path
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
TABLETA = (ROOT / 'qa/paleta-tableta').exists()
OUT = ROOT / ('qa/paleta-tableta' if TABLETA else 'qa/clonacion')
DEVICE = 'emulator-5558' if TABLETA else 'emulator-5556'
AVD = b'Trivia_Antiguedad_Tablet_API_36' if TABLETA else b'ChePreguntame_QA_API_36'


def adb(*args):
    return subprocess.run([str(ADB), '-s', DEVICE, *args], check=True, capture_output=True).stdout


def snapshot(nombre):
    adb('shell', 'uiautomator', 'dump', '/sdcard/trivia-qa.xml')
    raw = adb('exec-out', 'cat', '/sdcard/trivia-qa.xml')
    (OUT / f'{nombre}.xml').write_bytes(raw)
    (OUT / f'{nombre}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    return list(ET.fromstring(raw).iter('node'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--tap')
    parser.add_argument('--nombre', required=True)
    args = parser.parse_args()
    assert AVD in adb('emu', 'avd', 'name'), 'Solo se usa el AVD previsto para esta etapa.'
    assert b'ar.maillet.triviaantiguedad' in adb('shell', 'dumpsys', 'activity', 'activities')
    if args.tap:
        nodos = snapshot(args.nombre + '-antes')
        nodo = next(n for n in nodos if args.tap in (n.get('text'), n.get('content-desc')))
        assert nodo.get('enabled') == 'true'
        x0, y0, x1, y1 = map(int, re.findall(r'\d+', nodo.get('bounds')))
        adb('shell', 'input', 'tap', str((x0+x1)//2), str((y0+y1)//2))
        time.sleep(1)
    nodos = snapshot(args.nombre)
    print(json.dumps([dict(texto=n.get('text') or n.get('content-desc'), limites=n.get('bounds')) for n in nodos if n.get('text') or n.get('content-desc')], ensure_ascii=False))
