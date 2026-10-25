"""Aplica solo valores de color; no modifica recursos raster ni tipografía."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/paleta-tableta'
QA.mkdir(parents=True, exist_ok=True)
THEME = ROOT / 'lib/tema/tema_trivia_antiguedad.dart'
COLORS = ROOT / 'android/app/src/main/res/values/colors.xml'
REFERENCE = Path(r'C:\Users\alan\AppData\Local\Temp\codex-clipboard-6a37deb3-f78a-489c-8f99-64afc478e3cb.png')
assert not (QA / 'antes.json').exists(), 'La paleta ya se aplicó; no reemplazar el respaldo.'
baseline = {}
for folder in ('lib', 'assets', 'android/app/src', 'test', 'integration_test', 'test_driver'):
    for p in (ROOT / folder).rglob('*'):
        if p.is_file():
            baseline[p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
for name in ('pubspec.yaml', 'pubspec.lock'):
    baseline[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
(QA / 'antes.json').write_text(json.dumps(baseline, indent=2), encoding='utf-8')
shutil.copy2(REFERENCE, QA / 'portada-referencia.png')
shutil.copy2(THEME, QA / 'tema-antes.dart.txt')
shutil.copy2(COLORS, QA / 'colores-antes.xml.txt')
text = THEME.read_text(encoding='utf-8')
colors = {
    'tinta': '342725', 'tenue': '795D54', 'naranja': 'B2190E',
    'sobreNaranja': 'FCF8F0', 'naranjaTexto': 'B2190E', 'salvia': 'F1D3C7',
    'fondo': 'FCF8F0', 'hoja': 'FCF8F0', 'borde': 'DA8F84',
    'salviaClara': 'F5DFD4', 'salviaMedia': 'F1D3C7', 'salviaOscura': 'EDC7B9',
}
for role, value in colors.items():
    text, count = re.subn(rf'(static const {role} = Color\(0xFF)[0-9A-F]{{6}}(\);)', rf'\g<1>{value}\2', text)
    assert count == 1, role

def rgb(hexcode):
    return np.array([int(hexcode[i:i+2], 16) for i in (0, 2, 4)], dtype=float)

def matrix(name):
    match = re.search(rf'static const {name} = ColorFilter.matrix\(\[(.*?)\]\);', text, re.S)
    values = np.array([float(v) for v in re.findall(r'-?\d+\.\d+', match.group(1))]).reshape(4, 5)
    return values

background = matrix('filtroFondo')
old = np.array([np.append(rgb(c), 1) for c in ['F5F2E8', 'D9E7D6', '2A6047', 'FFFFFF']])
new = np.array([rgb(c) for c in ['FCF8F0', 'F1D3C7', 'B2190E', 'FFFFFF']])
mapping = np.linalg.solve(old, new).T
background[:3, :3], background[:3, 4] = mapping[:, :3] @ background[:3, :3], mapping[:, :3] @ background[:3, 4] + mapping[:, 3]
logo = matrix('filtroLogo')
mapping_logo = np.linalg.solve(np.array([rgb(c) for c in ['2D6B4D', 'FF7900', 'FFFFFF']]), np.array([rgb(c) for c in ['342725', 'B2190E', 'FCF8F0']])).T
logo[:3, :3] = mapping_logo @ logo[:3, :3]
for name, values in [('filtroFondo', background), ('filtroLogo', logo)]:
    body = '\n' + ''.join(f'    {value:.9f},\n' for value in values.flatten()) + '  '
    text = re.sub(rf'(static const {name} = ColorFilter.matrix\(\[).*?(\]\);)', lambda m: m.group(1) + body + m.group(2), text, flags=re.S)
text = re.sub(r'(static const coloresCartas = \[).*?(\];)', '\\1\n    Color(0xFFF5DFD4),\n    Color(0xFFF1D3C7),\n    Color(0xFFEDC7B9),\n    Color(0xFFFCF8F0),\n  \\2', text, flags=re.S)
text = text.replace('// Fondo crema, figuras salvia y marcas verdes; conserva textura y alfa.', '// Portada: crema, figuras rosa y marcas rojas; conserva textura y alfa.')
text = text.replace('// Colores del logo del video; forma, textura y alfa originales.', '// Portada: tinta marrón, acento rojo y crema; forma, textura y alfa originales.')
THEME.write_text(text, encoding='utf-8')
COLORS.write_text(COLORS.read_text(encoding='utf-8').replace('#F5F2E8', '#FCF8F0').replace('#2D6B4D', '#342725'), encoding='utf-8')
(QA / 'paleta.json').write_text(json.dumps(dict(colores=colors, cartas=['F5DFD4','F1D3C7','EDC7B9','FCF8F0'], fuente=str(REFERENCE), cambios_permitidos=[str(THEME.relative_to(ROOT)), str(COLORS.relative_to(ROOT))]), indent=2), encoding='utf-8')
print('Paleta de la portada aplicada. Recursos gráficos intactos.')
