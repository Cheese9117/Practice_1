# Practice I — From Pixels to the Integral
ST0244 - Programming Languages Programming · EAFIT

## Integrantes del equipo
- Juan Sebastián Henao Arenas

## Entorno de desarrollo
- **Haskell**: GHC 9.4.7 (compilador `ghc`, sin dependencias externas — solo `base`, `bytestring`).
- **Prolog**: SWI-Prolog 9.0.4.
- Probado en Linux (Ubuntu 24.04), pero ambos programas usan solo IO estándar y deberían compilar/ejecutar igual en Windows/macOS con GHC y SWI-Prolog instalados.

## Estructura del repositorio
```
Haskell/
  Main.hs
Prolog/
  main.pl
README.md
curva_binaria_P4.pbm
```

## Cómo ejecutar la solución en Haskell
Desde la carpeta `Haskell/` (el programa espera el `.pbm` en `../curva_binaria_P4.pbm`):

```bash
cd Haskell
ghc -O2 -o main Main.hs
./main
```

También puede ejecutarse sin compilar, con `runghc Main.hs`.

## Cómo ejecutar la solución en Prolog
Desde la carpeta `Prolog/` (el programa espera el `.pbm` en `../curva_binaria_P4.pbm`):

```bash
cd Prolog
swipl main.pl
```

El predicado `main/0` se dispara automáticamente al cargar el archivo gracias a `:- initialization(main, main).`, imprime los resultados y termina con `halt`.

## Área obtenida
Con el archivo `curva_binaria_P4.pbm` suministrado (567 × 319 píxeles):

```
Area = 108660 pixeles cuadrados
```

Ambas implementaciones (Haskell y Prolog) producen exactamente el mismo valor, y coincide con el resultado de referencia del programa en C++ del enunciado (Figura 1), incluyendo los mismos valores de muestra `x_i -> f(x_i)`.

## Estrategia para la visualización en consola
La imagen original (567 × 319 píxeles) es mucho más grande que una terminal típica, así que en ambos programas se usa la misma estrategia de **muestreo + reescalado**, aplicada sobre la lista/estructura de alturas `M` ya calculada (no sobre los píxeles crudos):

1. **Muestreo horizontal**: en lugar de recorrer las 567 columnas, se toman `N = 100` índices distribuidos uniformemente en el dominio `[0, ancho-1]` (`i * (largo-1) / (N-1)`), de modo que el ancho de consola quede fijo sin importar el tamaño de la imagen original.
2. **Reescalado vertical**: cada altura muestreada `f(x)` se reescala proporcionalmente a un número fijo de filas de consola (`28`), con `round(f(x) * filas_consola / max(M))`, preservando la proporción relativa entre columnas altas y bajas.
3. Con esas alturas escaladas se dibuja:
   - una silueta ASCII de la curva (fila por fila, de arriba hacia abajo, imprimiendo `#` cuando la altura escalada alcanza esa fila), y
   - una versión compacta de una sola línea usando una **rampa de caracteres ASCII** (` .:-=+*#%@`, de menor a mayor altura), un "sparkline" de `M[x] = f(x)`. Se usa ASCII en vez de bloques Unicode (▁▂▃▄▅▆▇█) para que la visualización se vea igual en cualquier consola, sin depender de la página de códigos (`chcp`) ni de la fuente configurada en el sistema.

Esta estrategia mantiene la forma general de la curva (dónde sube, dónde baja, dónde está el valle) sin necesitar mostrar los 567×319 píxeles originales.

## Comparación de paradigmas (resumen)
- **Haskell (funcional)**: el problema se ve como una cadena de transformaciones `dominio -> alturas -> área`. `M` se obtiene aplicando `f` a todo el dominio con `map f [0 .. ancho-1]`, y el área emerge de plegar esa lista con `sum`. No hay estado mutable ni bucles imperativos: todo es composición de funciones puras sobre listas.
- **Prolog (lógico/declarativo)**: el problema se ve como un conjunto de relaciones que deben cumplirse. `f(X, Datos, Alto, BytesPorFila, Altura)` no "calcula" un valor con instrucciones, sino que describe qué relación debe existir entre una columna `X` y su altura `Altura`. `M` se construye con `findall/3`, pidiéndole a Prolog *todos* los valores de `Altura` que satisfacen esa relación para cada `X`, y el área surge de sumar esa lista con `sum_list/2`.

En ambos casos la transformación conceptual es la misma:

```
PBM -> bytes -> pixeles -> f(x) -> M -> area
```

pero mientras Haskell la expresa como *funciones aplicadas y combinadas*, Prolog la expresa como *relaciones que Prolog resuelve buscando todas las soluciones*.
