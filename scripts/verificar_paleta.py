"""Comprueba que en el juego solo cambiaron los dos archivos de color."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/paleta-tableta'


def sin_colores(text):
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r'Color\(0x[0-9A-Fa-f]+\)', 'Color(COLOR)', text)
    text = re.sub(r'ColorFilter.matrix\(\[.*?\]\)', 'ColorFilter.matrix([MATRIZ])', text, flags=re.S)
    return re.sub(r'\s+', '', text)


if __name__ == '__main__':
    baseline = json.loads((QA / 'antes.json').read_text(encoding='utf-8'))
    allowed = {'lib/tema/tema_trivia_antiguedad.dart', 'android/app/src/main/res/values/colors.xml'}
    changed = []
    for name, expected in baseline.items():
        actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        if expected != actual:
            assert name in allowed, f'Cambio fuera de la paleta: {name}'
            changed.append(name)
    assert set(changed) == allowed
    before = (QA / 'tema-antes.dart.txt').read_text(encoding='utf-8')
    after = (ROOT / 'lib/tema/tema_trivia_antiguedad.dart').read_text(encoding='utf-8')
    assert sin_colores(before) == sin_colores(after), 'Se modificó algo además de los valores de color.'
    before_xml = (QA / 'colores-antes.xml.txt').read_text(encoding='utf-8')
    after_xml = (ROOT / 'android/app/src/main/res/values/colors.xml').read_text(encoding='utf-8')
    assert re.sub(r'#[0-9A-Fa-f]+', '#COLOR', before_xml) == re.sub(r'#[0-9A-Fa-f]+', '#COLOR', after_xml)
    report = dict(archivos_comprobados=len(baseline), cambios=changed, solo_valores_de_color=True, fuentes_imagenes_sonidos_contenido_y_logica_identicos=True)
    (QA / 'alcance.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))
