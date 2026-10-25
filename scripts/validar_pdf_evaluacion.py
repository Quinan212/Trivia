"""Audita texto/paginación y renderiza los PDF simulados del generador de Flutter."""
from pathlib import Path
import json, re, subprocess, unicodedata
from concurrent.futures import ThreadPoolExecutor
from pypdf import PdfReader
import pdfplumber
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
PDF=ROOT/'qa/evaluacion/pdf'
OUT=PDF/'render-1.1.6'
OUT.mkdir(exist_ok=True)
bank=json.loads((ROOT/'assets/contenido/trivia-unidad-iv.json').read_text(encoding='utf-8'))
def norm(s):return re.sub(r'\s+','',unicodedata.normalize('NFC',s))
def analizar(p):
 r=PdfReader(p);texts=[norm(pg.extract_text()) for pg in r.pages]
 assert r.metadata.author=='Javier Patricio Borche'
 assert r.metadata.title.startswith('Unidad IV · Informe de evaluación')
 assert norm('Docente: Javier Patricio Borche') in texts[0]
 assert norm('Procesos sociales, políticos, económicos y culturales de la Antigüedad') in texts[0]
 assert norm('1B · 2026') in texts[0]
 assert norm('historia antigua') not in texts[0].casefold()
 assert not any(norm('Alternativa correcta:') in t for t in texts), 'Clave repetida debajo de las opciones'
 assert not any(norm('Alan Gabriel Maillet') in t for t in texts)
 questions=[q['id'] for q in bank if any(all(norm(x) in t for x in [q['text'],*q['options']]) for t in texts)]
 codes=[q['id'] for q in bank if any(norm(q['id']) in t for t in texts)]
 assert not codes,('Códigos internos visibles',codes)
 outside=[];circulos={'verdes':0,'rojos':0}
 with pdfplumber.open(p) as pdf:
  for n,pg in enumerate(pdf.pages,1):
   for curva in pg.curves:
    color=curva.get('stroking_color')
    if not (curva.get('stroke') and abs(curva.get('width',0)-16)<.4 and abs(curva.get('height',0)-16)<.4 and isinstance(color,(list,tuple)) and len(color)==3):continue
    for clave,rgb in [('verdes',(45/255,106/255,79/255)),('rojos',(178/255,25/255,14/255))]:
     if max(abs(a-b) for a,b in zip(color,rgb))<.001:circulos[clave]+=1
   for ch in pg.chars:
    if ch['text'].strip() and (ch['x0']<-.5 or ch['x1']>pg.width+.5 or ch['top']<-.5 or ch['bottom']>pg.height+.5):outside.append((n,ch['text']))
 dest=OUT/p.stem;dest.mkdir(exist_ok=True)
 rendered=subprocess.run(['pdftoppm','-scale-to','850','-png',str(p),str(dest/'p')],capture_output=True)
 assert rendered.returncode==0,rendered.stderr
 images=sorted(dest.glob('p-*.png'));assert len(images)==len(texts)
 for start in range(0,len(images),20):
  sheet=Image.new('RGB',(1100,1320),'#e9e3df');draw=ImageDraw.Draw(sheet)
  for j,img in enumerate(images[start:start+20]):
   im=Image.open(img);im.thumbnail((206,292));x=(j%5)*220+7;y=(j//5)*330+23;sheet.paste(im,(x,y));draw.text((x,y-17),img.stem,fill='black')
  sheet.save(OUT/f'{p.stem}-contacto-{start//20+1:02}.jpg')
 wrong=[i for i,t in enumerate(texts[1:],2) if f'{i:02}/{len(texts):02}' not in t]
 assert not outside and not wrong,(outside,wrong)
 if p.stem=='prueba-estres-200':assert len(questions)==200
 assert circulos['verdes']>=len(questions),circulos
 if p.stem=='informe-alumno-simulado':assert circulos['rojos']>=2,circulos
 return dict(archivo=p.name,paginas=len(texts),preguntas_con_cuatro_opciones_en_la_misma_pagina=len(questions),circulos_de_respuestas=circulos,codigos_internos_visibles=codes,caracteres_fuera_de_pagina=outside,numeracion_incorrecta=wrong,macrones={c:sum(t.count(c) for t in texts) for c in 'āēīōū'})
with ThreadPoolExecutor(max_workers=3) as ex:results=list(ex.map(analizar,[*PDF.glob('*.pdf'),ROOT/'qa/evaluacion/simulacion-alumno/informe-alumno-simulado.pdf']))
(ROOT/'qa/evaluacion/auditoria-pdf-final.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(results,ensure_ascii=True))
