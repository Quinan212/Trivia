"""Inspección de UI Android: solo etiquetas leídas de la jerarquía actual."""
from pathlib import Path
import subprocess,xml.etree.ElementTree as ET,re,json,time,argparse
ROOT=Path(__file__).resolve().parents[1]
ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
def adb(*args,device='emulator-5556'):
 return subprocess.run([str(ADB),'-s',device,*args],check=True,capture_output=True).stdout
def captura(nombre,device='emulator-5556'):
 expected=b'ChePreguntame_QA_API_36' if device=='emulator-5556' else b'Trivia_Antiguedad_Tablet_API_36'
 assert expected in adb('emu','avd','name',device=device)
 out=ROOT/'qa/evaluacion/android'/device;out.mkdir(parents=True,exist_ok=True)
 adb('shell','uiautomator','dump','/sdcard/trivia-evaluacion-qa.xml',device=device)
 raw=adb('exec-out','cat','/sdcard/trivia-evaluacion-qa.xml',device=device)
 (out/f'{nombre}.xml').write_bytes(raw);(out/f'{nombre}.png').write_bytes(adb('exec-out','screencap','-p',device=device))
 return list(ET.fromstring(raw).iter('node'))
def tocar(texto,nombre,device='emulator-5556'):
 nodes=captura(nombre+'-antes',device=device)
 found=[n for n in nodes if texto in (n.get('text'),n.get('content-desc')) and n.get('enabled')=='true']
 assert len(found)==1,[(n.attrib) for n in found]
 n=found[0];x0,y0,x1,y1=map(int,re.findall(r'\d+',n.get('bounds')))
 adb('shell','input','tap',str((x0+x1)//2),str((y0+y1)//2),device=device);time.sleep(.7)
 return captura(nombre,device=device)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--nombre',required=True);p.add_argument('--tap');p.add_argument('--device',default='emulator-5556',choices=['emulator-5556','emulator-5558']);a=p.parse_args()
 nodes=tocar(a.tap,a.nombre,a.device) if a.tap else captura(a.nombre,a.device)
 print(json.dumps([dict(texto=n.get('text')or n.get('content-desc'),limites=n.get('bounds'),enabled=n.get('enabled'),id=n.get('resource-id')) for n in nodes if n.get('text')or n.get('content-desc')],ensure_ascii=False))
