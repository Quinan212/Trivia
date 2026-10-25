"""Verifica que la copia solo adapta identidad y conserva código y recursos."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = Path(r'C:\Users\alan\Desktop\JUEGO CONTAME\contame-android')
CAMBIOS = [
    ('ar.contame.contame_android', 'ar.maillet.triviaantiguedad'),
    ('ar.maillet.encuentroer', 'ar.maillet.triviaantiguedad'),
    ('contame_android', 'trivia_antiguedad'),
    ('Che, Preguntame', 'Trivia de la antiguedad'),
    ('Che, preguntame', 'Trivia de la antiguedad'),
    ('Che Preguntame', 'Trivia de la antiguedad'),
    ('ChePreguntame', 'TriviaAntiguedad'),
    ('che-preguntame', 'trivia-antiguedad'),
    ('che-simbolo', 'trivia-simbolo'),
    ('che_simbolo', 'trivia_simbolo'),
    ('che_icon', 'trivia_icon'),
    ('Contame', 'TriviaAntiguedad'),
    ('CONTAME', 'TRIVIA-ANTIGUEDAD'),
    ('contame', 'trivia_antiguedad'),
]


def adaptar(texto):
    for viejo, nuevo in CAMBIOS:
        texto = texto.replace(viejo, nuevo)
    return texto


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == '__main__':
    revisados = []
    paleta_posterior = ROOT / 'qa/paleta-tableta/tema-antes.dart.txt'
    if paleta_posterior.exists():
        subprocess.run([shutil.which('python'), str(ROOT / 'scripts/verificar_paleta.py')], check=True)
    with tempfile.TemporaryDirectory(prefix='trivia-audit-') as temporal:
        base = Path(temporal)
        shutil.copy2(ROOT / 'pubspec.yaml', base / 'pubspec.yaml')
        for carpeta in ('lib', 'test', 'integration_test', 'test_driver'):
            for archivo in (ORIGINAL / carpeta).rglob('*.dart'):
                relativo = archivo.relative_to(ORIGINAL).as_posix()
                esperado = adaptar(archivo.read_text(encoding='utf-8'))
                if relativo == 'lib/compartido/componentes/fondo_conversacion.dart':
                    # Única adaptación visual: el nombre largo conserva una línea
                    # del encabezado y no quita espacio a cartas ni tutorial.
                    esperado = esperado.replace(
                        "'Trivia de la antiguedad',\n                                  style:",
                        "'Trivia de la antiguedad',\n                                  maxLines: 1,\n                                  overflow: TextOverflow.ellipsis,\n                                  style:",
                    )
                destino = base / adaptar(relativo)
                destino.parent.mkdir(parents=True, exist_ok=True)
                destino.write_text(esperado, encoding='utf-8')
                revisados.append(relativo)
        subprocess.run([shutil.which('dart'), 'format', str(base)], check=True, capture_output=True)
        for relativo in revisados:
            esperado = (base / adaptar(relativo)).read_text(encoding='utf-8')
            actual = (ROOT / adaptar(relativo)).read_text(encoding='utf-8')
            if relativo == 'lib/tema/tema_contame.dart' and paleta_posterior.exists():
                actual = paleta_posterior.read_text(encoding='utf-8')
            assert esperado == actual, f'Cambio adicional al renombrado: {relativo}'

    recursos = json.loads((ROOT / 'qa/clonacion/assets.json').read_text(encoding='utf-8'))
    for recurso in recursos:
        origen = ORIGINAL / recurso['original']
        copia = ROOT / recurso['copia']
        assert sha(origen) == recurso['sha256_original'], f"Original alterado: {origen}"
        assert sha(copia) == recurso['sha256_copia'], f"Copia alterada: {copia}"
        if recurso['original'].endswith('politica-privacidad.txt'):
            assert adaptar(origen.read_text(encoding='utf-8')) == copia.read_text(encoding='utf-8')
        else:
            assert origen.read_bytes() == copia.read_bytes()
    assert (ORIGINAL / 'pubspec.lock').read_bytes() == (ROOT / 'pubspec.lock').read_bytes()
    informe = dict(base_solo_identidad=True, paleta_posterior_verificada=paleta_posterior.exists(), adaptacion_titulo='Una línea con elipsis; semántica conserva el nombre completo.', archivos_dart=len(revisados), recursos=len(recursos), recursos_identicos=sum(r['identico'] for r in recursos), lockfile_identico=True, archivos=revisados)
    (ROOT / 'qa/clonacion/comparacion.json').write_text(json.dumps(informe, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in informe.items() if k != 'archivos'}, ensure_ascii=False))
