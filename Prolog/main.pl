:- initialization(main, main).

ruta_archivo('../curva_binaria_P4.pbm').

% --------------------------------------------------------------
% 1-2. Carga del archivo PBM P4 y acceso a pixeles individuales
% --------------------------------------------------------------

% leer_pbm(+Ruta, -Ancho, -Alto, -BytesPorFila, -DatosString)
leer_pbm(Ruta, Ancho, Alto, BytesPorFila, DatosString) :-
    open(Ruta, read, Stream, [type(binary)]),
    read_string(Stream, _, Contenido),
    close(Stream),
    string_codes(Contenido, Codigos),
    parsear_encabezado(Codigos, Ancho, Alto, DatosCodigos),
    string_codes(DatosString, DatosCodigos),
    BytesPorFila is (Ancho + 7) // 8.

% parsear_encabezado(+Codigos, -Ancho, -Alto, -DatosCodigos)
% Formato P4: "P4" <blancos/comentarios> Ancho <blancos/comentarios> Alto <1 separador> <binario>
parsear_encabezado([0'P, 0'4 | Resto0], Ancho, Alto, Datos) :-
    saltar_blancos_comentarios(Resto0, Resto1),
    leer_entero(Resto1, Ancho, Resto2),
    saltar_blancos_comentarios(Resto2, Resto3),
    leer_entero(Resto3, Alto, Resto4),
    Resto4 = [_Separador | Datos].

saltar_blancos_comentarios([], []) :- !.
saltar_blancos_comentarios([C|Resto], Salida) :-
    ( blanco(C)
    -> saltar_blancos_comentarios(Resto, Salida)
    ;  C =:= 0'#
    -> saltar_hasta_nl(Resto, Resto1),
       saltar_blancos_comentarios(Resto1, Salida)
    ;  Salida = [C|Resto]
    ).

blanco(32). blanco(9). blanco(10). blanco(13).

saltar_hasta_nl([], []) :- !.
saltar_hasta_nl([10|Resto], Resto) :- !.
saltar_hasta_nl([_|Resto], Salida) :- saltar_hasta_nl(Resto, Salida).

leer_digitos([C|Cs], [C|Ds], Resto) :-
    C >= 0'0, C =< 0'9, !,
    leer_digitos(Cs, Ds, Resto).
leer_digitos(Resto, [], Resto).

leer_entero(Codigos, N, Resto) :-
    leer_digitos(Codigos, Digitos, Resto),
    Digitos \= [],
    number_codes(N, Digitos).

