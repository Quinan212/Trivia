"""Deriva los acentos de la base roja conservando luminosidad CIELAB.

Cambia el matiz conservando L; reduce cromaticidad si el destino sale de sRGB.
La familia amarilla usa los tonos vivos pedidos por Alan, sin derivación oliva.
Papel, textura, tinta y colores semánticos se conservan en Flutter.
"""
import math


def lab(hexadecimal):
    rgb = [int(hexadecimal[i:i+2], 16)/255 for i in (0,2,4)]
    r,g,b = [v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    xyz = [(.4124564*r+.3575761*g+.1804375*b)/.95047,
           .2126729*r+.7151522*g+.072175*b,
           (.0193339*r+.119192*g+.9503041*b)/1.08883]
    x,y,z = [v**(1/3) if v>(6/29)**3 else v/(3*(6/29)**2)+4/29 for v in xyz]
    return 116*y-16,500*(x-y),200*(y-z)


def rgb(l,a,b):
    y=(l+16)/116;x=y+a/500;z=y-b/200
    x,y,z=[v**3 if v>6/29 else 3*(6/29)**2*(v-4/29) for v in (x,y,z)]
    x*=.95047;z*=1.08883
    valores=[3.2404542*x-1.5371385*y-.4985314*z,
            -.969266*x+1.8760108*y+.041556*z,
            .0556434*x-.2040259*y+1.0572252*z]
    return [12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055 for v in valores]


def girar(color,grados,factor=1):
    l,a,b=lab(color);c=math.hypot(a,b)*factor;h=math.radians(grados)
    for _ in range(500):
        salida=rgb(l,c*math.cos(h),c*math.sin(h))
        if all(0<=v<=1 for v in salida):
            return ''.join(f'{round(v*255):02X}' for v in salida)
        c*=.99
    raise ValueError(color)


if __name__=='__main__':
    principales=['B2190E','118E0B','0973BA','FFCC00','C44E0F']
    colores={'naranja':'B2190E','borde':'96503E','salvia':'D99C84',
             'salviaClara':'F1D1C1','salviaMedia':'E6B49D','salviaOscura':'BD7F65'}
    for nombre,base in colores.items():
        if nombre=='naranja':
            valores=principales
        else:
            matices=[math.degrees(math.atan2(lab(c)[2],lab(c)[1])) for c in principales[1:]]
            valores=[base,*[girar(base,h) for h in matices]]
        if nombre!='naranja':
            valores[3]={'borde':'9C7400','salvia':'F4D16A','salviaClara':'FFF1B8','salviaMedia':'FFE08A','salviaOscura':'D9AC38'}[nombre]
        if nombre!='naranja': valores[4]=girar(base,65,1.7)
        print(nombre, ', '.join('0xFF'+v for v in valores))