% pixel(+X, +Y, +Datos, +BytesPorFila, -Bit)
% Bit es 1 (region bajo la curva) o 0 (exterior) en la posicion (X,Y).
pixel(X, Y, Datos, BytesPorFila, Bit) :-
    IndiceByte is Y * BytesPorFila + (X // 8),
    IndiceString is IndiceByte + 1,           % string_code/3 es 1-based
    string_code(IndiceString, Datos, Byte),
    PosBit is 7 - (X mod 8),
    Bit is (Byte >> PosBit) /\ 1.

% --------------------------------------------------------------
% 3. La relacion f(X, Datos, Alto, BytesPorFila, Altura):
%    Altura = cantidad de pixeles negros consecutivos contados
%    desde la fila inferior de la columna X hacia arriba.
% --------------------------------------------------------------

f(X, Datos, Alto, BytesPorFila, Altura) :-
    YInicial is Alto - 1,
    contar_negros_consecutivos(X, YInicial, Datos, BytesPorFila, 0, Altura).

contar_negros_consecutivos(_, Y, _, _, Acumulado, Acumulado) :-
    Y < 0, !.
contar_negros_consecutivos(X, Y, Datos, BytesPorFila, Acumulado, Altura) :-
    Y >= 0,
    pixel(X, Y, Datos, BytesPorFila, Bit),
    ( Bit =:= 1
    -> Acumulado1 is Acumulado + 1,
       Y1 is Y - 1,
       contar_negros_consecutivos(X, Y1, Datos, BytesPorFila, Acumulado1, Altura)
    ;  Altura = Acumulado
    ).

% --------------------------------------------------------------
% 4-5. M = lista declarativa de alturas, y area = sum_list(M)
% --------------------------------------------------------------

% calcular_M(+Datos, +Alto, +Ancho, +BytesPorFila, -M)
% M es la lista de TODAS las Alturas que satisfacen la relacion f/5
% para cada X en [0, Ancho-1]. No se "llena" M con asignaciones:
% se describe la relacion y se le pide a Prolog que encuentre todos
% los valores que la satisfacen.
calcular_M(Datos, Alto, Ancho, BytesPorFila, M) :-
    MaxX is Ancho - 1,
    findall(
        Altura,
        ( between(0, MaxX, X),
          f(X, Datos, Alto, BytesPorFila, Altura)
        ),
        M
    ).

% calcular_area(+M, -Area): la suma de Riemann, Delta x = 1.
calcular_area(M, Area) :-
    sum_list(M, Area).

% --------------------------------------------------------------
% 6-7. Visualizacion en consola
% --------------------------------------------------------------

ancho_consola(100).
alto_consola(28).

% muestrear(+Largo, +N, -Indices): N indices uniformemente distribuidos en [0,Largo-1]
muestrear(Largo, N, Indices) :-
    ( N >= Largo
    -> LM1b is Largo - 1,
       numlist(0, LM1b, Indices)
    ;  NM1 is N - 1,
       LM1 is Largo - 1,
       findall(
           I,
           ( between(0, NM1, K), I is (K * LM1) // NM1 ),
           Indices
       )
    ).

alturas_muestreadas(M, N, Alturas) :-
    length(M, Largo),
    muestrear(Largo, N, Indices),
    maplist(nth0_altura(M), Indices, Alturas).

nth0_altura(M, I, H) :- nth0(I, M, H).

dibujar_curva(M) :-
    ancho_consola(AC),
    alto_consola(FC),
    alturas_muestreadas(M, AC, Alturas),
    max_list(Alturas, MaxH),
    numlist(1, FC, Filas0),
    reverse(Filas0, Filas),
    forall(
        member(Fila, Filas),
        ( forall(
              member(H, Alturas),
              ( Escalada is round(H * FC / MaxH),
                ( Escalada >= Fila -> write('#') ; write(' ') )
              )
          ),
          nl
        )
    ).

% Rampa de caracteres ASCII (en vez de bloques Unicode) para que la
% visualizacion se vea igual en cualquier consola, sin depender de
% la pagina de codigos o la fuente configurada en el sistema.
rampa_ascii([' ','.',':','-','=','+','*','#','%','@']).

dibujar_sparkline(M) :-
    ancho_consola(AC),
    alturas_muestreadas(M, AC, Alturas),
    max_list(Alturas, MaxH),
    rampa_ascii(Bloques),
    length(Bloques, Len),
    NNiveles is Len - 1,
    forall(
        member(H, Alturas),
        ( Idx is round(H * NNiveles / MaxH),
          nth0(Idx, Bloques, Caracter),
          write(Caracter)
        )
    ),
    nl.

% --------------------------------------------------------------
% 8. Valores de muestra x_i -> f(x_i)
% --------------------------------------------------------------

mostrar_muestras(M) :-
    length(M, Largo),
    muestrear(Largo, 10, Indices),
    forall(
        nth0(I, Indices, X),
        ( nth0(X, M, H),
          format("x_~w = ~w -> f(x_~w) = ~w pixeles~n", [I, X, I, H])
        )
    ).

% --------------------------------------------------------------
% Main
% --------------------------------------------------------------

main :-
    ruta_archivo(Ruta),
    leer_pbm(Ruta, Ancho, Alto, BytesPorFila, Datos),
    calcular_M(Datos, Alto, Ancho, BytesPorFila, M),
    calcular_area(M, Area),

    format("Imagen: ~w x ~w pixeles~n", [Ancho, Alto]),
    format("Area = ~w pixeles cuadrados~n~n", [Area]),

    writeln('VISUALIZACION DE LA CURVA (muestreada y reescalada a la consola):'),
    dibujar_curva(M),
    nl,

    writeln('FUNCION DE ALTURAS M[x] = f(x):'),
    dibujar_sparkline(M),
    nl,

    writeln('ALGUNOS VALORES x_i -> f(x_i):'),
    mostrar_muestras(M),

    halt.
main :-
    writeln('Error ejecutando el programa.'),
    halt(1).
